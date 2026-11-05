import 'dart:math';

/// 두 지점 사이 큰 원 거리(km), haversine
double distanceKm(double lat1, double lon1, double lat2, double lon2) {
  double r(double d) => d * pi / 180;
  final a = pow(sin(r(lat2 - lat1) / 2), 2) +
      cos(r(lat1)) * cos(r(lat2)) * pow(sin(r(lon2 - lon1) / 2), 2);
  return 2 * 6371 * asin(sqrt(a));
}
