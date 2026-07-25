/// AI 同士の対戦を大量に回してバランスを実測する。
///
///     dart run tool/simulate.dart [試行回数]
///
/// docs/game-design.md 8 章に挙げたバランス懸念は、机上ではなく
/// ここで出る数値で判断する。試合の長さ、先攻勝率、ワードの使用頻度、
/// 1 試合あたりのダメージ内訳を出力する。
library;

import 'dart:io';
import 'dart:math';

import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/game_state.dart';

/// 1 試合ぶんの集計結果。
class MatchRecord {
  MatchRecord({
    required this.turns,
    required this.firstWon,
    required this.decided,
    required this.wordUsage,
    required this.wordDamage,
    required this.sequenceDamage,
    required this.byDeckOut,
  });

  final int turns;
  final bool firstWon;
  final bool decided;

  /// LP ではなくデッキ切れで決着したか。
  final bool byDeckOut;
  final Map<String, int> wordUsage;
  final int wordDamage;
  final int sequenceDamage;
}

const int _turnLimit = 100;

MatchRecord playMatch(DeckList firstDeck, DeckList secondDeck, int seed) {
  final state = GameState(
    first: PlayerState(name: firstDeck.name, deck: firstDeck.toCardList()),
    second: PlayerState(name: secondDeck.name, deck: secondDeck.toCardList()),
    rng: Random(seed),
  );
  final game = Game(
    state: state,
    firstChooser: const HeuristicChooser(),
    secondChooser: const HeuristicChooser(),
  );
  game.start();

  const ai = SimpleAi();
  final wordUsage = <String, int>{};
  var wordDamage = 0;
  var sequenceDamage = 0;
  var turns = 0;

  while (!state.isOver && turns < _turnLimit) {
    ai.playTurn(game);
    final result = game.endTurn();
    turns++;

    final word = result.word;
    if (word != null && !result.wordNegated) {
      wordUsage[word.word.word] = (wordUsage[word.word.word] ?? 0) + 1;
    }
    wordDamage += result.wordDamage;
    sequenceDamage += result.sequenceDamage;
  }

  return MatchRecord(
    turns: turns,
    firstWon: identical(state.winner, state.first),
    decided: state.isOver,
    byDeckOut: state.first.deckedOut || state.second.deckedOut,
    wordUsage: wordUsage,
    wordDamage: wordDamage,
    sequenceDamage: sequenceDamage,
  );
}

void main(List<String> args) {
  final trials = args.isEmpty ? 500 : int.parse(args.first);

  final records = <MatchRecord>[];
  for (var seed = 0; seed < trials; seed++) {
    // 先攻・後攻を入れ替えて両方向を等量まわす。
    records.add(seed.isEven
        ? playMatch(starterAggro, starterControl, seed)
        : playMatch(starterControl, starterAggro, seed));
  }

  final decided = records.where((r) => r.decided).toList();
  final turns = decided.map((r) => r.turns).toList()..sort();

  stdout
    ..writeln('=== AZgame バランス実測 ($trials 試合) ===')
    ..writeln()
    ..writeln('■ 試合の長さ（手番数。両者のターンを合算）')
    ..writeln('  決着率      : ${_pct(decided.length / records.length)}');

  if (turns.isNotEmpty) {
    stdout
      ..writeln('  平均        : ${_avg(turns).toStringAsFixed(1)} 手番'
          '（≒ ${(_avg(turns) / 2).toStringAsFixed(1)} ターン）')
      ..writeln('  中央値      : ${turns[turns.length ~/ 2]} 手番')
      ..writeln('  最短 / 最長 : ${turns.first} / ${turns.last} 手番');
  }

  final deckOuts = decided.where((r) => r.byDeckOut).length;
  stdout.writeln('  デッキ切れ決着: ${_pct(deckOuts / decided.length)}'
      '（高いほど「殴り合いで決着しない」ことを意味する）');

  final byLp = decided.where((r) => !r.byDeckOut).map((r) => r.turns).toList()
    ..sort();
  if (byLp.isNotEmpty) {
    stdout.writeln('  LP 決着のみの中央値: ${byLp[byLp.length ~/ 2]} 手番');
  }

  final firstWins = decided.where((r) => r.firstWon).length;
  stdout
    ..writeln()
    ..writeln('■ 先攻・後攻')
    ..writeln('  先攻勝率    : ${_pct(firstWins / decided.length)}'
        '（0.50 から離れるほど不公平）')
    ..writeln()
    ..writeln('■ ダメージ内訳（1 試合平均）');

  final wordAvg = _avg(decided.map((r) => r.wordDamage).toList());
  final seqAvg = _avg(decided.map((r) => r.sequenceDamage).toList());
  final total = wordAvg + seqAvg;
  stdout
    ..writeln('  ワード      : ${wordAvg.toStringAsFixed(1)}'
        '（${_pct(total == 0 ? 0 : wordAvg / total)}）')
    ..writeln('  シークエンス: ${seqAvg.toStringAsFixed(1)}'
        '（${_pct(total == 0 ? 0 : seqAvg / total)}）');

  final usage = <String, int>{};
  for (final record in records) {
    record.wordUsage.forEach((word, count) {
      usage[word] = (usage[word] ?? 0) + count;
    });
  }
  final ranked = usage.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));

  stdout
    ..writeln()
    ..writeln('■ 発動されたワード（上位 15）');
  for (final entry in ranked.take(15)) {
    stdout.writeln('  ${entry.key.padRight(6)} ${entry.value} 回');
  }

  final unused = <String>[];
  for (final deck in starterDecks) {
    for (final word in deck.buildableWords()) {
      if (!usage.containsKey(word)) unused.add(word);
    }
  }
  if (unused.isNotEmpty) {
    stdout
      ..writeln()
      ..writeln('■ デッキに入っているのに一度も発動しなかったワード')
      ..writeln('  ${unused.toSet().toList().join(', ')}');
  }
}

double _avg(List<int> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
