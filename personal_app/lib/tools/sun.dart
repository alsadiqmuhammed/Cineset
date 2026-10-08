import 'dart:math';

/// حساب أوقات الشمس (معادلة الشروق المبسطة، دقتها حوالي دقيقة).
class SunTimes {
  final DateTime? dawnBlue, dawnGolden, sunrise, morningGoldenEnd;
  final DateTime? eveningGoldenStart, sunset, duskGolden, duskBlue;
  const SunTimes(
    this.dawnBlue,
    this.dawnGolden,
    this.sunrise,
    this.morningGoldenEnd,
    this.eveningGoldenStart,
    this.sunset,
    this.duskGolden,
    this.duskBlue,
  );
}

double _rad(double d) => d * pi / 180;
double _deg(double r) => r * 180 / pi;

SunTimes sunTimes(DateTime day, double lat, double lon) {
  final noonUtc = DateTime.utc(day.year, day.month, day.day, 12);
  final jd = noonUtc.millisecondsSinceEpoch / 86400000 + 2440587.5;
  final n = (jd - 2451545.0 + 0.0008).roundToDouble();
  final jStar = n - lon / 360;
  final m = (357.5291 + 0.98560028 * jStar) % 360;
  final c =
      1.9148 * sin(_rad(m)) +
      0.02 * sin(_rad(2 * m)) +
      0.0003 * sin(_rad(3 * m));
  final lambda = (m + c + 180 + 102.9372) % 360;
  final jTransit =
      2451545 + jStar + 0.0053 * sin(_rad(m)) - 0.0069 * sin(_rad(2 * lambda));
  final sinDec = sin(_rad(lambda)) * sin(_rad(23.4397));
  final cosDec = cos(asin(sinDec));

  (DateTime?, DateTime?) at(double altitude) {
    final cosW =
        (sin(_rad(altitude)) - sin(_rad(lat)) * sinDec) /
        (cos(_rad(lat)) * cosDec);
    if (cosW.abs() > 1) return (null, null);
    final w = _deg(acos(cosW));
    DateTime toLocal(double j) => DateTime.fromMillisecondsSinceEpoch(
      ((j - 2440587.5) * 86400000).round(),
      isUtc: true,
    ).toLocal();
    return (toLocal(jTransit - w / 360), toLocal(jTransit + w / 360));
  }

  final blue = at(-6), golden = at(-4), rise = at(-0.833), high = at(6);
  return SunTimes(
    blue.$1,
    golden.$1,
    rise.$1,
    high.$1,
    high.$2,
    rise.$2,
    golden.$2,
    blue.$2,
  );
}
