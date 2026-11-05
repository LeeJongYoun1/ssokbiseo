import 'dart:convert';

import 'package:http/http.dart' as http;

import '../config.dart' as cfg;

class ServerException implements Exception {
  final String message;
  const ServerException(this.message);
  @override
  String toString() => 'ServerException: $message';
}

class Weather {
  final num tempC;
  final String sky, rain;
  final num popMax;
  final num? tmin, tmax;
  const Weather(this.tempC, this.sky, this.rain, this.popMax, this.tmin, this.tmax);
  factory Weather.fromJson(Map<String, dynamic> j) => Weather(
      j['tempC'] as num, j['sky'] as String, j['rain'] as String,
      j['popMax'] as num, j['tmin'] as num?, j['tmax'] as num?);
}

class Place {
  final String name, address;
  final double lat, lon;
  const Place(this.name, this.address, this.lat, this.lon);
  factory Place.fromJson(Map<String, dynamic> j) => Place(j['name'] as String,
      j['address'] as String, (j['lat'] as num).toDouble(), (j['lon'] as num).toDouble());
  Map<String, dynamic> toJson() =>
      {'name': name, 'address': address, 'lat': lat, 'lon': lon};
}

class RouteTime {
  final int? carMin, transitMin;
  final bool transitBlocked;
  const RouteTime(this.carMin, this.transitMin, this.transitBlocked);
  factory RouteTime.fromJson(Map<String, dynamic> j) => RouteTime(
      (j['carMin'] as num?)?.toInt(), (j['transitMin'] as num?)?.toInt(),
      j['transitBlocked'] as bool? ?? false);
}

class ServerApi {
  final http.Client _c;
  final String base, appKey;
  final Duration timeout;
  ServerApi(this._c,
      {this.base = cfg.serverBase,
      this.appKey = cfg.appKey,
      this.timeout = const Duration(seconds: 5)});

  Future<Map<String, dynamic>> _get(String path, Map<String, String> q) async {
    try {
      final r = await _c
          .get(Uri.parse('$base$path').replace(queryParameters: q),
              headers: {'x-ssok-key': appKey})
          .timeout(timeout);
      if (r.statusCode != 200) throw ServerException('HTTP ${r.statusCode}');
      return jsonDecode(utf8.decode(r.bodyBytes)) as Map<String, dynamic>;
    } on ServerException {
      rethrow;
    } catch (e) {
      throw ServerException('$e'); // 타임아웃·네트워크·파싱 실패 모두
    }
  }

  Future<T> _parse<T>(Future<Map<String, dynamic>> f, T Function(Map<String, dynamic>) p) async {
    final j = await f;
    try {
      return p(j);
    } catch (e) {
      throw ServerException('bad body: $e');
    }
  }

  Future<Weather> weather(double lat, double lon) => _parse(
      _get('/api/weather', {'lat': '$lat', 'lon': '$lon'}), Weather.fromJson);

  Future<List<Place>> geocode(String q) => _parse(
      _get('/api/geocode', {'q': q}),
      (j) => (j['items'] as List)
          .map((e) => Place.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList());

  Future<RouteTime> route(Place from, Place to) => _parse(
      _get('/api/route', {
        'fromLat': '${from.lat}', 'fromLon': '${from.lon}',
        'toLat': '${to.lat}', 'toLon': '${to.lon}',
      }),
      RouteTime.fromJson);
}
