/// `data/*.json` から `lib/src/data/catalog.g.dart` を生成する。
///
/// 設計上の情報源は一貫して `data/*.json` 側に置き、Dart 側はそこから
/// 機械的に生成する。バランス調整は JSON を編集して本スクリプトを再実行する。
///
///     dart run tool/generate_catalog.dart
///
/// ワード陣形の効果は型付きの数値なので、表示用の文言もここで組み立てる。
/// data 側に文言を持たせないことで、効果と説明がずれる余地をなくしている。
library;

import 'dart:convert';
import 'dart:io';

const _classes = <String, String>{
  'vowel': 'LetterClass.vowel',
  'core': 'LetterClass.core',
  'heavy': 'LetterClass.heavy',
  'rare': 'LetterClass.rare',
};

const _triggers = <String, String>{
  'static': 'AbilityTrigger.static',
  'upkeep': 'AbilityTrigger.upkeep',
  'onPlay': 'AbilityTrigger.onPlay',
};

/// 効果の型と、表示文言の組み立て方。出力順がそのまま文言の並び順になる。
final List<(String, String Function(Object))> _effectText = [
  ('powerBonus', (v) => '自分の全文字のパワー+$v'),
  ('toughnessBonus', (v) => '自分の全文字のタフネス+$v'),
  ('pierce', (_) => '自分の全文字の戦闘ダメージは対峙する文字を無視して相手 LP に入る'),
  ('freeze', (v) => '相手の文字 $v 体は攻撃できない'),
  ('upkeepDamage', (v) => '毎ターン、相手に $v ダメージ'),
  ('upkeepHeal', (v) => '毎ターン、LP を $v 回復'),
  ('upkeepShield', (v) => '毎ターン、シールドを $v 得る'),
  ('upkeepEnergy', (v) => '毎ターン、エナジーを $v 得る'),
  ('upkeepDraw', (v) => '毎ターン、$v 枚ドロー'),
];

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
    final klass = _classes[card['class']];
    final trigger = _triggers[card['abilityTrigger']];
    if (klass == null) throw StateError('未知の class: ${card['class']} ($letter)');
    if (trigger == null) {
      throw StateError('未知の abilityTrigger: ${card['abilityTrigger']} ($letter)');
    }
    buffer
      ..writeln("  '$letter': LetterCard(")
      ..writeln("    letter: '$letter',")
      ..writeln('    rank: ${card['rank']},')
      ..writeln('    cost: ${card['cost']},')
      ..writeln('    power: ${card['power']},')
      ..writeln('    toughness: ${card['toughness']},')
      ..writeln('    klass: $klass,')
      ..writeln('    deckLimit: ${card['deckLimit']},')
      ..writeln('    energyProduced: ${card['energyProduced']},')
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
  for (final entry in words) {
    final word = entry['word'] as String;
    if (!seen.add(word)) throw StateError('ワードが重複しています: $word');
    if (!RegExp(r'^[A-Z]{2,5}$').hasMatch(word)) {
      throw StateError('ワードは大文字 2〜5 文字でなければなりません: $word');
    }
    if (word.length != entry['length']) {
      throw StateError('length が語長と一致しません: $word');
    }

    final effect = (entry['effect'] as Map).cast<String, dynamic>();
    final known = _effectText.map((e) => e.$1).toSet();
    for (final key in effect.keys) {
      if (!known.contains(key)) throw StateError('未知の効果型: $key ($word)');
    }
    if (effect.isEmpty) throw StateError('効果が空です: $word');

    buffer
      ..writeln("  '$word': ComboWord(")
      ..writeln("    word: '$word',")
      ..writeln('    effect: ${_dartEffect(effect)},')
      ..writeln('    text: ${_dartString(_describe(effect))},')
      ..writeln('  ),');
  }

  final maxLength =
      words.map((w) => (w['word'] as String).length).reduce((a, b) => a > b ? a : b);

  buffer
    ..writeln('};')
    ..writeln()
    ..writeln('/// 登録されているワードの最大長。陣形探索の打ち切りに使う。')
    ..writeln('const int maxWordLength = $maxLength;');

  final output = File('lib/src/data/catalog.g.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('生成しました: ${output.path} '
      '(カード ${cards.length} 種 / ワード ${words.length} 語)');
}

String _dartEffect(Map<String, dynamic> effect) {
  final args = <String>[];
  for (final (key, _) in _effectText) {
    final value = effect[key];
    if (value == null) continue;
    args.add('$key: $value');
  }
  return 'WordEffect(${args.join(', ')})';
}

String _describe(Map<String, dynamic> effect) {
  final parts = <String>[];
  for (final (key, describe) in _effectText) {
    final value = effect[key];
    if (value == null) continue;
    if (value is bool && !value) continue;
    parts.add(describe(value));
  }
  return '${parts.join('。')}。';
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
