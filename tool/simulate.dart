/// AI 同士の対戦を大量に回してバランスを実測する。
///
///     dart run tool/simulate.dart [試行回数]
///
/// v0.4 は運の要素がないため、AI 同士は毎回同じ棋譜になる。そこで
/// 序盤の手をずらした局面から開始して、局面のばらつきを作って測る。
library;

import 'dart:io';
import 'dart:math';

import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/models.dart';

class Record {
  Record({
    required this.moves,
    required this.firstCount,
    required this.secondCount,
    required this.formations,
    required this.captures,
    required this.lengths,
  });

  final int moves;
  final int firstCount;
  final int secondCount;

  /// 成立した並びの総数。
  final int formations;

  /// 奪われた駒の総数。
  final int captures;

  /// 成立した並びの長さの内訳。
  final Map<int, int> lengths;

  int? get winnerSign => firstCount == secondCount
      ? null
      : (firstCount > secondCount ? 1 : -1);
}

Record playMatch(int seed) {
  final rng = Random(seed);
  final game = AzGame();
  const ai = SimpleAi();

  var formations = 0;
  var captures = 0;
  final lengths = <int, int>{};

  // 最初の数手だけランダムに散らし、そこから両者最善を尽くす。
  // これで「同じ初手からの分岐」を疑似的に作れる。
  var scattered = 0;
  while (!game.isOver) {
    MoveResult? result;
    if (scattered < 4) {
      final hand = game.distinctHandOf(game.turn);
      final cells = game.legalCells;
      result = game.play(
        hand[rng.nextInt(hand.length)],
        cells[rng.nextInt(cells.length)],
      );
      scattered++;
    } else {
      result = ai.playTurn(game);
    }
    if (result == null) break;

    formations += result.formations.length;
    captures += result.captured.length;
    for (final formation in result.formations) {
      final length = formation.cells.length;
      lengths[length] = (lengths[length] ?? 0) + 1;
    }
  }

  return Record(
    moves: game.moveCount,
    firstCount: game.board.countOf(Owner.first),
    secondCount: game.board.countOf(Owner.second),
    formations: formations,
    captures: captures,
    lengths: lengths,
  );
}

void main(List<String> args) {
  final trials = args.isEmpty ? 500 : int.parse(args.first);
  final records = [for (var seed = 0; seed < trials; seed++) playMatch(seed)];

  final firstWins = records.where((r) => r.winnerSign == 1).length;
  final draws = records.where((r) => r.winnerSign == null).length;
  final margins = records
      .map((r) => (r.firstCount - r.secondCount).abs())
      .toList()
    ..sort();

  stdout
    ..writeln('=== AZgame v0.4 バランス実測 ($trials 試合) ===')
    ..writeln()
    ..writeln('■ 決着')
    ..writeln('  先手勝率    : ${_pct(firstWins / trials)}')
    ..writeln('  引き分け    : ${_pct(draws / trials)}')
    ..writeln('  平均手数    : ${_avg(records.map((r) => r.moves)).toStringAsFixed(1)}')
    ..writeln('  勝敗の差    : 平均 ${_avg(margins).toStringAsFixed(1)} 枚 / '
        '中央値 ${margins[margins.length ~/ 2]} 枚')
    ..writeln()
    ..writeln('■ 単語は機能しているか')
    ..writeln('  1 試合の成立数: '
        '${_avg(records.map((r) => r.formations)).toStringAsFixed(1)}')
    ..writeln('  1 試合の捕獲数: '
        '${_avg(records.map((r) => r.captures)).toStringAsFixed(1)}')
    ..writeln('  成立が 0 の試合: '
        '${_pct(records.where((r) => r.formations == 0).length / trials)}');

  final lengths = <int, int>{};
  for (final record in records) {
    record.lengths.forEach((length, count) {
      lengths[length] = (lengths[length] ?? 0) + count;
    });
  }
  final total = lengths.values.fold(0, (a, b) => a + b);
  final keys = lengths.keys.toList()..sort();
  stdout.writeln('  長さの内訳    : ${keys.map((l) => '$l文字 '
      '${_pct(total == 0 ? 0 : lengths[l]! / total)}').join(' / ')}');
}

double _avg(Iterable<int> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
