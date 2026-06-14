import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pronunciation_engine/pronunciation_engine.dart';

import '../app/theme.dart';
import '../services/progress_service.dart';
import '../services/translation_service.dart';
import '../services/tts_service.dart';

/// 앱 첫 화면. 브랜딩, 3단계 안내(문장/문절/말툭튀), 학습 현황 요약, 연습 시작 CTA.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<ProgressStats> _statsFuture;

  @override
  void initState() {
    super.initState();
    _statsFuture = ProgressService.loadStats();
  }

  void _refresh() {
    setState(() => _statsFuture = ProgressService.loadStats());
  }

  String _t(String key) => TranslationService.get(key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildTopBar(),
                const SizedBox(height: 28),
                _buildHero(),
                const SizedBox(height: 28),
                _buildStatsCard(),
                const SizedBox(height: 28),
                _buildStartButton(),
                const SizedBox(height: 32),
                _buildLevelsSection(),
                const SizedBox(height: 24),
                _buildSecondaryActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                gradient: AppColors.brandGradient,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Center(
                child: Text('あ',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              _t('app_title'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home_tagline'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 30,
            fontWeight: FontWeight.bold,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          _t('home_subtitle'),
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 15,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsCard() {
    return FutureBuilder<ProgressStats>(
      future: _statsFuture,
      builder: (context, snapshot) {
        final stats = snapshot.data ?? const ProgressStats([]);
        final streak = stats.streakDays(DateTime.now());
        final avg = stats.averageScore;
        final sentences = stats.uniqueSentencesPracticed;
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: AppTheme.panelDecoration(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _t('home_progress_title'),
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _statTile('🔥', '$streak',
                      '${_t('stat_streak')} (${_t('stat_days')})'),
                  _statTile('⭐', avg == 0 ? '-' : avg.toStringAsFixed(0),
                      _t('stat_avg')),
                  _statTile('📚', '$sentences', _t('stat_sentences')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _statTile(String emoji, String value, String label) {
    return Expanded(
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.accent,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return GestureDetector(
      onTap: () {
        TtsService.unlockAudioEngine();
        context.push('/practice').then((_) => _refresh());
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: BoxDecoration(
          gradient: AppColors.brandGradient,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.4),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.play_circle_fill, color: Colors.white, size: 24),
            const SizedBox(width: 10),
            Text(
              _t('home_start'),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _t('home_levels_title'),
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 14),
        _levelRow(Icons.notes, '문장', _t('level_sentence_desc'),
            PracticeLevel.sentence),
        const SizedBox(height: 10),
        _levelRow(Icons.view_agenda, '문절', _t('level_chunk_desc'),
            PracticeLevel.chunk),
        const SizedBox(height: 10),
        _levelRow(Icons.lightbulb, '말툭튀', _t('level_recall_desc'),
            PracticeLevel.recall),
      ],
    );
  }

  Widget _levelRow(
      IconData icon, String title, String desc, PracticeLevel level) {
    return GestureDetector(
      onTap: () {
        TtsService.unlockAudioEngine();
        context.push('/practice', extra: level).then((_) => _refresh());
      },
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: AppTheme.panelDecoration(),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.accent, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    desc,
                    style: const TextStyle(
                        color: AppColors.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildSecondaryActions() {
    return Row(
      children: [
        Expanded(
          child: _secondaryButton(
            Icons.bar_chart,
            _t('home_view_progress'),
            () => context.push('/progress').then((_) => _refresh()),
          ),
        ),
        const SizedBox(width: 12),
        _secondaryIconButton(
          Icons.admin_panel_settings,
          () => context.push('/admin').then((_) => _refresh()),
        ),
      ],
    );
  }

  Widget _secondaryButton(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textSecondary, size: 18),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _secondaryIconButton(IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Icon(icon, color: AppColors.textSecondary, size: 20),
      ),
    );
  }
}
