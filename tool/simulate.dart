/// 自動プレイヤーに戦闘を何度も打たせ、バランスを実測する。
///
///     dart run tool/simulate.dart [試行回数]
///
/// 見たいのは「デッキ × 敵」の表。**どのデッキも一律に最強ではなく、
/// 敵ごとに最適が入れ替わる**ようになっていれば、組み替える意味が生まれる。
library;

import 'dart:io';
import 'dart:math';

import 'package:azgame/src/data/enemies.g.dart';
import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/battle.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/enemy.dart';

class Outcome {
  Outcome({required this.won, required this.turns, required this.lifeLeft});

  final bool won;
  final int turns;
  final int lifeLeft;
}

Outcome fight(DeckList deck, EnemyDef enemy, int seed) {
  final battle = Battle(
    enemy: enemy,
    deck: deck.toCardList(),
    rng: Random(seed),
  )..start();

  const player = AutoPlayer();
  var turns = 0;
  while (!battle.isOver && turns < 60) {
    player.takeTurn(battle);
    battle.endTurn();
    turns++;
  }
  return Outcome(
    won: battle.playerWon,
    turns: turns,
    lifeLeft: battle.playerLife,
  );
}

void main(List<String> args) {
  final trials = args.isEmpty ? 500 : int.parse(args.first);

  stdout
    ..writeln('=== AZgame v0.7 バランス実測（$trials 戦 / 組）===')
    ..writeln();

  // 勝率の表。行がデッキ、列が敵。
  stdout.writeln(
      '${''.padRight(6)}${enemyRoster.map((e) => e.name.padLeft(10)).join()}');
  final rates = <String, List<double>>{};
  final turnTable = <String, List<double>>{};

  for (final deck in presetDecks) {
    final row = <double>[];
    final turnRow = <double>[];
    for (final enemy in enemyRoster) {
      final outcomes = [
        for (var seed = 0; seed < trials; seed++) fight(deck, enemy, seed),
      ];
      row.add(outcomes.where((o) => o.won).length / trials);
      turnRow.add(_avg(outcomes.map((o) => o.turns)));
    }
    rates[deck.name] = row;
    turnTable[deck.name] = turnRow;
    stdout.writeln('${deck.name.padRight(6)}'
        '${row.map((r) => _pct(r).padLeft(10)).join()}');
  }

  stdout
    ..writeln()
    ..writeln('平均ターン数');
  for (final entry in turnTable.entries) {
    stdout.writeln('${entry.key.padRight(6)}'
        '${entry.value.map((t) => t.toStringAsFixed(1).padLeft(10)).join()}');
  }

  stdout
    ..writeln()
    ..writeln('敵ごとの最適デッキ（入れ替わっているほどよい）');
  for (var i = 0; i < enemyRoster.length; i++) {
    final best = rates.entries.reduce((a, b) => a.value[i] >= b.value[i] ? a : b);
    final worst = rates.entries.reduce((a, b) => a.value[i] <= b.value[i] ? a : b);
    stdout.writeln('  ${enemyRoster[i].name.padRight(6)}'
        ' 最適 ${best.key} (${_pct(best.value[i])})'
        ' / 最悪 ${worst.key} (${_pct(worst.value[i])})');
  }
}

double _avg(Iterable<int> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
