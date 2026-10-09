import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'store.dart';
import 'sync.dart';

/// مشروع Firebase مال العيادة (من google-services.json).
const _options = FirebaseOptions(
  apiKey: 'AIzaSyDFehsWgf_Cx-Fa6eDvoiAXGBTCgpEIQvI',
  appId: '1:897577160241:android:fa6efcbec9292b4a3c4f10',
  messagingSenderId: '897577160241',
  projectId: 'rival-26719',
  storageBucket: 'rival-26719.firebasestorage.app',
  // للويب: الدخول يمر عبر نطاق المشروع.
  authDomain: 'rival-26719.firebaseapp.com',
);

/// عضو بالعيادة (وثيقة members/{email}).
/// role: admin يشوف كل شي ويدير الحسابات، doctor يشوف بس حالاته.
/// dental / beauty: رقم ملف الطبيب بكل قسم (الطبيب ما يفتح قسم ما إله بيه ملف).
class Member {
  final String email;
  final String name;
  final bool isAdmin;
  final Map<String, String> doctorIds;
  const Member({
    required this.email,
    this.name = '',
    this.isAdmin = false,
    this.doctorIds = const {},
  });

  String? doctorFor(String section) => doctorIds[section];
  bool canOpen(String section) => isAdmin || doctorFor(section) != null;

  /// وثائق النسخة الأولى ما بيها role: كانت كلها للإدارة.
  factory Member.fromJson(String email, Map<String, dynamic> j) => Member(
    email: email,
    name: (j['name'] as String?) ?? '',
    isAdmin: (j['role'] as String?) != 'doctor',
    doctorIds: {
      for (final s in const ['dental', 'beauty'])
        if (j[s] is String && (j[s] as String).isNotEmpty) s: j[s] as String,
    },
  );

  Map<String, Object?> toJson() => {
    'name': name,
    'role': isAdmin ? 'admin' : 'doctor',
    'dental': doctorIds['dental'],
    'beauty': doctorIds['beauty'],
  };
}

/// قاعدة البيانات الموحدة: الدخول بحساب العيادة، وتشغيل المزامنة للقسم المفتوح.
/// إذا Firebase ما اشتغل (مثلاً بالاختبارات) التطبيق يكمل على بيانات الجهاز.
class Cloud extends ChangeNotifier {
  Cloud._();
  static final instance = Cloud._();

  final Map<String, Future<String>> _urls = {};

  /// رابط صورة بالتخزين (للويب: الصور تنعرض من هنا مباشرة).
  Future<String> photoUrl(String section, String name) =>
      _urls['$section/$name'] ??= FirebaseStorage.instance
          .ref('sections/$section/photos/$name')
          .getDownloadURL();

  bool available = false;
  SyncStatus status = SyncStatus.off;
  String? detail;
  SyncEngine? _engine;

  /// صلاحيات الحساب المسجل (تنقرا من members بعد الدخول).
  Member? member;

