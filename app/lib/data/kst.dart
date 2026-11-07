String kstToday(DateTime now) =>
    now.toUtc().add(const Duration(hours: 9)).toIso8601String().substring(0, 10);
