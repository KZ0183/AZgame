/// AI 同士の対戦を大量に回してバランスを実測する。
///
///     dart run tool/simulate.dart [試行回数]
library;

import 'dart:io';
import 'dart:math';

import 'package:azgame/src/data/catalog.g.dart';
import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/game.dart';

class Record {
  Record({
    required this.turns,
    required this.firstWon,
    required this.decided,
    required this.loserLife,
    required this.landScrewTurns,
  });

  final int turns;
  final bool firstWon;
  final bool decided;

  /// 敗者の残りライフ（0 以下なら削り切られた）。
  final int loserLife;

  /// 「土地が足りず、手札のクリーチャーを 1 枚も唱えられなかった」ターン数。
  final int landScrewTurns;
}

Record play(int seed) {
  final game = Game(
    first: PlayerState(name: '先攻', deck: starterDeck.toCardList()),
    second: PlayerState(name: '後攻', deck: starterDeck.toCardList()),
    firstBlocker: SimpleAi.chooseBlocks,
    secondBlocker: SimpleAi.chooseBlocks,
    rng: Random(seed),
  )..start();

  const ai = SimpleAi();
  var turns = 0;
  var screwed = 0;

  while (!game.isOver && turns < 200) {
    final before = game.active.creatures.length;
    final hadCreatureInHand =
        game.active.hand.any((letter) => cardCatalog[letter]!.isCreature);
    ai.takeTurn(game);
    if (hadCreatureInHand && game.active.creatures.length == before) screwed++;
    game.endTurn();
    turns++;
  }

  final loser = game.winner == game.first ? game.second : game.first;
  return Record(
    turns: turns,
    firstWon: game.winner == game.first,
    decided: game.isOver,
    loserLife: loser.life,
    landScrewTurns: screwed,
  );
}

void main(List<String> args) {
  final trials = args.isEmpty ? 500 : int.parse(args.first);
  final records = [for (var seed = 0; seed < trials; seed++) play(seed)];
  final decided = records.where((r) => r.decided).toList();
  final turns = decided.map((r) => r.turns).toList()..sort();

  stdout
    ..writeln('=== AZgame v0.5 バランス実測 ($trials 試合) ===')
    ..writeln()
    ..writeln('■ 試合')
    ..writeln('  決着率      : ${_pct(decided.length / records.length)}')
    ..writeln('  平均ターン  : ${_avg(turns).toStringAsFixed(1)}')
    ..writeln('  中央値      : ${turns[turns.length ~/ 2]}')
    ..writeln('  最短 / 最長 : ${turns.first} / ${turns.last}')
    ..writeln('  先攻勝率    : '
        '${_pct(decided.where((r) => r.firstWon).length / decided.length)}')
    ..writeln()
    ..writeln('■ ゲームの締まり方')
    ..writeln('  敗者の残ライフ平均: '
        '${_avg(decided.map((r) => r.loserLife)).toStringAsFixed(1)}')
    ..writeln('  クリーチャーを出せなかったターンの割合: '
        '${_pct(_avg(decided.map((r) => r.landScrewTurns)) / _avg(turns))}');
}

double _avg(Iterable<int> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
