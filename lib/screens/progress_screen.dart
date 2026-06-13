import 'package:flutter/material.dart';
import 'package:pronunciation_engine/pronunciation_engine.dart';

import '../app/theme.dart';
import '../services/progress_service.dart';
import '../services/translation_service.dart';

/// 학습 통계 화면.
class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> {
  late Future<ProgressStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ProgressService.loadStats();
  }

  void _reload() {
    setState(() => _statsFuture = ProgressService.loadStats());
  }

  String _t(String key) => TranslationService.get(key);

  Future<void> _confirmReset() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_t('progress_reset'),
            style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(_t('progress_reset_confirm'),
            style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(_t('common_cancel'),
                style: const TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: Text(_t('common_delete'),
                style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ProgressService.clear();
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: FutureBuilder<ProgressStats>(
                  future: _statsFuture,
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent),
                      );
                    }
                    final stats = snapshot.data!;
                    if (stats.totalAttempts == 0) {
                      return _buildEmpty();
                    }
                    return _buildContent(stats);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.maybePop(context),
            icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
          ),
          const SizedBox(width: 4),
          Text(
            _t('progress_title'),
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _confirmReset,
            icon: const Icon(Icons.delete_outline, color: AppColors.textMuted),
            tooltip: _t('progress_reset'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.insights, color: Colors.white24, size: 64),
            const SizedBox(height: 16),
            Text(
              _t('progress_empty'),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 15, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(ProgressStats stats) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _metricCard(_t('progress_total'), '${stats.totalAttempts}',
                  AppColors.accent),
              const SizedBox(width: 12),
              _metricCard(_t('progress_best'),
                  stats.bestScore.toStringAsFixed(0), AppColors.success),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _metricCard(_t('stat_avg'),
                  stats.averageScore.toStringAsFixed(0), AppColors.warning),
              const SizedBox(width: 12),
              _metricCard(_t('progress_passed'), '${stats.passedCount()}',
                  AppColors.success),
            ],
          ),
          const SizedBox(height: 24),
          _buildByLevel(stats),
          const SizedBox(height: 24),
          _buildRecent(stats),
        ],
      ),
    );
  }

  Widget _metricCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: AppTheme.panelDecoration(),
        child: Column(
          children: [
            Text(
              value,
              style: TextStyle(
                color: color,
                fontSize: 30,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildByLevel(ProgressStats stats) {
    final byLevel = stats.attemptsByLevel;
    // 일본어는 단어 레벨 미사용 → 문장/문절/입툭튀만 표시
    final levels = [
      PracticeLevel.sentence,
      PracticeLevel.chunk,
      PracticeLevel.recall,
    ];
    final maxCount = levels
        .map((l) => byLevel[l] ?? 0)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('progress_by_level'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 16),
          for (final level in levels)
            _levelBar(
              level == PracticeLevel.chunk ? '문절' : level.labelKo,
              byLevel[level] ?? 0,
              maxCount,
            ),
        ],
      ),
    );
  }

  Widget _levelBar(String label, int count, int maxCount) {
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 54,
            child: Text(
              label,
              style:
                  const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 10,
                backgroundColor: Colors.white.withValues(alpha: 0.06),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 28,
            child: Text(
              '$count',
              textAlign: TextAlign.end,
              style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecent(ProgressStats stats) {
    final recent = stats.recent(8);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            _t('progress_recent'),
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          for (final a in recent) _recentRow(a),
        ],
      ),
    );
  }

  Widget _recentRow(PracticeAttempt a) {
    final color = AppColors.forScore(a.score);
    final levelLabel =
        a.level == PracticeLevel.chunk ? '문절' : a.level.labelKo;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: AppColors.accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              levelLabel,
              style: const TextStyle(color: AppColors.accent, fontSize: 11),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _formatTime(a.timestamp),
              style: const TextStyle(color: AppColors.textMuted, fontSize: 12),
            ),
          ),
          Text(
            a.score.toStringAsFixed(0),
            style: TextStyle(
                color: color, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${t.month}/${t.day} ${two(t.hour)}:${two(t.minute)}';
  }
}