  User? get user => available ? FirebaseAuth.instance.currentUser : null;
  bool get signedIn => user != null && member != null;
  bool get isAdmin => member?.isAdmin ?? true;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: _options);
      available = true;
      if (kIsWeb) {
        // ذاكرة بالمتصفح حتى تنفتح البيانات بسرعة وتشتغل لحظات بدون إنترنت.
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
        );
      }
      Store.instance.photoUploader = (section, name, bytes) async {
        final ext = name.split('.').last.toLowerCase();
        await FirebaseStorage.instance
            .ref('sections/$section/photos/$name')
            .putData(
              Uint8List.fromList(bytes),
              SettableMetadata(
                contentType: ext == 'png' ? 'image/png' : 'image/jpeg',
              ),
            );
      };
    } catch (e) {
      debugPrint('Firebase: $e');
      available = false;
      return;
    }
    // مسجل من قبل: نقرا صلاحياته. بدون إنترنت نستخدم آخر نسخة محفوظة،
    // وما نطلّعه من حسابه إلا إذا السيرفر أكّد إن الحساب انشال.
    if (user != null) {
      final (m, removed) = await _loadMember(
        timeout: const Duration(seconds: 6),
      );
      if (removed) {
        await FirebaseAuth.instance.signOut();
      } else if (m != null) {
        member = m;
        await Store.instance.useAccount(user!.uid);
      }
    }
  }

  File get _memberCache =>
      File('${Store.instance.device.path}/member_${user?.uid}.json');

  // نسخة محفوظة من الصلاحيات (ملف بالتلفون، وذاكرة المتصفح بالويب).
  Future<void> _cacheWrite(String json) async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.setString('member_${user?.uid}', json);
    } else {
      await _memberCache.writeAsString(json);
    }
  }

  Future<String?> _cacheRead() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      return p.getString('member_${user?.uid}');
    }
    return await _memberCache.exists() ? _memberCache.readAsString() : null;
  }

  Future<void> _cacheClear() async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      await p.remove('member_${user?.uid}');
    } else if (await _memberCache.exists()) {
      await _memberCache.delete();
    }
  }

  /// (الصلاحيات، هل السيرفر أكّد إن الحساب ما موجود).
  Future<(Member?, bool)> _loadMember({Duration? timeout}) async {
    final email = user?.email?.toLowerCase();
    if (email == null) return (null, true);
    try {
      var future = FirebaseFirestore.instance
          .collection('members')
          .doc(email)
          .get();
      if (timeout != null) future = future.timeout(timeout);
      final doc = await future;
      if (doc.exists) {
        final data = doc.data()!;
        await _cacheWrite(jsonEncode(data));
        return (Member.fromJson(email, data), false);
      }
      if (!doc.metadata.isFromCache) {
        await _cacheClear();
        return (null, true);
      }
    } catch (_) {
      // بدون إنترنت أو بطء: نكمل على النسخة المحفوظة.
    }
    try {
      final raw = await _cacheRead();
      if (raw == null) return (null, false);
      final data = jsonDecode(raw);
      return (Member.fromJson(email, data as Map<String, dynamic>), false);
    } catch (_) {
      return (null, false);
    }
  }

  /// يدخل ويتأكد إن الإيميل مضاف لأعضاء العيادة. يرجّع رسالة خطأ أو null.
  Future<String?> signIn(String email, String password) async {
    if (!available) return 'قاعدة البيانات مو متوفرة على هذا الجهاز';
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      return switch (e.code) {
        'invalid-email' => 'الإيميل مو صحيح',
        'user-disabled' => 'هذا الحساب موقوف',
        'network-request-failed' =>
          'ماكو إنترنت. تأكد من الاتصال وجرب مرة ثانية',
        'too-many-requests' => 'محاولات كثيرة. انتظر شوية وجرب',
        'operation-not-allowed' => 'الدخول بالإيميل مو مفعّل بمشروع Firebase (Authentication ← Sign-in method)',
        _ => 'الإيميل أو الرمز غلط',
      };
    }
    final problem = await _memberProblem();
    if (problem != null) {
      await FirebaseAuth.instance.signOut();
      return problem;
    }
    member = (await _loadMember()).$1;
    final m = member;
    if (m == null) {
      await FirebaseAuth.instance.signOut();
      return 'ما گدرنا نقرا صلاحيات الحساب. جرب مرة ثانية.';
    }
    if (!m.isAdmin && m.doctorIds.isEmpty) {
      member = null;
      await FirebaseAuth.instance.signOut();
      return 'الحساب مضاف كطبيب، بس ما مربوط بملف طبيب. خلي المسؤول يربطه من '
          '"المزيد ← حسابات الأطباء".';
    }
    await Store.instance.useAccount(user!.uid);
    notifyListeners();
    return null;
  }

  /// يتأكد إن الإيميل مضاف بمجموعة members، ويوضح السبب بالضبط إذا لا.
  Future<String?> _memberProblem() async {
    final email = user?.email?.toLowerCase();
    if (email == null) return 'الحساب ما بيه إيميل';
    try {
      final doc = await FirebaseFirestore.instance
          .collection('members')
          .doc(email)
          .get(const GetOptions(source: Source.server));
      if (doc.exists) return null;
      return 'الحساب دخل، بس ماكو وثيقة باسم:\n$email\nبمجموعة members.\n'
          'لازم رقم الوثيقة (Document ID) يكون الإيميل نفسه بالأحرف الصغيرة، '
          'مو رقم تلقائي (Auto-ID).';
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        return 'قاعدة البيانات رفضت القراءة. تأكد إنك لصقت قواعد firestore.rules '
            'بـ Firestore ← Rules ودست Publish.';
      }
      if (e.code == 'unavailable') {
        return 'ما گدرنا نوصل لقاعدة البيانات. تأكد من الإنترنت وجرب مرة ثانية.';
      }
      return 'خطأ من قاعدة البيانات (${e.code}): ${e.message}';
    } catch (e) {
      return 'خطأ بالتأكد من العضوية: $e';
    }
  }

  Future<void> signOut() async {
    await detach();
    Store.instance.sync = null;
    if (available) await FirebaseAuth.instance.signOut();
    member = null;
    await Store.instance.useAccount(null);
    notifyListeners();
  }

  /// يشغّل المزامنة للقسم المفتوح بالمتجر.
  Future<void> attach(Store store) async {
    if (!signedIn) return;
    // الصلاحيات ممكن تغيرت من الإدارة: نحدثها (بدون إنترنت تبقى المحفوظة).
    final (fresh, removed) = await _loadMember(
      timeout: const Duration(seconds: 4),
    );
    if (removed) {
      await signOut();
      return;
    }
    if (fresh != null) member = fresh;
    final m = member;
    if (m == null) return;
    await detach();
    final section = store.section.name;
    store.myDoctorId = m.isAdmin ? null : m.doctorFor(section);
    if (!m.canOpen(section)) return;
    final engine = SyncEngine(
      store,
      FirebaseBackend(),
      doctorId: m.isAdmin ? null : m.doctorFor(section),
      onStatus: (s, [d]) {
        status = s;
        detail = d;
        notifyListeners();
      },
    );
    _engine = engine;
    store.sync = engine;
    await engine.attach();
  }

  Future<void> detach() async {
    await _engine?.detach();
    _engine = null;
  }

  /// يرفع كل شي هسه (من زر "زامن الآن").
  Future<void> syncNow() async => _engine?.push();

  // ---------- إدارة الحسابات (للإدارة بس) ----------

  CollectionReference<Map<String, dynamic>> get _members =>
      FirebaseFirestore.instance.collection('members');

  Stream<List<Member>> watchMembers() => _members.snapshots().map(
    (q) =>
        [for (final d in q.docs) Member.fromJson(d.id, d.data())]
          ..sort((a, b) => a.email.compareTo(b.email)),
  );

  /// أطباء قسم من قاعدة البيانات (حتى نربط الحساب بملف بقسم ما مفتوح هسه).
  Future<List<(String, String)>> doctorsOf(String section) async {
    final q = await FirebaseFirestore.instance
        .collection('sections')
        .doc(section)
        .collection('doctors')
        .get();
    return [
      for (final d in q.docs) (d.id, (d.data()['label'] as String?) ?? d.id),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
  }

  /// يسوي حساب دخول جديد (إذا ما موجود) ويضيفه للأعضاء.
  /// الحساب ينسوى بنسخة Firebase ثانية حتى ما يطلع المسؤول من حسابه.
  Future<String?> saveMember(Member m, {String? password}) async {
    final email = m.email.trim().toLowerCase();
    if (password != null && password.isNotEmpty) {
      FirebaseApp helper;
      try {
        helper = Firebase.app('accounts');
      } catch (_) {
        helper = await Firebase.initializeApp(
          name: 'accounts',
          options: _options,
        );
      }
      final auth = FirebaseAuth.instanceFor(app: helper);
      try {
        await auth.createUserWithEmailAndPassword(
          email: email,
          password: password,
        );
      } on FirebaseAuthException catch (e) {
        if (e.code != 'email-already-in-use') {
          return switch (e.code) {
            'weak-password' => 'الرمز ضعيف. خليه ٦ أحرف أو أكثر',
            'invalid-email' => 'الإيميل مو صحيح',
            'network-request-failed' => 'ماكو إنترنت',
            _ => 'ما انسوى الحساب: ${e.message}',
          };
        }
      } finally {
        await auth.signOut();
      }
    }
    try {
      await _members
          .doc(email)
          .set(
            Member(
              email: email,
              name: m.name,
              isAdmin: m.isAdmin,
              doctorIds: m.doctorIds,
            ).toJson(),
          );
    } on FirebaseException catch (e) {
      return 'ما انحفظت الصلاحيات (${e.code})';
    }
    return null;
  }

  Future<void> removeMember(String email) => _members.doc(email).delete();

  Future<String?> sendPasswordReset(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      return null;
    } on FirebaseAuthException catch (e) {
      return 'ما انرسل: ${e.message}';
    }
  }
}

