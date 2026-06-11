import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:my_japanese_app/screens/home_screen.dart';
import 'package:my_japanese_app/services/translation_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('홈 화면이 브랜드명과 시작 버튼을 렌더링한다', (tester) async {
    TranslationService.isKorean = true;
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();

    expect(find.text(TranslationService.get('app_title')), findsOneWidget);
    expect(find.text(TranslationService.get('home_start')), findsOneWidget);
    expect(find.text(TranslationService.get('home_tagline')), findsOneWidget);
  });

  testWidgets('2단계(문장/문절) 안내가 표시된다', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: HomeScreen()));
    await tester.pumpAndSettle();
    expect(find.text('문장'), findsOneWidget);
    expect(find.text('문절'), findsOneWidget);
  });
}
