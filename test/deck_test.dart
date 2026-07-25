/// デッキ検証とプリセットデッキの検査、および AI の通し動作確認。
library;

import 'dart:math';

import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

Game gameFromDecks(DeckList a, DeckList b, {int seed = 1}) {
  final state = GameState(
    first: PlayerState(name: a.name, deck: a.toCardList()),
    second: PlayerState(name: b.name, deck: b.toCardList()),
    rng: Random(seed),
  );
  return Game(
    state: state,
    firstChooser: const HeuristicChooser(),
    secondChooser: const HeuristicChooser(),
  );
}

void main() {
  group('デッキ検証', () {
    test('プリセットデッキはすべてルールを満たす', () {
      for (final deck in starterDecks) {
        expect(deck.validate(), isEmpty, reason: '${deck.name}: ${deck.validate()}');
        expect(deck.size, kDeckSize);
      }
    });

    test('枚数が足りないデッキは弾かれる', () {
      const deck = DeckList(name: '不足', counts: {'A': 4, 'E': 4});
      expect(deck.isValid, isFalse);
    });

    test('投入上限を超えたデッキは弾かれる', () {
      final counts = {'A': 5, 'E': 4, 'I': 4, 'O': 3, 'U': 3, 'L': 3, 'S': 3, 'N': 3, 'T': 2};
      final deck = DeckList(name: '上限超過', counts: counts);
      expect(deck.size, kDeckSize);
      expect(
        deck.validate().map((v) => v.message).join(),
        contains('A は 4 枚までです'),
      );
    });

    test('未知の文字は弾かれる', () {
      const deck = DeckList(name: '不正', counts: {'あ': 30});
      expect(deck.validate().map((v) => v.message).join(), contains('未知の文字'));
    });

    test('プリセットデッキは主軸となるワードを組める', () {
      expect(starterAggro.buildableWords(), containsAll(['ACE', 'FIRE', 'STAR', 'ZAP']));
      expect(starterControl.buildableWords(), containsAll(['HEAL', 'CALM', 'ICE', 'OAK']));
    });

    test('組めるワードは長い順に並ぶ', () {
      final words = starterAggro.buildableWords();
      for (var i = 1; i < words.length; i++) {
        expect(words[i - 1].length, greaterThanOrEqualTo(words[i].length));
      }
    });
  });

  group('AI による通し対戦', () {
    test('AI 同士の対戦が決着まで進み、状態が壊れない', () {
      final game = gameFromDecks(starterAggro, starterControl);
      game.start();

      const ai = SimpleAi();
      var turns = 0;
      while (!game.state.isOver && turns < 100) {
        ai.playTurn(game);
        game.endTurn();
        turns++;

        // 不変条件: 盤面が壊れていないこと。
        for (final player in [game.state.first, game.state.second]) {
          expect(player.line.slots.length, 5);
          expect(player.energy, lessThanOrEqualTo(player.maxEnergy));
          expect(player.hand.length, lessThanOrEqualTo(kHandLimit + 5));
        }
      }

      expect(game.state.isOver, isTrue, reason: '100 ターン以内に決着しなかった');
    });

    test('複数の乱数シードで決着し、試合が極端に長引かない', () {
      final lengths = <int>[];

      for (var seed = 0; seed < 20; seed++) {
        final game = gameFromDecks(starterAggro, starterControl, seed: seed);
        game.start();
        const ai = SimpleAi();
        var turns = 0;
        while (!game.state.isOver && turns < 100) {
          ai.playTurn(game);
          game.endTurn();
          turns++;
        }
        expect(game.state.isOver, isTrue, reason: 'seed $seed で決着しなかった');
        lengths.add(turns);
      }

      // docs/game-design.md 2.3 の想定は 8〜12 ターン（両者合計で 16〜24 手番）。
      final average = lengths.reduce((a, b) => a + b) / lengths.length;
      expect(average, lessThan(40), reason: '平均 $average 手番は長すぎる');
    });

    test('AI はワードが完成する手を最優先する', () {
      final game = gameFromDecks(starterAggro, starterControl);
      game.start();
      final me = game.state.active;
      me.energy = 10;
      me.line.clear();
      me.line.place(0, 'A');
      me.line.place(1, 'C');
      me.hand
        ..clear()
        ..addAll(['E', 'B']);

      final move = const SimpleAi().bestMove(game);
      expect(move, isNotNull);
      expect(move!.letter, 'E', reason: 'ACE を完成させる E を選ぶべき');
      expect(move.slot, 2);
    });
  });
}
