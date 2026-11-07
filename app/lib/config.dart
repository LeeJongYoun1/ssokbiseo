import 'package:flutter/foundation.dart';

// 값은 빌드 때 --dart-define 으로만 넣는다(저장소에 없음).
const serverBase = String.fromEnvironment('SSOK_SERVER');
const appKey = String.fromEnvironment('SSOK_APP_KEY');

/// 값 없이 빌드하면 서버 호출이 전부 실패하므로 시작할 때 눈에 띄게 알린다.
void warnIfConfigMissing() {
  if (serverBase.isEmpty || appKey.isEmpty) {
    debugPrint('SSOK_SERVER / SSOK_APP_KEY 없이 빌드됨 — --dart-define 필요');
  }
}

/// 서버 주소 없이 빌드하면 예시 모드(키 필요한 부분을 가짜 값으로 채움).
const bool kDemo = serverBase == '';
