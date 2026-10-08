import 'package:flutter_test/flutter_test.dart';
import 'package:personal_app/tools/sun.dart';

void main() {
  test('Basra sunrise and sunset on 2026-10-08 (UTC)', () {
    final s = sunTimes(DateTime(2026, 10, 8), 30.5085, 47.7804);
    // Solar noon ~08:37 UTC (47.78°E, equation of time +12 min), day ~11h40m.
    final rise = s.sunrise!.toUtc(), set = s.sunset!.toUtc();
    expect(rise.hour * 60 + rise.minute, closeTo(2 * 60 + 47, 5));
    expect(set.hour * 60 + set.minute, closeTo(14 * 60 + 27, 5));
    expect(s.dawnBlue!.isBefore(s.dawnGolden!), isTrue);
    expect(s.duskGolden!.isBefore(s.duskBlue!), isTrue);
  });
}
