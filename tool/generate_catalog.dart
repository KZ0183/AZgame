/// `data/*.json` から `lib/src/data/catalog.g.dart` を生成する。
///
///     dart run tool/generate_catalog.dart
///
/// v0.4 の文字は能力もコストも持たないため、生成物は文字の同一性
/// （順位とクラス）と、成立しうる単語の一覧だけになる。
library;

import 'dart:convert';
import 'dart:io';

const _classes = <String, String>{
  'vowel': 'LetterClass.vowel',
  'core': 'LetterClass.core',
  'heavy': 'LetterClass.heavy',
  'rare': 'LetterClass.rare',
};

void main() {
  final cardsJson =
      jsonDecode(File('data/cards.json').readAsStringSync()) as Map<String, dynamic>;
  final wordsJson =
      jsonDecode(File('data/words.json').readAsStringSync()) as Map<String, dynamic>;

  final cards = (cardsJson['cards'] as List).cast<Map<String, dynamic>>();
  final words = (wordsJson['words'] as List).cast<String>();

  if (cards.length != 26) {
    throw StateError('カードは 26 種でなければなりません: ${cards.length} 種');
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — 直接編集しないこと。')
    ..writeln('//')
    ..writeln('// 生成元: data/cards.json (v${cardsJson['version']}), '
        'data/words.json (v${wordsJson['version']})')
    ..writeln('// 再生成: dart run tool/generate_catalog.dart')
    ..writeln('library;')
    ..writeln()
    ..writeln("import '../engine/models.dart';")
    ..writeln()
    ..writeln('/// 全 26 文字のマスターデータ。キーは大文字 1 文字。')
    ..writeln('const Map<String, LetterCard> cardCatalog = {');

  for (final card in cards) {
    final letter = card['letter'] as String;
    final klass = _classes[card['class']];
    if (klass == null) throw StateError('未知の class: ${card['class']} ($letter)');
    buffer
      ..writeln("  '$letter': LetterCard(")
      ..writeln("    letter: '$letter',")
      ..writeln('    rank: ${card['rank']},')
      ..writeln('    klass: $klass,')
      ..writeln('  ),');
  }

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// 盤上で成立する単語の一覧。')
    ..writeln('const Set<String> wordSet = {');

  final seen = <String>{};
  for (final word in words) {
    if (!seen.add(word)) throw StateError('ワードが重複しています: $word');
    if (!RegExp(r'^[A-Z]{2,5}$').hasMatch(word)) {
      throw StateError('ワードは大文字 2〜5 文字でなければなりません: $word');
    }
    buffer.writeln("  '$word',");
  }

  final maxLength = words.map((w) => w.length).reduce((a, b) => a > b ? a : b);

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// 登録されている単語の最大長。探索の打ち切りに使う。')
    ..writeln('const int maxWordLength = $maxLength;');

  File('lib/src/data/catalog.g.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('生成しました (カード ${cards.length} 種 / ワード ${words.length} 語)');
}
