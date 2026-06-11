import 'dart:convert';

import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 한 번의 발음 연습 시도 기록.
class PracticeAttempt {
  final String sentenceId;
  final PracticeLevel level;
  final double score; // 0~100
  final DateTime timestamp;

  const PracticeAttempt({
    required this.sentenceId,
    required this.level,
    required this.score,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'sentenceId': sentenceId,
        'level': level.name,
        'score': score,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PracticeAttempt.fromJson(Map<String, dynamic> json) {
    return PracticeAttempt(
      sentenceId: json['sentenceId']?.toString() ?? '',
      level: PracticeLevel.values.firstWhere(
        (l) => l.name == json['level'],
        orElse: () => PracticeLevel.sentence,
      ),
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      timestamp: DateTime.tryParse(json['timestamp']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

/// 연습 기록으로부터 계산되는 통계. 순수 로직이라 단위 테스트가 쉽다.
class ProgressStats {
  final List<PracticeAttempt> attempts;

  const ProgressStats(this.attempts);

  int get totalAttempts => attempts.length;

  double get averageScore {
    if (attempts.isEmpty) return 0.0;
    final sum = attempts.fold<double>(0, (a, b) => a + b.score);
    return sum / attempts.length;
  }

  double get bestScore {
    if (attempts.isEmpty) return 0.0;
    return attempts.map((a) => a.score).reduce((a, b) => a > b ? a : b);
  }

  int passedCount({double threshold = 85.0}) =>
      attempts.where((a) => a.score >= threshold).length;

  double? bestScoreFor(String sentenceId) {
    final scores =
        attempts.where((a) => a.sentenceId == sentenceId).map((a) => a.score);
    if (scores.isEmpty) return null;
    return scores.reduce((a, b) => a > b ? a : b);
  }

  int get uniqueSentencesPracticed =>
      attempts.map((a) => a.sentenceId).toSet().length;

  Map<PracticeLevel, int> get attemptsByLevel {
    final map = {for (final l in PracticeLevel.values) l: 0};
    for (final a in attempts) {
      map[a.level] = (map[a.level] ?? 0) + 1;
    }
    return map;
  }

  /// [now] 기준 연속 학습 일수(streak).
  int streakDays(DateTime now) {
    if (attempts.isEmpty) return 0;
    final days = attempts
        .map((a) =>
            DateTime(a.timestamp.year, a.timestamp.month, a.timestamp.day))
        .toSet();
    var cursor = DateTime(now.year, now.month, now.day);

    if (!days.contains(cursor)) {
      cursor = cursor.subtract(const Duration(days: 1));
      if (!days.contains(cursor)) return 0;
    }

    var streak = 0;
    while (days.contains(cursor)) {
      streak++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return streak;
  }

  List<PracticeAttempt> recent(int n) {
    final sorted = [...attempts]
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return sorted.take(n).toList();
  }
}

/// 연습 기록을 shared_preferences에 영속화하는 서비스.
class ProgressService {
  static const String _key = 'practice_attempts_v1';

  static Future<List<PracticeAttempt>> loadAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => PracticeAttempt.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<ProgressStats> loadStats() async {
    return ProgressStats(await loadAttempts());
  }

  static Future<void> recordAttempt(PracticeAttempt attempt) async {
    final prefs = await SharedPreferences.getInstance();
    final attempts = await loadAttempts()
      ..add(attempt);
    await prefs.setString(
      _key,
      jsonEncode(attempts.map((a) => a.toJson()).toList()),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
