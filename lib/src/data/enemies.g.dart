// GENERATED FILE — 直接編集しないこと。
//
// 生成元: data/enemies.json (v0.7.0)
// 再生成: dart run tool/generate_catalog.dart
library;

import '../engine/enemy.dart';

/// 挑む順に並んだ敵。前から順に相手をする。
const List<EnemyDef> enemyRoster = [
  EnemyDef(
    id: 'kikori',
    name: '木こり人形',
    glyph: '🪓',
    life: 34,
    flavor: '森のはずれで斧を振り続ける人形。単調だが一撃が重い。',
    lesson: '本体の一撃が速い。壁を並べても止まらないので、間に合わせる速さが要る。',
    pattern: [
      EnemyAction(kind: EnemyActionKind.summon, summons: ['あ']),
      EnemyAction(kind: EnemyActionKind.strike, value: 8),
      EnemyAction(kind: EnemyActionKind.strike, value: 8),
      EnemyAction(kind: EnemyActionKind.summon, summons: ['い']),
      EnemyAction(kind: EnemyActionKind.strike, value: 11),
    ],
  ),
  EnemyDef(
    id: 'mukade',
    name: '百足の群',
    glyph: '🐛',
    life: 46,
    flavor: '一匹ずつは弱い。だが数えているうちに増えている。',
    lesson: '雑魚の総攻撃が本体。挑発で受けるほど楽になるが、薙ぎ払いと本体の一撃は素通りする。',
    pattern: [
      EnemyAction(kind: EnemyActionKind.summon, summons: ['あ', 'か', 'き']),
      EnemyAction(kind: EnemyActionKind.summon, summons: ['い', 'い']),
      EnemyAction(kind: EnemyActionKind.strike, value: 4),
      EnemyAction(kind: EnemyActionKind.sweep, value: 2),
      EnemyAction(kind: EnemyActionKind.summon, summons: ['う', 'か', 'か']),
      EnemyAction(kind: EnemyActionKind.strike, value: 5),
      EnemyAction(kind: EnemyActionKind.summon, summons: ['い', 'き', 'あ']),
      EnemyAction(kind: EnemyActionKind.strike, value: 7),
    ],
  ),
  EnemyDef(
    id: 'oni',
    name: '鬼',
    glyph: '👹',
    life: 52,
    flavor: '壁を立て、薙ぎ払い、力を溜めて振り下ろす。',
    lesson: '一撃が回るたびに重くなる。長引かせるほど不利になるので、どこかで決めに行く必要がある。',
    pattern: [
      EnemyAction(kind: EnemyActionKind.summon, summons: ['ち']),
      EnemyAction(kind: EnemyActionKind.strike, value: 7),
      EnemyAction(kind: EnemyActionKind.sweep, value: 3),
      EnemyAction(kind: EnemyActionKind.strike, value: 7),
      EnemyAction(kind: EnemyActionKind.empower, value: 5),
      EnemyAction(kind: EnemyActionKind.summon, summons: ['つ']),
      EnemyAction(kind: EnemyActionKind.sweep, value: 3),
      EnemyAction(kind: EnemyActionKind.strike, value: 7),
      EnemyAction(kind: EnemyActionKind.heal, value: 8),
    ],
  ),
];
