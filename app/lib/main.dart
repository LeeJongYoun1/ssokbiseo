import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
        ['Jua'], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });
  runApp(MaterialApp(
    title: '쏙비서',
    theme: ssokTheme(),
    home: const Scaffold(
      body: Center(
        child: Text('쏙비서',
            style: TextStyle(fontFamily: 'JuaTitle', fontSize: 48)),
      ),
    ),
  ));
}
