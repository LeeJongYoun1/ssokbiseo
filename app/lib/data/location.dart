import 'package:geolocator/geolocator.dart';

/// null = 권한 없음(또는 위치 꺼짐)
abstract class LocationSource {
  Future<(double, double)?> current();
  Future<bool> request() async => false;
}

bool _ok(LocationPermission p) =>
    p == LocationPermission.whileInUse || p == LocationPermission.always;

class GeolocatorSource extends LocationSource {
  @override
  Future<bool> request() async => _ok(await Geolocator.requestPermission());

  @override
  Future<(double, double)?> current() async {
    try {
      if (!_ok(await Geolocator.checkPermission())) return null;
      final p = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(accuracy: LocationAccuracy.low));
      return (p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}
