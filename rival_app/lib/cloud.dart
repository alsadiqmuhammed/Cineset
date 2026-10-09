import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';

import 'store.dart';
import 'sync.dart';

/// مشروع Firebase مال العيادة (من google-services.json).
const _options = FirebaseOptions(
  apiKey: 'AIzaSyDFehsWgf_Cx-Fa6eDvoiAXGBTCgpEIQvI',
  appId: '1:897577160241:android:fa6efcbec9292b4a3c4f10',
  messagingSenderId: '897577160241',
  projectId: 'rival-26719',
  storageBucket: 'rival-26719.firebasestorage.app',
);

/// قاعدة البيانات الموحدة: الدخول بحساب العيادة، وتشغيل المزامنة للقسم المفتوح.
/// إذا Firebase ما اشتغل (مثلاً بالاختبارات) التطبيق يكمل على بيانات الجهاز.
class Cloud extends ChangeNotifier {
  Cloud._();
  static final instance = Cloud._();

  bool available = false;
  SyncStatus status = SyncStatus.off;
  String? detail;
  SyncEngine? _engine;

  User? get user => available ? FirebaseAuth.instance.currentUser : null;
  bool get signedIn => user != null;

  Future<void> init() async {
    try {
      await Firebase.initializeApp(options: _options);
      available = true;
    } catch (e) {
      debugPrint('Firebase: $e');
      available = false;
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
    notifyListeners();
  }

  /// يشغّل المزامنة للقسم المفتوح بالمتجر.
  Future<void> attach(Store store) async {
    if (!signedIn) return;
    await detach();
    final engine = SyncEngine(
      store,
      FirebaseBackend(),
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
    try {
      final r = await InternetAddress.lookup('firestore.googleapis.com')
          .timeout(const Duration(seconds: 5));
      ok = r.isNotEmpty && r.first.rawAddress.isNotEmpty;
    } catch (_) {
      ok = false;
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
/// sections/{dental|beauty}/{patients|doctors|meta}/{id} و sections/{s}/photos/{name}
class FirebaseBackend implements SyncBackend {
  final _db = FirebaseFirestore.instance;
  final _files = FirebaseStorage.instance;

  CollectionReference<Map<String, dynamic>> _col(String s, String k) =>
      _db.collection('sections').doc(s).collection(k);

  @override
  Stream<RemoteSnapshot> watch(String section, String kind) =>
      _col(section, kind)
          .snapshots(includeMetadataChanges: true)
          .map(
            (q) => RemoteSnapshot([
              for (final d in q.docs)
                if (d.data()['json'] is String)
                  RemoteDoc(d.id, d.data()['json'] as String),
            ], fromCache: q.metadata.isFromCache),
          );

  @override
  Future<void> put(
    String section,
    String kind,
    String id,
    String json, {
    String label = '',
  }) => _col(section, kind).doc(id).set({
    'json': json,
    'label': label,
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
