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

/// 先手（プレイヤー）と後手（相手）の駒の色。
const Color kFirstColor = Color(0xFF3E6DD6);
const Color kSecondColor = Color(0xFFC0503F);

/// ワード成立時の強調色。
const Color kWordColor = Color(0xFFB57BEE);

/// シークエンス成立時の強調色。
const Color kSequenceColor = Color(0xFF4FC3A1);

/// カードの色。土地は緑、クリーチャーはコストが重いほど赤に寄る。
Color cardColor(LetterCard card) {
  return switch (card.cost) {
    1 => const Color(0xFF3FA7A0),
    2 => const Color(0xFF4E8FCB),
    3 => const Color(0xFF6C7BD6),
    4 => const Color(0xFF8E6FCE),
    5 => const Color(0xFFB56AB0),
    6 => const Color(0xFFC85F7C),
    7 => const Color(0xFFD4504F),
    _ => const Color(0xFFE0634B),
  };
}

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
