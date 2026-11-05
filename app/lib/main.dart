import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'data/briefing_repo.dart';
import 'data/calendar.dart';
import 'data/location.dart';
import 'data/server_api.dart';
import 'data/settings.dart';
import 'ui/home_page.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Jua'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  final prefs = await SharedPreferences.getInstance();
  final client = http.Client();
  runApp(MaterialApp(
    title: '쏙비서',
    theme: ssokTheme(),
    home: HomePage(
      briefingRepo: BriefingRepo(client, prefs),
      api: ServerApi(client),
      store: SettingsStore(prefs),
      calendar: DeviceCalendarSource(),
      location: GeolocatorSource(),
    ),
  ));
}
