/// 配色。
///
/// **色は行（種族）で決める。** 46 種に絵を用意する余力はないので、
/// 「か行は赤で突撃」「た行は黄で挑発」のように、
/// 色と文字の形そのものを識別子にする方針。
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

const Color kLifeColor = Color(0xFFE3576B);
const Color kEnergyColor = Color(0xFFF2C14E);
const Color kEnemyColor = Color(0xFFC0503F);
const Color kAccentColor = Color(0xFFB57BEE);

/// 行ごとの色。
const Map<String, Color> kRowColors = {
  'あ行': Color(0xFF4E8FCB), // 藍 — 素直
  'か行': Color(0xFFE0634B), // 緋 — 突撃
  'さ行': Color(0xFF3FA7A0), // 青竹 — 狙撃
  'た行': Color(0xFFC9A227), // 山吹 — 挑発
  'な行': Color(0xFF6FBF73), // 若葉 — 絆魂
  'は行': Color(0xFFB5548A), // 紅梅 — 貫通
  'ま行': Color(0xFF7A6FCE), // 藤 — 硬い
  'や行': Color(0xFFE08A3C), // 橙 — 高火力
  'ら行': Color(0xFF4FC3A1), // 翡翠 — ドロー
  'わ行': Color(0xFF9AA0B5), // 鈍色 — 回復
  'ん': Color(0xFFE3576B), // 朱 — 唯一の 6 コスト
};

Color rowColor(String row) => kRowColors[row] ?? kTextMuted;

Color cardColor(KanaCard card) => rowColor(card.row);

/// 行が何を得意とするか。図鑑と敵の紹介で使う。
const Map<String, String> kRowTraits = {
  'あ行': '素直。コストどおりのパワーとタフネス',
  'か行': '突撃。出したターンから殴れる代わりに脆い',
  'さ行': '狙撃。出たときに敵 1 体を焼く',
  'た行': '挑発。雑魚の攻撃を引き受ける壁',
  'な行': '絆魂。殴りながらライフを戻す',
  'は行': '貫通。壁を倒した余りが本体に入る',
  'ま行': '硬い。能力はないがとにかく落ちない',
  'や行': '高火力。パワーが 1 高く、タフネスが 1 低い',
  'ら行': 'ドロー。出たとき 1 枚引く',
  'わ行': '回復。出たときライフが戻る',
  'ん': '唯一の 6 コスト。7/7 貫通',
};

ThemeData buildTheme() {
  final base = ThemeData.dark(useMaterial3: true);
  return base.copyWith(
    scaffoldBackgroundColor: kBackground,
    colorScheme: base.colorScheme.copyWith(
      surface: kSurface,
      primary: kAccentColor,
    ),
    textTheme: base.textTheme.apply(
      bodyColor: kTextPrimary,
      displayColor: kTextPrimary,
    ),
  );
}