/// هل الجهاز متصل بالإنترنت؟ يفحص كل ١٠ ثواني (وبسرعة لما يتغير الحال).
class Net extends ChangeNotifier {
  Net._();
  static final instance = Net._();

  bool online = true;
  bool _started = false;
  Timer? _timer;

  void start() {
    if (_started) return;
    _started = true;
    check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => check());
  }

  Future<void> check() async {
    bool ok;
    if (kIsWeb) {
      // المتصفح يدير الاتصال بنفسه؛ نعتبره متصل وFirestore يتعامل ويا الانقطاع.
      ok = true;
    } else {
      try {
        final r = await InternetAddress.lookup('firestore.googleapis.com')
            .timeout(const Duration(seconds: 5));
        ok = r.isNotEmpty && r.first.rawAddress.isNotEmpty;
      } catch (_) {
        ok = false;
      }
    }
    if (ok == online) return;
    online = ok;
    notifyListeners();
    // رجع الإنترنت: نرفع اللي تجمع بدون اتصال.
    if (ok) unawaited(Cloud.instance.syncNow());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Firestore للوثائق وStorage للصور:
/// sections/{dental|beauty}/{people|cases|doctors|meta}/{id} و sections/{s}/photos/{name}
class FirebaseBackend implements SyncBackend {
  final _db = FirebaseFirestore.instance;
  final _files = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String s, String k) =>
      _db.collection('sections').doc(s).collection(k);

  static RemoteDoc? _doc(DocumentSnapshot<Map<String, dynamic>> d) {
    final data = d.data();
    if (data == null || data['json'] is! String) return null;
    return RemoteDoc(d.id, data['json'] as String, {
      for (final k in const ['doctors', 'doctorId', 'patientId'])
        if (data.containsKey(k)) k: data[k],
    });
  }

  @override
  Stream<RemoteSnapshot> watch(String section, String kind, {Scope? scope}) {
    Query<Map<String, dynamic>> q = _col(section, kind);
    if (scope != null) {
      q = scope.contains
          ? q.where(scope.field, arrayContains: scope.value)
          : q.where(scope.field, isEqualTo: scope.value);
    }
    return q
        .snapshots(includeMetadataChanges: true)
        .map(
          (q) => RemoteSnapshot([
            for (final d in q.docs) ?_doc(d),
          ], fromCache: q.metadata.isFromCache),
        );
  }

  @override
  Future<List<RemoteDoc>> fetch(String section, String kind) async {
    final q = await _col(
      section,
      kind,
    ).get(const GetOptions(source: Source.server));
    return [for (final d in q.docs) ?_doc(d)];
  }

  @override
  Future<void> put(
    String section,
    String kind,
    String id,
    String json, {
    String label = '',
    Map<String, Object?> fields = const {},
  }) => _col(section, kind).doc(id).set({
    'json': json,
    'label': label,
    ...fields,
    'by': FirebaseAuth.instance.currentUser?.email,
    'updatedAt': FieldValue.serverTimestamp(),
  });

  @override
  Future<void> remove(String section, String kind, String id) =>
      _col(section, kind).doc(id).delete();

  @override
  Future<void> upload(String section, String name, File file) async {
    await _files.ref('sections/$section/photos/$name').putFile(file);
  }

  @override
  Future<void> download(String section, String name, File dest) async {
    final tmp = File('${dest.path}.part');
    await _files.ref('sections/$section/photos/$name').writeToFile(tmp);
    await tmp.rename(dest.path);
  }
}
