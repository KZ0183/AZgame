/// `data/cards.json` から `lib/src/data/catalog.g.dart` を生成する。
///
///     dart run tool/generate_catalog.dart
///
/// カードはすべてバニラなので、生成物は 26 枚のステータス表だけになる。
library;

import 'dart:convert';
import 'dart:io';

void main() {
  final cardsJson =
      jsonDecode(File('data/cards.json').readAsStringSync()) as Map<String, dynamic>;
  final cards = (cardsJson['cards'] as List).cast<Map<String, dynamic>>();

  if (cards.length != 26) {
    throw StateError('カードは 26 種でなければなりません: ${cards.length} 種');
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — 直接編集しないこと。')
    ..writeln('//')
    ..writeln('// 生成元: data/cards.json (v${cardsJson['version']})')
    ..writeln('// 再生成: dart run tool/generate_catalog.dart')
    ..writeln('library;')
    ..writeln()
    ..writeln("import '../engine/models.dart';")
    ..writeln()
    ..writeln('/// 全 26 枚のマスターデータ。キーは大文字 1 文字。')
    ..writeln('const Map<String, LetterCard> cardCatalog = {');

  for (final card in cards) {
    final letter = card['letter'] as String;
    buffer
      ..writeln("  '$letter': LetterCard(")
      ..writeln("    letter: '$letter',")
      ..writeln('    rank: ${card['rank']},')
      ..writeln('    cost: ${card['cost']},')
      ..writeln('    power: ${card['power']},')
      ..writeln('    toughness: ${card['toughness']},')
      ..writeln('    deckLimit: ${card['deckLimit']},')
      ..writeln('  ),');
  }

  buffer.writeln('};');

  File('lib/src/data/catalog.g.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('生成しました (カード ${cards.length} 枚)');
}
