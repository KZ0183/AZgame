/// AI 同士の対戦を大量に回してバランスを実測する。
///
///     dart run tool/simulate.dart [試行回数]
library;

import 'dart:io';
import 'dart:math';

import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/game.dart';

class Record {
  Record({
    required this.turns,
    required this.firstWon,
    required this.decided,
    required this.idleTurns,
    required this.maxBoard,
  });

  final int turns;
  final bool firstWon;
  final bool decided;

  /// 手札にカードがあるのに 1 枚も出せなかったターン数。
  final int idleTurns;

  /// 片側の盤面が最大何体まで並んだか。
  final int maxBoard;
}

Record play(int seed) {
  final game = Game(
    first: PlayerState(name: '先攻', deck: starterDeck.toCardList()),
    second: PlayerState(name: '後攻', deck: starterDeck.toCardList()),
    rng: Random(seed),
  )..start();

  const ai = SimpleAi();
  var turns = 0;
  var idle = 0;
  var maxBoard = 0;

  while (!game.isOver && turns < 200) {
    final before = game.active.creatures.length;
    final hadCards = game.active.hand.isNotEmpty;
    ai.takeTurn(game);
    if (hadCards && game.active.creatures.length == before) idle++;
    maxBoard = max(maxBoard, game.active.creatures.length);
    game.endTurn();
    turns++;
  }

  return Record(
    turns: turns,
    firstWon: game.winner == game.first,
    decided: game.isOver,
    idleTurns: idle,
    maxBoard: maxBoard,
  );
}

void main(List<String> args) {
  final trials = args.isEmpty ? 500 : int.parse(args.first);
  final records = [for (var seed = 0; seed < trials; seed++) play(seed)];
  final decided = records.where((r) => r.decided).toList();
  final turns = decided.map((r) => r.turns).toList()..sort();

  stdout
    ..writeln('=== AZgame v0.6 バランス実測 ($trials 試合) ===')
    ..writeln()
    ..writeln('  決着率        : ${_pct(decided.length / records.length)}')
    ..writeln('  平均ターン    : ${_avg(turns).toStringAsFixed(1)}'
        '（両者合計の手番数）')
    ..writeln('  中央値        : ${turns[turns.length ~/ 2]}')
    ..writeln('  最短 / 最長   : ${turns.first} / ${turns.last}')
    ..writeln('  先攻勝率      : '
        '${_pct(decided.where((r) => r.firstWon).length / decided.length)}')
    ..writeln('  何も出せない手番: '
        '${_pct(_avg(decided.map((r) => r.idleTurns)) / _avg(turns))}')
    ..writeln('  盤面の最大体数: '
        '${_avg(decided.map((r) => r.maxBoard)).toStringAsFixed(1)}');
}

double _avg(Iterable<int> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
