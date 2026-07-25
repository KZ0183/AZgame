/// 配色とカードの見た目を決める定数群。
///
/// 文字カードはクラス（母音・基幹・重・希少）で色分けする。
/// 26 種すべてに個別の絵を用意するのは現実的でないため、
/// 色と文字そのものの造形で識別性を作る方針。
library;

import 'package:flutter/material.dart';

import '../engine/models.dart';

/// 盤面の背景。夜の対戦卓を想定した暗色。
const Color kBackground = Color(0xFF12141C);
const Color kSurface = Color(0xFF1C1F2B);
const Color kSurfaceHigh = Color(0xFF272B3A);
const Color kOutline = Color(0xFF3A3F52);
const Color kTextPrimary = Color(0xFFECEEF5);
const Color kTextMuted = Color(0xFF8D93A8);

/// ライフ・シールド・エナジーの識別色。
const Color kLifeColor = Color(0xFFE3576B);
const Color kShieldColor = Color(0xFF5BA9E8);
const Color kEnergyColor = Color(0xFFF2C14E);

/// ワード成立時の強調色。
const Color kWordColor = Color(0xFFB57BEE);

/// シークエンス成立時の強調色。
const Color kSequenceColor = Color(0xFF4FC3A1);

/// クラスごとのカード色。
Color classColor(LetterClass klass) => switch (klass) {
      LetterClass.vowel => const Color(0xFFE8A33D),
      LetterClass.core => const Color(0xFF3FA7A0),
      LetterClass.heavy => const Color(0xFF6C7BD6),
      LetterClass.rare => const Color(0xFFD4504F),
    };

/// クラスの日本語表示名。
String classLabel(LetterClass klass) => switch (klass) {
      LetterClass.vowel => '母音',
      LetterClass.core => '基幹',
      LetterClass.heavy => '重',
      LetterClass.rare => '希少',
    };

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBackground,
    colorScheme: base.colorScheme.copyWith(
      surface: kSurface,
      primary: kWordColor,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: kTextPrimary,
      displayColor: kTextPrimary,
    ),
  );
}
