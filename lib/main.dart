/// AZgame のエントリポイント。
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/ui/home_screen.dart';
import 'src/ui/theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // 片手・縦持ちでの操作を前提にした盤面設計のため、縦向きに固定する。
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  runApp(const AzGameApp());
}

class AzGameApp extends StatelessWidget {
  const AzGameApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'かな戦記',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: const HomeScreen(),
    );
  }
}
