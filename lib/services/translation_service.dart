/// 앱 UI 문자열 (한국어 기본 / 영어 보조).
///
/// 대상 사용자는 한국인 일본어 학습자이므로 UI는 한국어가 기본이다.
class TranslationService {
  /// true면 한국어 UI.
  static bool isKorean = true;

  static String get(String key) {
    if (isKorean) {
      return _ko[key] ?? key;
    }
    return _en[key] ?? _ko[key] ?? key;
  }

  static const Map<String, String> _ko = {
    'app_title': '말트임 일본어',
    'live_mic': '음성 인식 작동 중 🎙️',
    'demo_active': '데모 모드 활성화 🛠️',
    'sentence_label': '문장',
    'listen': '듣기',
    'repeat': '반복',
    'continuous_listen': '연속듣기',
    'stop': '정지',
    'instruction_default': '마이크 버튼을 누르고 문장을 큰 소리로 따라 말해 보세요.',
    'instruction_demo': '데모 모드입니다. 마이크를 탭하면 가상 발음이 시뮬레이션됩니다.',
    'instruction_analyzing': '발음을 분석하는 중입니다...',
    'instruction_listening': '듣고 있습니다... 말씀해 보세요!',
    'instruction_no_speech': '음성이 감지되지 않았습니다. 마이크를 다시 탭해 보세요.',
    'instruction_complete': '발음 분석 완료!',
    'sim_accuracy': '시뮬레이션 정확도:',
    'score_title': '발음 점수',
    'feedback_excellent': '훌륭한 발음입니다! 이대로 계속해 보세요!',
    'feedback_decent': '좋습니다! 조금만 더 가다듬어 볼까요?',
    'feedback_poor': '천천히 또박또박 연습해 보세요.',
    'detail_title': '발음 상세 분석:',
    'tips_title': '상세 교정 팁:',
    'help_title': '학습 가이드',
    'help_content': '1. 상단의 일본어 문장을 확인합니다.\n'
        '2. [듣기]로 원어민 발음을 듣습니다. 반복 횟수(1~3회)를 고를 수 있습니다.\n'
        '3. 하단 마이크 버튼을 탭하고 문장을 큰 소리로 따라 말합니다.\n'
        '4. 분석 결과에서 정확한 부분(녹색)과 틀린 부분(적색)을 확인하세요.\n'
        '5. [연속듣기]는 현재 문장부터 끝까지 자동으로 들려줍니다.',
    'help_gotit': '확인했습니다!',
    'settings_title': '설정',
    'settings_mode_real': '실제 마이크 녹음',
    'settings_mode_demo': '시뮬레이션 데모 모드',
    'settings_voice_label': '원어민 목소리',
    'settings_cancel': '취소',
    'settings_save': '저장 및 적용',
    'say_words': '문장을 말씀해 보세요...',
    'show_translation': '뜻 보기 👁️',
    'hide_translation': '뜻 숨기기 🙈',
    'show_reading': '읽기(가나) 보기',
    'hide_reading': '읽기 숨기기',
    // 홈
    'home_tagline': '입으로 익히는 진짜 일본어',
    'home_subtitle': '문장 · 문절 단위로 듣고 따라 말하세요',
    'home_start': '오늘의 연습 시작',
    'home_levels_title': '3단계로 쉽게',
    'level_sentence_desc': '문장 전체를 한 번에 듣고 따라하기',
    'level_chunk_desc': '의미 덩어리(문절)로 나눠서 연습',
    'level_recall_desc': '안 보고 바로 말로 툭 튀어나오게',
    'home_progress_title': '나의 학습 현황',
    'stat_streak': '연속 학습',
    'stat_avg': '평균 점수',
    'stat_sentences': '연습 문장',
    'stat_days': '일',
    'home_view_progress': '학습 통계 보기',
    'level_select': '연습 단위 선택',
    'pick_chunk': '연습할 문절을 선택하세요',
    // 통계
    'progress_title': '학습 통계',
    'progress_empty': '아직 연습 기록이 없어요. 첫 연습을 시작해 보세요!',
    'progress_total': '총 연습 횟수',
    'progress_best': '최고 점수',
    'progress_passed': '합격 (85점+)',
    'progress_by_level': '단위별 연습',
    'progress_recent': '최근 기록',
    'progress_reset': '기록 초기화',
    'progress_reset_confirm': '모든 학습 기록을 삭제할까요?',
    'common_cancel': '취소',
    'common_delete': '삭제',
    // 관리자
    'no_sentences': '등록된 연습 문장이 없습니다.',
    'admin_guide': '관리자 패널로 이동하여 문장을 추가하거나 업로드해 주세요.',
    'go_admin': '관리자 패널로 이동',
    'admin_panel': '관리자 패널 🛠️',
    'admin_add_sentence': '새 연습 문장 추가',
    'admin_input_text': '일본어 문장',
    'admin_input_reading': '읽기 (히라가나, 선택)',
    'admin_input_translation': '한국어 뜻',
    'admin_input_category': '카테고리 (예: Day 1)',
    'admin_input_chunks': '문절 청크 (공백 또는 / 로 구분)',
    'admin_btn_add': '문장 추가',
    'admin_paste_json': 'JSON 붙여넣어 가져오기',
    'admin_btn_import': '가져오기',
    'admin_export_json': 'JSON 내보내기',
    'admin_btn_reset': '기본 문장으로 초기화',
    'admin_sentence_list': '등록된 연습 문장',
    'admin_err_invalid_json': '올바르지 않은 JSON 형식입니다.',
    'admin_success_import': '가져오기 완료!',
    'admin_sentence_added': '새 문장이 추가되었습니다.',
  };

  static const Map<String, String> _en = {
    'app_title': 'Maltuim Japanese',
    'home_tagline': 'Real Japanese, spoken out loud',
    'listen': 'Listen',
    'repeat': 'Repeat',
    'continuous_listen': 'Play All',
    'stop': 'Stop',
  };
}
