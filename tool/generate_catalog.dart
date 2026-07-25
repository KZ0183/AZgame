/// `data/*.json` から `lib/src/data/catalog.g.dart` を生成する。
///
/// カードとワードの設計上の情報源は一貫して `data/*.json` 側に置き、
/// Dart 側はそこから機械的に生成する。バランス調整は JSON を編集して
/// 本スクリプトを再実行すればよい。
///
///     dart run tool/generate_catalog.dart
///
/// なお効果の「挙動」は JSON から生成できないため、
/// `lib/src/engine/effects.dart` に手で実装する。JSON 側の定義と実装の
/// 対応漏れは `test/catalog_test.dart` が検出する。
library;

import 'dart:convert';
import 'dart:io';

const _classByLetter = <String, String>{
  'vowel': 'LetterClass.vowel',
  'core': 'LetterClass.core',
  'heavy': 'LetterClass.heavy',
  'rare': 'LetterClass.rare',
};

const _triggerByName = <String, String>{
  'onPlace': 'AbilityTrigger.onPlace',
  'passive': 'AbilityTrigger.passive',
  'onWord': 'AbilityTrigger.onWord',
};

void main() {
  final cardsJson =
      jsonDecode(File('data/cards.json').readAsStringSync()) as Map<String, dynamic>;
  final wordsJson =
      jsonDecode(File('data/words.json').readAsStringSync()) as Map<String, dynamic>;

  final cards = (cardsJson['cards'] as List).cast<Map<String, dynamic>>();
  final words = (wordsJson['words'] as List).cast<Map<String, dynamic>>();

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
    final klass = _classByLetter[card['class']];
    final trigger = _triggerByName[card['abilityTrigger']];
    if (klass == null) {
      throw StateError('未知の class: ${card['class']} ($letter)');
    }
    if (trigger == null) {
      throw StateError('未知の abilityTrigger: ${card['abilityTrigger']} ($letter)');
    }
    buffer
      ..writeln("  '$letter': LetterCard(")
      ..writeln("    letter: '$letter',")
      ..writeln('    rank: ${card['rank']},')
      ..writeln('    cost: ${card['cost']},')
      ..writeln('    power: ${card['power']},')
      ..writeln('    klass: $klass,')
      ..writeln('    deckLimit: ${card['deckLimit']},')
      ..writeln("    abilityName: ${_dartString(card['abilityName'] as String)},")
      ..writeln('    trigger: $trigger,')
      ..writeln("    abilityText: ${_dartString(card['abilityText'] as String)},")
      ..writeln('  ),');
  }

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// 全コンボワードのマスターデータ。キーは大文字の語。')
    ..writeln('const Map<String, ComboWord> wordCatalog = {');

  final seen = <String>{};
  for (final word in words) {
    final text = word['word'] as String;
    if (!seen.add(text)) {
      throw StateError('ワードが重複しています: $text');
    }
    if (text != text.toUpperCase() || !RegExp(r'^[A-Z]{2,5}$').hasMatch(text)) {
      throw StateError('ワードは大文字 2〜5 文字でなければなりません: $text');
    }
    if (text.length != word['length']) {
      throw StateError('length が語長と一致しません: $text');
    }
    buffer
      ..writeln("  '$text': ComboWord(")
      ..writeln("    word: '$text',")
      ..writeln('    damage: ${word['damage']},')
      ..writeln("    effectText: ${_dartString(word['effect'] as String)},")
      ..writeln('  ),');
  }

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// 登録されているワードの最大長。ワード探索の打ち切りに使う。')
    ..writeln('const int maxWordLength = '
        '${words.map((w) => (w['word'] as String).length).reduce((a, b) => a > b ? a : b)};');

  final output = File('lib/src/data/catalog.g.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('生成しました: ${output.path} '
      '(カード ${cards.length} 種 / ワード ${words.length} 語)');
}

/// Dart のシングルクォート文字列リテラルとしてエスケープする。
String _dartString(String value) {
  final escaped = value
      .replaceAll(r'\', r'\\')
      .replaceAll("'", r"\'")
      .replaceAll(r'$', r'\$')
      .replaceAll('\n', r'\n');
  return "'$escaped'";
}
