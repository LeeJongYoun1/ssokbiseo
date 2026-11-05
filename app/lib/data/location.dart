import 'package:geolocator/geolocator.dart';

/// GPS(위치 서비스)가 꺼져 있을 때 loadRoutes가 던진다.
class GpsOff implements Exception {
  const GpsOff();
}

/// null = 권한 없음(또는 위치 꺼짐)
abstract class LocationSource {
  Future<(double, double)?> current();
  Future<bool> serviceOn() async => true;
  Future<bool> request() async => false;
}

bool _ok(LocationPermission p) =>
    p == LocationPermission.whileInUse || p == LocationPermission.always;

class GeolocatorSource extends LocationSource {
  @override
  Future<bool> serviceOn() => Geolocator.isLocationServiceEnabled();

  @override
  Future<bool> request() async {
    if (!await serviceOn()) {
      await Geolocator.openLocationSettings();
      return false;
    }
    final p = await Geolocator.requestPermission();
    // 다시 묻지 않음: 시스템 창이 못 뜨니 앱 설정으로 보낸다
    if (p == LocationPermission.deniedForever) await Geolocator.openAppSettings();
    return _ok(p);
  }

  @override
  Future<(double, double)?> current() async {
    try {
      if (!_ok(await Geolocator.checkPermission())) return null;
      try {
        final p = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
                accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 5)));
        return (p.latitude, p.longitude);
      } catch (_) {
        final p = await Geolocator.getLastKnownPosition();
        return p == null ? null : (p.latitude, p.longitude);
      }
    } catch (_) {
      return null;
    }
  }
}
