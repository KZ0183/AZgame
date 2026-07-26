/// AI 同士の対戦を大量に回してバランスを実測する。
///
///     dart run tool/simulate.dart [試行回数]
///
/// v0.3 で最も重要な指標は「ワード陣形が実際に成立し、維持されているか」。
/// 単語がゲームの中心になっているかどうかは、ここでしか確かめられない。
library;

import 'dart:io';
import 'dart:math';

import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/detection.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/game_state.dart';

class MatchRecord {
  MatchRecord({
    required this.turns,
    required this.firstWon,
    required this.decided,
    required this.byDeckOut,
    required this.combatDamage,
    required this.totalDamage,
    required this.turnsWithWord,
    required this.turnsWithSequence,
    required this.wordUsage,
    required this.longestWord,
  });

  final int turns;
  final bool firstWon;
  final bool decided;
  final bool byDeckOut;

  /// 戦闘で相手 LP に通った合計。
  final int combatDamage;

  /// 実際に減った LP の合計（両者ぶん）。
  final int totalDamage;

  /// ワード陣形が成立していた手番数。
  final int turnsWithWord;
  final int turnsWithSequence;

  final Map<String, int> wordUsage;

  /// この試合で成立した最長のワード。
  final int longestWord;
}

const int _turnLimit = 200;

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
  var combatDamage = 0;
  var turnsWithWord = 0;
  var turnsWithSequence = 0;
  var longestWord = 0;
  var turns = 0;

  final startingLp = state.first.lp + state.second.lp;

  while (!state.isOver && turns < _turnLimit) {
    ai.playTurn(game);

    // 戦闘前の盤面で陣形を数える。維持できているかを見たいので毎手番測る。
    final formations = findFormations(state.active.field);
    if (formations.words.isNotEmpty) {
      turnsWithWord++;
      for (final formation in formations.words) {
        final word = formation.word.word;
        wordUsage[word] = (wordUsage[word] ?? 0) + 1;
        if (word.length > longestWord) longestWord = word.length;
      }
    }
    if (formations.sequences.isNotEmpty) turnsWithSequence++;

    combatDamage += game.endTurn().totalDamage;
    turns++;
  }

  return MatchRecord(
    turns: turns,
    firstWon: identical(state.winner, state.first),
    decided: state.isOver,
    byDeckOut: state.first.deckedOut || state.second.deckedOut,
    combatDamage: combatDamage,
    totalDamage: startingLp - (state.first.lp + state.second.lp),
    turnsWithWord: turnsWithWord,
    turnsWithSequence: turnsWithSequence,
    wordUsage: wordUsage,
    longestWord: longestWord,
  );
}

void main(List<String> args) {
  final trials = args.isEmpty ? 500 : int.parse(args.first);

  final records = <MatchRecord>[];
  for (var seed = 0; seed < trials; seed++) {
    records.add(seed.isEven
        ? playMatch(starterAggro, starterControl, seed)
        : playMatch(starterControl, starterAggro, seed));
  }

  final decided = records.where((r) => r.decided).toList();
  final turns = decided.map((r) => r.turns).toList()..sort();

  stdout
    ..writeln('=== AZgame v0.3 バランス実測 ($trials 試合) ===')
    ..writeln()
    ..writeln('■ 試合の長さ（手番数。両者の手番を合算）')
    ..writeln('  決着率        : ${_pct(decided.length / records.length)}');

  if (turns.isNotEmpty) {
    stdout
      ..writeln('  平均          : ${_avg(turns).toStringAsFixed(1)} 手番'
          '（≒ ${(_avg(turns) / 2).toStringAsFixed(1)} ターン）')
      ..writeln('  中央値        : ${turns[turns.length ~/ 2]} 手番')
      ..writeln('  最短 / 最長   : ${turns.first} / ${turns.last} 手番')
      ..writeln('  デッキ切れ決着: '
          '${_pct(decided.where((r) => r.byDeckOut).length / decided.length)}');
  }

  final firstWins = decided.where((r) => r.firstWon).length;
  stdout
    ..writeln()
    ..writeln('■ 先攻・後攻')
    ..writeln('  先攻勝率      : ${_pct(firstWins / decided.length)}')
    ..writeln()
    ..writeln('■ ワード陣形は機能しているか（v0.3 の中心指標）');

  final wordUptime = decided
      .map((r) => r.turns == 0 ? 0.0 : r.turnsWithWord / r.turns)
      .toList();
  final sequenceUptime = decided
      .map((r) => r.turns == 0 ? 0.0 : r.turnsWithSequence / r.turns)
      .toList();

  stdout
    ..writeln('  ワード成立率  : ${_pct(_avgD(wordUptime))}'
        '（陣形が成立していた手番の割合）')
    ..writeln('  連番成立率    : ${_pct(_avgD(sequenceUptime))}')
    ..writeln('  ワードが 1 度も出ない試合: '
        '${_pct(decided.where((r) => r.turnsWithWord == 0).length / decided.length)}');

  final longest = <int, int>{};
  for (final record in decided) {
    longest[record.longestWord] = (longest[record.longestWord] ?? 0) + 1;
  }
  final lengths = longest.keys.toList()..sort();
  stdout.writeln('  試合中の最長ワード: '
      '${lengths.map((l) => '${l == 0 ? "なし" : "$l文字"} ${_pct(longest[l]! / decided.length)}').join(' / ')}');

  final combat = _avg(decided.map((r) => r.combatDamage).toList());
  final total = _avg(decided.map((r) => r.totalDamage).toList());
  stdout
    ..writeln()
    ..writeln('■ ダメージ内訳（1 試合平均）')
    ..writeln('  戦闘          : ${combat.toStringAsFixed(1)}'
        '（${_pct(total == 0 ? 0 : combat / total)}）')
    ..writeln('  能力・陣形    : ${(total - combat).toStringAsFixed(1)}'
        '（${_pct(total == 0 ? 0 : (total - combat) / total)}）');

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
    ..writeln('■ 成立したワード（上位 15。維持された手番数の合計）');
  for (final entry in ranked.take(15)) {
    stdout.writeln('  ${entry.key.padRight(6)} ${entry.value}');
  }

  final unused = <String>{};
  for (final deck in starterDecks) {
    for (final word in deck.buildableWords()) {
      if (!usage.containsKey(word)) unused.add(word);
    }
  }
  if (unused.isNotEmpty) {
    stdout
      ..writeln()
      ..writeln('■ デッキに入っているのに一度も成立しなかったワード')
      ..writeln('  ${unused.join(', ')}');
  }
}

double _avg(List<int> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

double _avgD(List<double> values) =>
    values.isEmpty ? 0 : values.reduce((a, b) => a + b) / values.length;

String _pct(double ratio) => '${(ratio * 100).toStringAsFixed(1)}%';
