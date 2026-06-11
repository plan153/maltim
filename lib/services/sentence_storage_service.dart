import 'dart:convert';
import 'package:pronunciation_engine/pronunciation_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 연습 문장 영속화 서비스 (shared_preferences).
///
/// 시드 데이터는 말트임 30일 커리큘럼 전체 예문(30일/98문장)이다.
/// 청크는 문절(文節) 단위: 명사+조사를 한 덩어리, 활용된 동사/형용사를 한 덩어리.
/// reading 필드에는 한국인 학습자용 한글 발음 표기를 담는다.
class SentenceStorageService {
  static const String _key = 'practice_sentences_ja_v2';

  /// 기본 시드 문장.
  static final List<PracticeSentence> _defaults = [
    // ─ Day 1 · 이동 동사 ─
    PracticeSentence(
      id: 'd01_1',
      text: 'がっこうに　いきます',
      reading: '각꼬우니 이키마스',
      category: 'Day 1 · 이동 동사',
      chunks: ['がっこうに', 'いきます'],
      translation: '학교에 갑니다',
    ),
    PracticeSentence(
      id: 'd01_2',
      text: 'うちに　かえります',
      reading: '우치니 카에리마스',
      category: 'Day 1 · 이동 동사',
      chunks: ['うちに', 'かえります'],
      translation: '집에 돌아갑니다',
    ),
    PracticeSentence(
      id: 'd01_3',
      text: 'まいにち　いきます',
      reading: '마이니치 이키마스',
      category: 'Day 1 · 이동 동사',
      chunks: ['まいにち', 'いきます'],
      translation: '매일 갑니다',
    ),
    // ─ Day 2 · 일과 공부 ─
    PracticeSentence(
      id: 'd02_1',
      text: 'しごとを　します',
      reading: '시고토오 시마스',
      category: 'Day 2 · 일과 공부',
      chunks: ['しごとを', 'します'],
      translation: '일을 합니다',
    ),
    PracticeSentence(
      id: 'd02_2',
      text: 'べんきょうを　します',
      reading: '벤쿄우오 시마스',
      category: 'Day 2 · 일과 공부',
      chunks: ['べんきょうを', 'します'],
      translation: '공부를 합니다',
    ),
    PracticeSentence(
      id: 'd02_3',
      text: 'しごとに　いきます',
      reading: '시고토니 이키마스',
      category: 'Day 2 · 일과 공부',
      chunks: ['しごとに', 'いきます'],
      translation: '일하러 갑니다',
    ),
    PracticeSentence(
      id: 'd02_4',
      text: 'たいへんです',
      reading: '타이헨데스',
      category: 'Day 2 · 일과 공부',
      chunks: ['たいへんです'],
      translation: '힘듭니다 / 대단합니다',
    ),
    // ─ Day 3 · 먹고 마시기 ─
    PracticeSentence(
      id: 'd03_1',
      text: 'レストランで　たべます',
      reading: '레스토란데 타베마스',
      category: 'Day 3 · 먹고 마시기',
      chunks: ['レストランで', 'たべます'],
      translation: '레스토랑에서 먹습니다',
    ),
    PracticeSentence(
      id: 'd03_2',
      text: 'みずを　のみます',
      reading: '미즈오 노미마스',
      category: 'Day 3 · 먹고 마시기',
      chunks: ['みずを', 'のみます'],
      translation: '물을 마십니다',
    ),
    PracticeSentence(
      id: 'd03_3',
      text: 'おいしいです',
      reading: '오이시이데스',
      category: 'Day 3 · 먹고 마시기',
      chunks: ['おいしいです'],
      translation: '맛있습니다',
    ),
    PracticeSentence(
      id: 'd03_4',
      text: 'なにを　たべますか',
      reading: '나니오 타베마스카',
      category: 'Day 3 · 먹고 마시기',
      chunks: ['なにを', 'たべますか'],
      translation: '무엇을 먹습니까?',
    ),
    // ─ Day 4 · 쇼핑 ─
    PracticeSentence(
      id: 'd04_1',
      text: 'スーパーで　かいます',
      reading: '스-파-데 카이마스',
      category: 'Day 4 · 쇼핑',
      chunks: ['スーパーで', 'かいます'],
      translation: '슈퍼에서 삽니다',
    ),
    PracticeSentence(
      id: 'd04_2',
      text: 'みせに　いきます',
      reading: '미세니 이키마스',
      category: 'Day 4 · 쇼핑',
      chunks: ['みせに', 'いきます'],
      translation: '가게에 갑니다',
    ),
    PracticeSentence(
      id: 'd04_3',
      text: 'なにを　かいますか',
      reading: '나니오 카이마스카',
      category: 'Day 4 · 쇼핑',
      chunks: ['なにを', 'かいますか'],
      translation: '무엇을 삽니까?',
    ),
    PracticeSentence(
      id: 'd04_4',
      text: 'たかいです',
      reading: '타카이데스',
      category: 'Day 4 · 쇼핑',
      chunks: ['たかいです'],
      translation: '비쌉니다',
    ),
    // ─ Day 5 · 존재 표현 ─
    PracticeSentence(
      id: 'd05_1',
      text: 'うちに　います',
      reading: '우치니 이마스',
      category: 'Day 5 · 존재 표현',
      chunks: ['うちに', 'います'],
      translation: '집에 있습니다',
    ),
    PracticeSentence(
      id: 'd05_2',
      text: 'ここに　あります',
      reading: '코코니 아리마스',
      category: 'Day 5 · 존재 표현',
      chunks: ['ここに', 'あります'],
      translation: '여기에 있습니다',
    ),
    PracticeSentence(
      id: 'd05_3',
      text: 'ともだちが　います',
      reading: '토모다치가 이마스',
      category: 'Day 5 · 존재 표현',
      chunks: ['ともだちが', 'います'],
      translation: '친구가 있습니다',
    ),
    PracticeSentence(
      id: 'd05_4',
      text: 'どこに　いますか',
      reading: '도코니 이마스카',
      category: 'Day 5 · 존재 표현',
      chunks: ['どこに', 'いますか'],
      translation: '어디에 있습니까?',
    ),
    // ─ Day 6 · 의문사 ─
    PracticeSentence(
      id: 'd06_1',
      text: 'いつ　いきますか',
      reading: '이츠 이키마스카',
      category: 'Day 6 · 의문사',
      chunks: ['いつ', 'いきますか'],
      translation: '언제 갑니까?',
    ),
    PracticeSentence(
      id: 'd06_2',
      text: 'どこに　いきますか',
      reading: '도코니 이키마스카',
      category: 'Day 6 · 의문사',
      chunks: ['どこに', 'いきますか'],
      translation: '어디에 갑니까?',
    ),
    PracticeSentence(
      id: 'd06_3',
      text: 'だれと　たべますか',
      reading: '다레토 타베마스카',
      category: 'Day 6 · 의문사',
      chunks: ['だれと', 'たべますか'],
      translation: '누구와 먹습니까?',
    ),
    PracticeSentence(
      id: 'd06_4',
      text: 'なんじに　きますか',
      reading: '난지니 키마스카',
      category: 'Day 6 · 의문사',
      chunks: ['なんじに', 'きますか'],
      translation: '몇 시에 옵니까?',
    ),
    // ─ Day 7 · 복합 표현 ─
    PracticeSentence(
      id: 'd07_1',
      text: 'がっこうで　べんきょうします',
      reading: '각꼬우데 벤쿄우시마스',
      category: 'Day 7 · 복합 표현',
      chunks: ['がっこうで', 'べんきょうします'],
      translation: '학교에서 공부합니다',
    ),
    PracticeSentence(
      id: 'd07_2',
      text: 'まいにち　しごとを　します',
      reading: '마이니치 시고토오 시마스',
      category: 'Day 7 · 복합 표현',
      chunks: ['まいにち', 'しごとを', 'します'],
      translation: '매일 일을 합니다',
    ),
    PracticeSentence(
      id: 'd07_3',
      text: 'ともだちと　みせに　いきます',
      reading: '토모다치토 미세니 이키마스',
      category: 'Day 7 · 복합 표현',
      chunks: ['ともだちと', 'みせに', 'いきます'],
      translation: '친구와 가게에 갑니다',
    ),
    // ─ Day 8 · 이동 ─
    PracticeSentence(
      id: 'd08_1',
      text: 'がっこうに　いきました',
      reading: '각꼬우니 이키마시타',
      category: 'Day 8 · 이동',
      chunks: ['がっこうに', 'いきました'],
      translation: '학교에 갔습니다',
    ),
    PracticeSentence(
      id: 'd08_2',
      text: 'うちに　かえりました',
      reading: '우치니 카에리마시타',
      category: 'Day 8 · 이동',
      chunks: ['うちに', 'かえりました'],
      translation: '집에 돌아갔습니다',
    ),
    PracticeSentence(
      id: 'd08_3',
      text: 'きのう　いきました',
      reading: '키노우 이키마시타',
      category: 'Day 8 · 이동',
      chunks: ['きのう', 'いきました'],
      translation: '어제 갔습니다',
    ),
    // ─ Day 9 · 음식 ─
    PracticeSentence(
      id: 'd09_1',
      text: 'すしを　たべました',
      reading: '스시오 타베마시타',
      category: 'Day 9 · 음식',
      chunks: ['すしを', 'たべました'],
      translation: '스시를 먹었습니다',
    ),
    PracticeSentence(
      id: 'd09_2',
      text: 'コーヒーを　のみました',
      reading: '코-히-오 노미마시타',
      category: 'Day 9 · 음식',
      chunks: ['コーヒーを', 'のみました'],
      translation: '커피를 마셨습니다',
    ),
    PracticeSentence(
      id: 'd09_3',
      text: 'おいしかったです',
      reading: '오이시캇타데스',
      category: 'Day 9 · 음식',
      chunks: ['おいしかったです'],
      translation: '맛있었습니다',
    ),
    // ─ Day 10 · 행동 ─
    PracticeSentence(
      id: 'd10_1',
      text: 'べんきょうを　しました',
      reading: '벤쿄우오 시마시타',
      category: 'Day 10 · 행동',
      chunks: ['べんきょうを', 'しました'],
      translation: '공부를 했습니다',
    ),
    PracticeSentence(
      id: 'd10_2',
      text: 'しごとを　しました',
      reading: '시고토오 시마시타',
      category: 'Day 10 · 행동',
      chunks: ['しごとを', 'しました'],
      translation: '일을 했습니다',
    ),
    PracticeSentence(
      id: 'd10_3',
      text: 'たのしかったです',
      reading: '타노시캇타데스',
      category: 'Day 10 · 행동',
      chunks: ['たのしかったです'],
      translation: '즐거웠습니다',
    ),
    // ─ Day 11 · 수면과 귀가 ─
    PracticeSentence(
      id: 'd11_1',
      text: 'はやく　かえりました',
      reading: '하야쿠 카에리마시타',
      category: 'Day 11 · 수면과 귀가',
      chunks: ['はやく', 'かえりました'],
      translation: '일찍 돌아갔습니다',
    ),
    PracticeSentence(
      id: 'd11_2',
      text: 'よく　ねました',
      reading: '요쿠 네마시타',
      category: 'Day 11 · 수면과 귀가',
      chunks: ['よく', 'ねました'],
      translation: '잘 잤습니다',
    ),
    PracticeSentence(
      id: 'd11_3',
      text: 'つかれました',
      reading: '츠카레마시타',
      category: 'Day 11 · 수면과 귀가',
      chunks: ['つかれました'],
      translation: '피곤했습니다',
    ),
    // ─ Day 12 · 함께 하자 ─
    PracticeSentence(
      id: 'd12_1',
      text: 'いっしょに　いきましょう',
      reading: '잇쇼니 이키마쇼우',
      category: 'Day 12 · 함께 하자',
      chunks: ['いっしょに', 'いきましょう'],
      translation: '함께 갑시다',
    ),
    PracticeSentence(
      id: 'd12_2',
      text: 'たべましょう',
      reading: '타베마쇼우',
      category: 'Day 12 · 함께 하자',
      chunks: ['たべましょう'],
      translation: '먹읍시다',
    ),
    PracticeSentence(
      id: 'd12_3',
      text: 'はじめましょう',
      reading: '하지메마쇼우',
      category: 'Day 12 · 함께 하자',
      chunks: ['はじめましょう'],
      translation: '시작합시다',
    ),
    PracticeSentence(
      id: 'd12_4',
      text: 'やすみましょう',
      reading: '야스미마쇼우',
      category: 'Day 12 · 함께 하자',
      chunks: ['やすみましょう'],
      translation: '쉽시다',
    ),
    // ─ Day 13 · ~하고 싶다 ─
    PracticeSentence(
      id: 'd13_1',
      text: 'にほんに　いきたいです',
      reading: '니혼니 이키타이데스',
      category: 'Day 13 · ~하고 싶다',
      chunks: ['にほんに', 'いきたいです'],
      translation: '일본에 가고 싶습니다',
    ),
    PracticeSentence(
      id: 'd13_2',
      text: 'すしを　たべたいです',
      reading: '스시오 타베타이데스',
      category: 'Day 13 · ~하고 싶다',
      chunks: ['すしを', 'たべたいです'],
      translation: '스시를 먹고 싶습니다',
    ),
    PracticeSentence(
      id: 'd13_3',
      text: 'にほんごを　はなしたいです',
      reading: '니혼고오 하나시타이데스',
      category: 'Day 13 · ~하고 싶다',
      chunks: ['にほんごを', 'はなしたいです'],
      translation: '일본어를 말하고 싶습니다',
    ),
    // ─ Day 14 · 종합 ─
    PracticeSentence(
      id: 'd14_1',
      text: 'きのう　すしを　たべました',
      reading: '키노우 스시오 타베마시타',
      category: 'Day 14 · 종합',
      chunks: ['きのう', 'すしを', 'たべました'],
      translation: '어제 스시를 먹었습니다',
    ),
    PracticeSentence(
      id: 'd14_2',
      text: 'いっしょに　いきましょう',
      reading: '잇쇼니 이키마쇼우',
      category: 'Day 14 · 종합',
      chunks: ['いっしょに', 'いきましょう'],
      translation: '함께 갑시다',
    ),
    PracticeSentence(
      id: 'd14_3',
      text: 'にほんに　いきたいです',
      reading: '니혼니 이키타이데스',
      category: 'Day 14 · 종합',
      chunks: ['にほんに', 'いきたいです'],
      translation: '일본에 가고 싶습니다',
    ),
    PracticeSentence(
      id: 'd14_4',
      text: 'たのしかったですね',
      reading: '타노시캇타데스네',
      category: 'Day 14 · 종합',
      chunks: ['たのしかったですね'],
      translation: '즐거웠죠?',
    ),
    // ─ Day 15 · ~해 주세요 ─
    PracticeSentence(
      id: 'd15_1',
      text: 'みて　ください',
      reading: '미테 쿠다사이',
      category: 'Day 15 · ~해 주세요',
      chunks: ['みて', 'ください'],
      translation: '봐 주세요',
    ),
    PracticeSentence(
      id: 'd15_2',
      text: 'きいて　ください',
      reading: '키이테 쿠다사이',
      category: 'Day 15 · ~해 주세요',
      chunks: ['きいて', 'ください'],
      translation: '들어 주세요',
    ),
    PracticeSentence(
      id: 'd15_3',
      text: 'まって　ください',
      reading: '맛테 쿠다사이',
      category: 'Day 15 · ~해 주세요',
      chunks: ['まって', 'ください'],
      translation: '기다려 주세요',
    ),
    // ─ Day 16 · 음식과 행동 ─
    PracticeSentence(
      id: 'd16_1',
      text: 'たべて　ください',
      reading: '타베테 쿠다사이',
      category: 'Day 16 · 음식과 행동',
      chunks: ['たべて', 'ください'],
      translation: '드세요',
    ),
    PracticeSentence(
      id: 'd16_2',
      text: 'のんで　ください',
      reading: '논데 쿠다사이',
      category: 'Day 16 · 음식과 행동',
      chunks: ['のんで', 'ください'],
      translation: '드세요 (음료)',
    ),
    PracticeSentence(
      id: 'd16_3',
      text: 'はなして　ください',
      reading: '하나시테 쿠다사이',
      category: 'Day 16 · 음식과 행동',
      chunks: ['はなして', 'ください'],
      translation: '말씀해 주세요',
    ),
    // ─ Day 17 · 행동 요청 ─
    PracticeSentence(
      id: 'd17_1',
      text: 'して　ください',
      reading: '시테 쿠다사이',
      category: 'Day 17 · 행동 요청',
      chunks: ['して', 'ください'],
      translation: '해 주세요',
    ),
    PracticeSentence(
      id: 'd17_2',
      text: 'かいて　ください',
      reading: '카이테 쿠다사이',
      category: 'Day 17 · 행동 요청',
      chunks: ['かいて', 'ください'],
      translation: '써 주세요',
    ),
    PracticeSentence(
      id: 'd17_3',
      text: 'おしえて　ください',
      reading: '오시에테 쿠다사이',
      category: 'Day 17 · 행동 요청',
      chunks: ['おしえて', 'ください'],
      translation: '가르쳐 주세요',
    ),
    // ─ Day 18 · ~하고 ─
    PracticeSentence(
      id: 'd18_1',
      text: 'たべて、のみます',
      reading: '타베테、노미마스',
      category: 'Day 18 · ~하고',
      chunks: ['たべて、のみます'],
      translation: '먹고, 마십니다',
    ),
    PracticeSentence(
      id: 'd18_2',
      text: 'いって、かえります',
      reading: '잇테、카에리마스',
      category: 'Day 18 · ~하고',
      chunks: ['いって、かえります'],
      translation: '가고, 돌아옵니다',
    ),
    PracticeSentence(
      id: 'd18_3',
      text: 'みて、はなします',
      reading: '미테、하나시마스',
      category: 'Day 18 · ~하고',
      chunks: ['みて、はなします'],
      translation: '보고, 이야기합니다',
    ),
    // ─ Day 19 · 허가 표현 ─
    PracticeSentence(
      id: 'd19_1',
      text: 'たべても　いいですか',
      reading: '타베테모 이이데스카',
      category: 'Day 19 · 허가 표현',
      chunks: ['たべても', 'いいですか'],
      translation: '먹어도 됩니까?',
    ),
    PracticeSentence(
      id: 'd19_2',
      text: 'いっても　いいですか',
      reading: '잇테모 이이데스카',
      category: 'Day 19 · 허가 표현',
      chunks: ['いっても', 'いいですか'],
      translation: '가도 됩니까?',
    ),
    PracticeSentence(
      id: 'd19_3',
      text: 'みても　いいですか',
      reading: '미테모 이이데스카',
      category: 'Day 19 · 허가 표현',
      chunks: ['みても', 'いいですか'],
      translation: '봐도 됩니까?',
    ),
    // ─ Day 20 · 금지 표현 ─
    PracticeSentence(
      id: 'd20_1',
      text: 'たべては　いけません',
      reading: '타베테와 이케마센',
      category: 'Day 20 · 금지 표현',
      chunks: ['たべては', 'いけません'],
      translation: '먹으면 안 됩니다',
    ),
    PracticeSentence(
      id: 'd20_2',
      text: 'ここに　はいっては　いけません',
      reading: '코코니 하잇테와 이케마센',
      category: 'Day 20 · 금지 표현',
      chunks: ['ここに', 'はいっては', 'いけません'],
      translation: '여기에 들어가면 안 됩니다',
    ),
    PracticeSentence(
      id: 'd20_3',
      text: 'はなしては　いけません',
      reading: '하나시테와 이케마센',
      category: 'Day 20 · 금지 표현',
      chunks: ['はなしては', 'いけません'],
      translation: '이야기하면 안 됩니다',
    ),
    // ─ Day 21 · テ형 종합 ─
    PracticeSentence(
      id: 'd21_1',
      text: 'みて　ください、おいしいです',
      reading: '미테 쿠다사이、오이시이데스',
      category: 'Day 21 · テ형 종합',
      chunks: ['みて', 'ください、おいしいです'],
      translation: '봐 주세요, 맛있습니다',
    ),
    PracticeSentence(
      id: 'd21_2',
      text: 'たべても　いいですか',
      reading: '타베테모 이이데스카',
      category: 'Day 21 · テ형 종합',
      chunks: ['たべても', 'いいですか'],
      translation: '먹어도 됩니까?',
    ),
    PracticeSentence(
      id: 'd21_3',
      text: 'まって　ください、いきます',
      reading: '맛테 쿠다사이、이키마스',
      category: 'Day 21 · テ형 종합',
      chunks: ['まって', 'ください、いきます'],
      translation: '기다려 주세요, 갑니다',
    ),
    // ─ Day 22 · 기본형(사전형) 첫 등장 ─
    PracticeSentence(
      id: 'd22_1',
      text: 'いく、いきます',
      reading: '이쿠 → 이키마스',
      category: 'Day 22 · 기본형(사전형) 첫 등장',
      chunks: ['いく、いきます'],
      translation: '가다 → 갑니다 (사전형 → 마스형)',
    ),
    PracticeSentence(
      id: 'd22_2',
      text: 'たべる、たべます',
      reading: '타베루 → 타베마스',
      category: 'Day 22 · 기본형(사전형) 첫 등장',
      chunks: ['たべる、たべます'],
      translation: '먹다 → 먹습니다',
    ),
    PracticeSentence(
      id: 'd22_3',
      text: 'する、します',
      reading: '스루 → 시마스',
      category: 'Day 22 · 기본형(사전형) 첫 등장',
      chunks: ['する、します'],
      translation: '하다 → 합니다',
    ),
    // ─ Day 23 · ~할 수 있다 ─
    PracticeSentence(
      id: 'd23_1',
      text: 'にほんごを　はなす　ことが　できます',
      reading: '니혼고오 하나스 코토가 데키마스',
      category: 'Day 23 · ~할 수 있다',
      chunks: ['にほんごを', 'はなす', 'ことが', 'できます'],
      translation: '일본어를 말할 수 있습니다',
    ),
    PracticeSentence(
      id: 'd23_2',
      text: 'すしを　たべる　ことが　できます',
      reading: '스시오 타베루 코토가 데키마스',
      category: 'Day 23 · ~할 수 있다',
      chunks: ['すしを', 'たべる', 'ことが', 'できます'],
      translation: '스시를 먹을 수 있습니다',
    ),
    PracticeSentence(
      id: 'd23_3',
      text: 'およぐ　ことが　できます',
      reading: '오요구 코토가 데키마스',
      category: 'Day 23 · ~할 수 있다',
      chunks: ['およぐ', 'ことが', 'できます'],
      translation: '수영할 수 있습니다',
    ),
    // ─ Day 24 · 전후 표현 ─
    PracticeSentence(
      id: 'd24_1',
      text: 'たべる　まえに　てを　あらいます',
      reading: '타베루 마에니 테오 아라이마스',
      category: 'Day 24 · 전후 표현',
      chunks: ['たべる', 'まえに', 'てを', 'あらいます'],
      translation: '먹기 전에 손을 씻습니다',
    ),
    PracticeSentence(
      id: 'd24_2',
      text: 'いった　あとで　かえります',
      reading: '잇타 아토데 카에리마스',
      category: 'Day 24 · 전후 표현',
      chunks: ['いった', 'あとで', 'かえります'],
      translation: '간 다음에 돌아옵니다',
    ),
    PracticeSentence(
      id: 'd24_3',
      text: 'べんきょうする　まえに　ねます',
      reading: '벤쿄우스루 마에니 네마스',
      category: 'Day 24 · 전후 표현',
      chunks: ['べんきょうする', 'まえに', 'ねます'],
      translation: '공부하기 전에 잡니다',
    ),
    // ─ Day 25 · 생각과 의도 ─
    PracticeSentence(
      id: 'd25_1',
      text: 'にほんに　いくと　おもいます',
      reading: '니혼니 이쿠토 오모이마스',
      category: 'Day 25 · 생각과 의도',
      chunks: ['にほんに', 'いくと', 'おもいます'],
      translation: '일본에 갈 것 같습니다',
    ),
    PracticeSentence(
      id: 'd25_2',
      text: 'たべたいと　おもいます',
      reading: '타베타이토 오모이마스',
      category: 'Day 25 · 생각과 의도',
      chunks: ['たべたいと', 'おもいます'],
      translation: '먹고 싶다고 생각합니다',
    ),
    PracticeSentence(
      id: 'd25_3',
      text: 'むずかしいと　おもいます',
      reading: '무즈카시이토 오모이마스',
      category: 'Day 25 · 생각과 의도',
      chunks: ['むずかしいと', 'おもいます'],
      translation: '어렵다고 생각합니다',
    ),
    // ─ Day 26 · 친구 대화 ─
    PracticeSentence(
      id: 'd26_1',
      text: 'どこに　いくの？',
      reading: '도코니 이쿠노?',
      category: 'Day 26 · 친구 대화',
      chunks: ['どこに', 'いくの？'],
      translation: '어디 가?',
    ),
    PracticeSentence(
      id: 'd26_2',
      text: 'たべようよ！',
      reading: '타베요우요!',
      category: 'Day 26 · 친구 대화',
      chunks: ['たべようよ！'],
      translation: '먹자!',
    ),
    PracticeSentence(
      id: 'd26_3',
      text: 'いいね！',
      reading: '이이네!',
      category: 'Day 26 · 친구 대화',
      chunks: ['いいね！'],
      translation: '좋아!',
    ),
    // ─ Day 27 · だ형 확장 ─
    PracticeSentence(
      id: 'd27_1',
      text: 'それは　なんだ？',
      reading: '소레와 난다?',
      category: 'Day 27 · だ형 확장',
      chunks: ['それは', 'なんだ？'],
      translation: '그게 뭐야?',
    ),
    PracticeSentence(
      id: 'd27_2',
      text: 'どこに　いたの？',
      reading: '도코니 이타노?',
      category: 'Day 27 · だ형 확장',
      chunks: ['どこに', 'いたの？'],
      translation: '어디 있었어?',
    ),
    PracticeSentence(
      id: 'd27_3',
      text: 'わかった！',
      reading: '와캇타!',
      category: 'Day 27 · だ형 확장',
      chunks: ['わかった！'],
      translation: '알았어!',
    ),
    // ─ Day 28 · 친구와의 일상 회화 ─
    PracticeSentence(
      id: 'd28_1',
      text: 'いっしょに　たべようよ',
      reading: '잇쇼니 타베요우요',
      category: 'Day 28 · 친구와의 일상 회화',
      chunks: ['いっしょに', 'たべようよ'],
      translation: '같이 먹자',
    ),
    PracticeSentence(
      id: 'd28_2',
      text: 'もう　かえるの？',
      reading: '모우 카에루노?',
      category: 'Day 28 · 친구와의 일상 회화',
      chunks: ['もう', 'かえるの？'],
      translation: '벌써 가?',
    ),
    PracticeSentence(
      id: 'd28_3',
      text: 'また　あそぼう！',
      reading: '마타 아소보우!',
      category: 'Day 28 · 친구와의 일상 회화',
      chunks: ['また', 'あそぼう！'],
      translation: '또 놀자!',
    ),
    // ─ Day 29 · 일상 시나리오 ─
    PracticeSentence(
      id: 'd29_1',
      text: 'きのう　どこに　いったの？',
      reading: '키노우 도코니 잇타노?',
      category: 'Day 29 · 일상 시나리오',
      chunks: ['きのう', 'どこに', 'いったの？'],
      translation: '어제 어디 갔어?',
    ),
    PracticeSentence(
      id: 'd29_2',
      text: 'レストランで　たべました',
      reading: '레스토란데 타베마시타',
      category: 'Day 29 · 일상 시나리오',
      chunks: ['レストランで', 'たべました'],
      translation: '레스토랑에서 먹었습니다',
    ),
    PracticeSentence(
      id: 'd29_3',
      text: 'また　いっしょに　いきましょう',
      reading: '마타 잇쇼니 이키마쇼우',
      category: 'Day 29 · 일상 시나리오',
      chunks: ['また', 'いっしょに', 'いきましょう'],
      translation: '또 같이 갑시다',
    ),
    // ─ Day 30 · 30일 종합 완성 ─
    PracticeSentence(
      id: 'd30_1',
      text: 'にほんごが　はなせるように　なりました',
      reading: '니혼고가 하나세루요우니 나리마시타',
      category: 'Day 30 · 30일 종합 완성',
      chunks: ['にほんごが', 'はなせるように', 'なりました'],
      translation: '일본어를 말할 수 있게 되었습니다',
    ),
    PracticeSentence(
      id: 'd30_2',
      text: 'まいにち　べんきょうしました',
      reading: '마이니치 벤쿄우시마시타',
      category: 'Day 30 · 30일 종합 완성',
      chunks: ['まいにち', 'べんきょうしました'],
      translation: '매일 공부했습니다',
    ),
    PracticeSentence(
      id: 'd30_3',
      text: 'ありがとうございました！',
      reading: '아리가토우 고자이마시타!',
      category: 'Day 30 · 30일 종합 완성',
      chunks: ['ありがとうございました！'],
      translation: '감사했습니다!',
    ),
    PracticeSentence(
      id: 'd30_4',
      text: 'これからも　がんばります！',
      reading: '코레카라모 감바리마스!',
      category: 'Day 30 · 30일 종합 완성',
      chunks: ['これからも', 'がんばります！'],
      translation: '앞으로도 열심히 하겠습니다!',
    ),
  ];

