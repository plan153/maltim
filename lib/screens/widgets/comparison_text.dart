import 'package:flutter/material.dart';
import 'package:pronunciation_engine/pronunciation_engine.dart';

import '../../app/theme.dart';
import '../../services/app_language.dart';

/// 발음 분석 결과를 문절(청크) 단위로 묶어 보여주는 위젯.
///
/// 일본어는 문자 단위로 정렬되므로, 각 청크가 차지하는 정규화 문자 수만큼
/// 정렬 결과를 소비하여 청크 블록으로 묶는다.
class ComparisonText extends StatelessWidget {
  final List<AlignmentWord> alignedWords;
  final List<String> chunks;
  final Function(String chunk)? onChunkTap;

  const ComparisonText({
    super.key,
    required this.alignedWords,
    required this.chunks,
    this.onChunkTap,
  });

  /// 정렬 결과를 청크별 그룹으로 나눈다.
  List<List<AlignmentWord>> _groupByChunks() {
    final groups = <List<AlignmentWord>>[];
    var idx = 0;

    for (var c = 0; c < chunks.length; c++) {
      final tokensInChunk = appLanguage.tokenize(chunks[c]).length;
      final group = <AlignmentWord>[];
      var consumed = 0;

      while (idx < alignedWords.length && consumed < tokensInChunk) {
        final w = alignedWords[idx];
        group.add(w);
        if (w.status != WordStatus.extra) {
          consumed++;
        }
        idx++;
      }

      // 마지막 청크에는 남은 extra 토큰까지 포함
      if (c == chunks.length - 1) {
        while (idx < alignedWords.length) {
          group.add(alignedWords[idx]);
          idx++;
        }
      }
      groups.add(group);
    }
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (alignedWords.isEmpty) {
      return const Center(
        child: Text(
          '발음 분석 결과가 여기에 표시됩니다.',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 15,
            fontStyle: FontStyle.italic,
          ),
          textAlign: TextAlign.center,
        ),
      );
    }

    final grouped = _groupByChunks();

    return Wrap(
      spacing: 12.0,
      runSpacing: 12.0,
      children: List.generate(grouped.length, (index) {
        return _chunkBlock(chunks[index], grouped[index]);
      }),
    );
  }

  Widget _chunkBlock(String chunkText, List<AlignmentWord> group) {
    return GestureDetector(
      onTap: () => onChunkTap?.call(chunkText),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          constraints: const BoxConstraints(minWidth: 60, maxWidth: 340),
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.012),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: Colors.white.withValues(alpha: 0.04)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // 청크 라벨
              Text(
                chunkText,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 6),
              // 문자 단위 결과 (붙여서 표시)
              Wrap(
                spacing: 2.0,
                runSpacing: 6.0,
                children: group.map(_charBox).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _charBox(AlignmentWord w) {
    switch (w.status) {
      case WordStatus.match:
        return _box(w.targetWord, AppColors.success, false);
      case WordStatus.mismatch:
        return _box(w.targetWord, AppColors.danger, false,
            sub: w.spokenWord);
      case WordStatus.missing:
        return _box(w.targetWord, Colors.grey, true);
      case WordStatus.extra:
        return _box(w.spokenWord, AppColors.warning, false, prefix: '+');
      case WordStatus.unknown:
        // 한자/가나 표기 차이로 일치 여부를 판단할 수 없는 경우.
        // 오답(red)이 아닌 중립 색으로만 표시하고, 글자 단위 1:1 대응이
        // 부정확할 수 있는 인식 표기(한자)는 노출하지 않는다.
        return _box(w.targetWord, AppColors.primary, false);
    }
  }

  Widget _box(String text, Color color, bool strikethrough,
      {String? sub, String prefix = '', String subPrefix = '🗣'}) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 3),
          decoration: BoxDecoration(
            // 분석 결과는 보조 정보이므로 아주 약한 톤으로 표시한다.
            color: color.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: color.withValues(alpha: 0.12)),
          ),
          child: Text(
            '$prefix$text',
            style: TextStyle(
              color: color.withValues(alpha: 0.75),
              fontSize: 16,
              fontWeight: FontWeight.w500,
              decoration:
                  strikethrough ? TextDecoration.lineThrough : null,
              decorationColor: color.withValues(alpha: 0.5),
            ),
          ),
        ),
        if (sub != null && sub.isNotEmpty)
          Text(
            '$subPrefix$sub',
            style: TextStyle(
              color: subPrefix == '🗣' ? AppColors.warning : AppColors.primary,
              fontSize: 10,
            ),
          ),
      ],
    );
  }
}
