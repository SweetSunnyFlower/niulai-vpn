import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

String _dateKey(DateTime time) {
  final date = DateTime(time.year, time.month, time.day);
  return '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}

class TrafficHour {
  TrafficHour({this.upload = 0, this.download = 0});

  int upload;
  int download;

  Map<String, dynamic> toJson() => {'upload': upload, 'download': download};

  factory TrafficHour.fromJson(Map<String, dynamic> json) {
    return TrafficHour(
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
    );
  }
}

class TrafficDay {
  TrafficDay({
    required this.date,
    this.upload = 0,
    this.download = 0,
    this.durationSeconds = 0,
    Map<int, TrafficHour>? hours,
  }) : hours = hours ?? {};

  final DateTime date;
  int upload;
  int download;
  int durationSeconds;
  final Map<int, TrafficHour> hours;

  void addTraffic(int hour, int uploadBytes, int downloadBytes) {
    upload += uploadBytes;
    download += downloadBytes;
    final item = hours.putIfAbsent(hour, () => TrafficHour());
    item.upload += uploadBytes;
    item.download += downloadBytes;
  }

  void addDuration(int seconds) {
    durationSeconds += seconds;
  }

  Map<String, dynamic> toJson() => {
    'date': _dateKey(date),
    'upload': upload,
    'download': download,
    'duration_seconds': durationSeconds,
    'hours': hours.map((key, value) => MapEntry('$key', value.toJson())),
  };

  factory TrafficDay.fromJson(Map<String, dynamic> json) {
    final rawHours = json['hours'] as Map<String, dynamic>? ?? const {};
    final hours = <int, TrafficHour>{};
    rawHours.forEach((key, value) {
      final hour = int.tryParse(key);
      if (hour != null && value is Map<String, dynamic>) {
        hours[hour] = TrafficHour.fromJson(value);
      }
    });
    return TrafficDay(
      date: DateTime.parse(json['date'] as String),
      upload: (json['upload'] as num?)?.toInt() ?? 0,
      download: (json['download'] as num?)?.toInt() ?? 0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      hours: hours,
    );
  }
}

class TrafficHistoryStore {
  static const _storageKey = 'traffic_history_v1';

  Future<Map<String, dynamic>> _loadRaw() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return {};
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {
      return {};
    }
    return {};
  }

  Future<void> _save(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  Future<void> addTraffic({
    required DateTime time,
    required int uploadBytes,
    required int downloadBytes,
  }) async {
    final data = await _loadRaw();
    final key = _dateKey(time);
    final rawDay = data[key];
    final day = rawDay is Map<String, dynamic>
        ? TrafficDay.fromJson(rawDay)
        : TrafficDay(date: _dateOnly(time));
    day.addTraffic(time.hour, uploadBytes, downloadBytes);
    data[key] = day.toJson();
    await _save(data);
  }

  Future<void> addDuration({
    required DateTime start,
    required DateTime end,
  }) async {
    final seconds = end.difference(start).inSeconds;
    if (seconds <= 0) {
      return;
    }
    final data = await _loadRaw();
    final key = _dateKey(start);
    final rawDay = data[key];
    final day = rawDay is Map<String, dynamic>
        ? TrafficDay.fromJson(rawDay)
        : TrafficDay(date: _dateOnly(start));
    day.addDuration(seconds);
    data[key] = day.toJson();
    await _save(data);
  }

  Future<List<TrafficDay>> loadDays(DateTime start, DateTime end) async {
    final data = await _loadRaw();
    final result = data.entries
        .map((entry) {
          final value = entry.value;
          if (value is! Map<String, dynamic>) {
            return null;
          }
          final day = TrafficDay.fromJson(value);
          final matches =
              !day.date.isBefore(_dateOnly(start)) &&
              !day.date.isAfter(_dateOnly(end));
          return matches ? day : null;
        })
        .whereType<TrafficDay>()
        .toList();
    result.sort((a, b) => a.date.compareTo(b.date));
    return result;
  }

  Future<void> pruneBefore(DateTime cutoff) async {
    final data = await _loadRaw();
    final target = _dateOnly(cutoff);
    data.removeWhere((key, value) {
      if (value is! Map<String, dynamic>) {
        return true;
      }
      return TrafficDay.fromJson(value).date.isBefore(target);
    });
    await _save(data);
  }

  DateTime _dateOnly(DateTime time) =>
      DateTime(time.year, time.month, time.day);
}
