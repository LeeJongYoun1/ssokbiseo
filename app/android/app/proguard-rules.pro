# device_calendar는 Gson으로 모델 필드명을 JSON 키로 쓴다. R8이 이름을 바꾸면 Dart 쪽에서 캘린더 id가 null이 된다.
-keep class com.builttoroam.devicecalendar.** { *; }