  /// 저장된 문장을 불러온다. 없으면 시드를 저장 후 반환.
  static Future<List<PracticeSentence>> loadSentences() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.isEmpty) {
      await saveSentences(_defaults);
      return List.of(_defaults);
    }
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return [
        for (var i = 0; i < list.length; i++)
          PracticeSentence.fromJson(
              list[i] as Map<String, dynamic>, 'ja_imported_$i'),
      ];
    } catch (_) {
      return List.of(_defaults);
    }
  }

  static Future<void> saveSentences(List<PracticeSentence> sentences) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _key, jsonEncode(sentences.map((s) => s.toJson()).toList()));
  }

  static Future<List<PracticeSentence>> addSentence(
      PracticeSentence sentence) async {
    final sentences = await loadSentences()
      ..add(sentence);
    await saveSentences(sentences);
    return sentences;
  }

  static Future<List<PracticeSentence>> deleteSentence(String id) async {
    final sentences = await loadSentences()
      ..removeWhere((s) => s.id == id);
    await saveSentences(sentences);
    return sentences;
  }

  static Future<List<PracticeSentence>> resetToDefaults() async {
    await saveSentences(_defaults);
    return List.of(_defaults);
  }

  /// JSON 배열 문자열을 가져와 DB를 교체한다.
  /// 형식: [{"id","text","reading","category","chunks":[...],"translation"}, ...]
  static Future<List<PracticeSentence>> importFromJson(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! List) {
      throw const FormatException('JSON 최상위는 배열이어야 합니다.');
    }
    final sentences = [
      for (var i = 0; i < decoded.length; i++)
        PracticeSentence.fromJson(
            decoded[i] as Map<String, dynamic>, 'ja_imported_$i'),
    ];
    if (sentences.isEmpty) {
      throw const FormatException('가져올 문장이 없습니다.');
    }
    await saveSentences(sentences);
    return sentences;
  }

  static String exportToJson(List<PracticeSentence> sentences) {
    return const JsonEncoder.withIndent('  ')
        .convert(sentences.map((s) => s.toJson()).toList());
  }
}
