import 'package:flutter/material.dart';

import 'app/router.dart';
import 'app/theme.dart';

void main() {
  runApp(const MaltuimApp());
}

/// 말트임 — 입으로 익히는 진짜 일본어.
class MaltuimApp extends StatelessWidget {
  const MaltuimApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '말트임 일본어',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      routerConfig: appRouter,
    );
  }
}
