import 'package:flutter/material.dart';
import 'package:pronunciation_engine/pronunciation_engine.dart';

import '../app/theme.dart';
import '../services/sentence_storage_service.dart';
import '../services/translation_service.dart';

/// 문장 DB 관리 화면.
///
/// - 새 문장 추가 (일본어/읽기/뜻/카테고리/문절 청크)
/// - JSON 붙여넣어 일괄 가져오기 (말트임 커리큘럼 반영용)
/// - JSON 내보내기, 기본값 초기화, 목록/삭제
class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  List<PracticeSentence> _sentences = [];
  bool _isLoading = true;

  final _textCtrl = TextEditingController();
  final _readingCtrl = TextEditingController();
  final _translationCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();
  final _chunksCtrl = TextEditingController();
  final _jsonCtrl = TextEditingController();

  String _t(String key) => TranslationService.get(key);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _readingCtrl.dispose();
    _translationCtrl.dispose();
    _categoryCtrl.dispose();
    _chunksCtrl.dispose();
    _jsonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final loaded = await SentenceStorageService.loadSentences();
    if (!mounted) return;
    setState(() {
      _sentences = loaded;
      _isLoading = false;
    });
  }

  void _snack(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.danger : AppColors.success,
    ));
  }

  Future<void> _addSentence() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    // 문절 청크: 공백 또는 / 로 구분. 비어 있으면 문장 전체 하나.
    final chunkRaw = _chunksCtrl.text.trim();
    final chunks = chunkRaw.isEmpty
        ? [text]
        : chunkRaw
            .split(RegExp(r'[/\s]+'))
            .where((s) => s.isNotEmpty)
            .toList();

    final sentence = PracticeSentence(
      id: 'ja_${DateTime.now().millisecondsSinceEpoch}',
      text: text,
      reading: _readingCtrl.text.trim(),
      category: _categoryCtrl.text.trim().isEmpty
          ? 'General'
          : _categoryCtrl.text.trim(),
      chunks: chunks,
      translation: _translationCtrl.text.trim(),
    );
    final updated = await SentenceStorageService.addSentence(sentence);
    if (!mounted) return;
    setState(() {
      _sentences = updated;
      _textCtrl.clear();
      _readingCtrl.clear();
      _translationCtrl.clear();
      _chunksCtrl.clear();
    });
    _snack(_t('admin_sentence_added'));
  }

  Future<void> _importJson() async {
    final raw = _jsonCtrl.text.trim();
    if (raw.isEmpty) return;
    try {
      final updated = await SentenceStorageService.importFromJson(raw);
      if (!mounted) return;
      setState(() {
        _sentences = updated;
        _jsonCtrl.clear();
      });
      _snack('${_t('admin_success_import')} (${updated.length}문장)');
    } catch (e) {
      _snack('${_t('admin_err_invalid_json')}: $e', error: true);
    }
  }

  void _exportJson() {
    final jsonStr = SentenceStorageService.exportToJson(_sentences);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(_t('admin_export_json'),
            style: const TextStyle(color: AppColors.textPrimary)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: SelectableText(
              jsonStr,
              style: const TextStyle(
                  color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(_t('common_cancel')),
          ),
        ],
      ),
    );
  }

  Future<void> _reset() async {
    final updated = await SentenceStorageService.resetToDefaults();
    if (!mounted) return;
    setState(() => _sentences = updated);
  }

  Future<void> _delete(String id) async {
    final updated = await SentenceStorageService.deleteSentence(id);
    if (!mounted) return;
    setState(() => _sentences = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.bgGradient),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.maybePop(context),
                      icon: const Icon(Icons.arrow_back,
                          color: AppColors.textPrimary),
                    ),
                    Text(
                      _t('admin_panel'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: _reset,
                      child: Text(_t('admin_btn_reset'),
                          style: const TextStyle(
                              color: AppColors.textMuted, fontSize: 12)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(
                        child:
                            CircularProgressIndicator(color: AppColors.accent))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _buildAddCard(),
                            const SizedBox(height: 16),
                            _buildImportCard(),
                            const SizedBox(height: 16),
                            _buildListCard(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAddCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('admin_add_sentence'),
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          _field(_textCtrl, _t('admin_input_text')),
          const SizedBox(height: 8),
          _field(_readingCtrl, _t('admin_input_reading')),
          const SizedBox(height: 8),
          _field(_translationCtrl, _t('admin_input_translation')),
          const SizedBox(height: 8),
          _field(_categoryCtrl, _t('admin_input_category')),
          const SizedBox(height: 8),
          _field(_chunksCtrl, _t('admin_input_chunks')),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            onPressed: _addSentence,
            icon: const Icon(Icons.add),
            label: Text(_t('admin_btn_add')),
          ),
        ],
      ),
    );
  }

  Widget _buildImportCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(_t('admin_paste_json'),
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          TextField(
            controller: _jsonCtrl,
            maxLines: 5,
            style: const TextStyle(
                color: AppColors.textPrimary, fontSize: 12),
            decoration: InputDecoration(
              hintText:
                  '[{"id":"d1_01","text":"おはようございます。","reading":"おはようございます","category":"Day 1","chunks":["おはようございます"],"translation":"안녕하세요"}]',
              hintStyle:
                  const TextStyle(color: Colors.white24, fontSize: 11),
              border: const OutlineInputBorder(),
              enabledBorder: OutlineInputBorder(
                borderSide:
                    BorderSide(color: Colors.white.withValues(alpha: 0.1)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary),
                  onPressed: _importJson,
                  child: Text(_t('admin_btn_import'),
                      style: const TextStyle(color: Colors.white)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: _exportJson,
                  child: Text(_t('admin_export_json'),
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 12)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildListCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.panelDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('${_t('admin_sentence_list')} (${_sentences.length})',
              style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final s in _sentences)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(s.text,
                  style: const TextStyle(
                      color: AppColors.textPrimary, fontSize: 15)),
              subtitle: Text(
                '${s.translation}  ·  ${s.category}  ·  [${s.chunks.join(' / ')}]',
                style:
                    const TextStyle(color: AppColors.textMuted, fontSize: 11),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline,
                    color: AppColors.textMuted, size: 20),
                onPressed: () => _delete(s.id),
              ),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController ctrl, String label) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppColors.textMuted, fontSize: 12),
        border: const OutlineInputBorder(),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
        ),
        isDense: true,
      ),
    );
  }
}
