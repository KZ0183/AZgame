/// `data/*.json` から `lib/src/data/*.g.dart` を生成する。
///
///     dart run tool/generate_catalog.dart
///
/// カードも敵も、正となるデータは JSON 側にある。Dart 側は触らない。
library;

import 'dart:convert';
import 'dart:io';

const int kCardCount = 46;

void main() {
  _generateCards();
  _generateEnemies();
}

void _generateCards() {
  final json = jsonDecode(File('data/cards.json').readAsStringSync())
      as Map<String, dynamic>;
  final cards = (json['cards'] as List).cast<Map<String, dynamic>>();

  if (cards.length != kCardCount) {
    throw StateError('カードは $kCardCount 種でなければなりません: ${cards.length} 種');
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — 直接編集しないこと。')
    ..writeln('//')
    ..writeln('// 生成元: data/cards.json (v${json['version']})')
    ..writeln('// 再生成: dart run tool/generate_catalog.dart')
    ..writeln('library;')
    ..writeln()
    ..writeln("import '../engine/models.dart';")
    ..writeln()
    ..writeln('/// 全 $kCardCount 枚のマスターデータ。キーは かな 1 文字。')
    ..writeln('const Map<String, KanaCard> cardCatalog = {');

  for (final card in cards) {
    final keywords = (card['keywords'] as List).cast<String>();
    buffer
      ..writeln("  '${card['kana']}': KanaCard(")
      ..writeln("    kana: '${card['kana']}',")
      ..writeln('    order: ${card['order']},')
      ..writeln("    row: '${card['row']}',")
      ..writeln('    cost: ${card['cost']},')
      ..writeln('    power: ${card['power']},')
      ..writeln('    toughness: ${card['toughness']},')
      ..writeln('    keywords: '
          '{${keywords.map((k) => 'Keyword.$k').join(', ')}},')
      ..writeln('    onPlay: OnPlay.${card['onPlay']},')
      ..writeln('    onPlayValue: ${card['onPlayValue']},')
      ..writeln('    deckLimit: ${card['deckLimit']},')
      ..writeln('  ),');
  }

  buffer.writeln('};');

  File('lib/src/data/catalog.g.dart')
    ..parent.createSync(recursive: true)
    ..writeAsStringSync(buffer.toString());

  stdout.writeln('カード ${cards.length} 枚を生成しました');
}

void _generateEnemies() {
  final json = jsonDecode(File('data/enemies.json').readAsStringSync())
      as Map<String, dynamic>;
  final enemies = (json['enemies'] as List).cast<Map<String, dynamic>>();

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE — 直接編集しないこと。')
    ..writeln('//')
    ..writeln('// 生成元: data/enemies.json (v${json['version']})')
    ..writeln('// 再生成: dart run tool/generate_catalog.dart')
    ..writeln('library;')
    ..writeln()
    ..writeln("import '../engine/enemy.dart';")
    ..writeln()
    ..writeln('/// 挑む順に並んだ敵。前から順に相手をする。')
    ..writeln('const List<EnemyDef> enemyRoster = [');

  for (final enemy in enemies) {
    buffer
      ..writeln('  EnemyDef(')
      ..writeln("    id: '${enemy['id']}',")
      ..writeln("    name: '${enemy['name']}',")
      ..writeln("    glyph: '${enemy['glyph']}',")
      ..writeln('    life: ${enemy['life']},')
      ..writeln("    flavor: '${enemy['flavor']}',")
      ..writeln("    lesson: '${enemy['lesson']}',")
      ..writeln('    pattern: [');
    for (final action in (enemy['pattern'] as List).cast<Map<String, dynamic>>()) {
      final summons = (action['summons'] as List?)?.cast<String>() ?? const [];
      buffer
        ..write('      EnemyAction(kind: EnemyActionKind.${action['kind']}')
        ..write(action['value'] != null ? ', value: ${action['value']}' : '')
        ..write(summons.isEmpty
            ? ''
            : ", summons: [${summons.map((s) => "'$s'").join(', ')}]")
        ..writeln('),');
    }
    buffer
      ..writeln('    ],')
      ..writeln('  ),');
  }

  buffer.writeln('];');

  File('lib/src/data/enemies.g.dart').writeAsStringSync(buffer.toString());

  stdout.writeln('敵 ${enemies.length} 体を生成しました');
}
