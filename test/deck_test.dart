/// デッキ検証とプリセットデッキの検査、および AI の通し動作確認。
library;

import 'dart:math';

import 'package:azgame/src/data/catalog.g.dart';
import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/game_state.dart';
import 'package:azgame/src/engine/models.dart';
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

int vowelCount(DeckList deck) => deck.counts.entries
    .where((e) => cardCatalog[e.key]!.isVowel)
    .fold(0, (sum, e) => sum + e.value);

void main() {
  group('デッキ検証', () {
    test('プリセットデッキはすべてルールを満たす', () {
      for (final deck in starterDecks) {
        expect(deck.validate(), isEmpty, reason: '${deck.name}: ${deck.validate()}');
        expect(deck.size, kDeckSize);
      }
    });

    test('プリセットデッキはマナ源を十分に積んでいる', () {
      // MTG の土地枚数と同じ判断。少なすぎるとエナジーが伸びず重い文字が腐る。
      for (final deck in starterDecks) {
        final vowels = vowelCount(deck);
        expect(vowels, greaterThanOrEqualTo(10),
            reason: '${deck.name} の母音が $vowels 枚では足りない');
        expect(vowels, lessThanOrEqualTo(18),
            reason: '${deck.name} の母音が $vowels 枚では戦力が足りない');
      }
    });

    test('枚数が足りないデッキと上限超過は弾かれる', () {
      const short = DeckList(name: '不足', counts: {'A': 4, 'E': 4});
      expect(short.isValid, isFalse);

      const over = DeckList(name: '上限超過', counts: {
        'A': 5, 'E': 4, 'I': 4, 'O': 3, 'U': 3, 'L': 3, 'S': 3, 'N': 3, 'T': 2,
      });
      expect(over.validate().map((v) => v.message).join(), contains('A は 4 枚まで'));
    });

    test('未知の文字は弾かれる', () {
      const deck = DeckList(name: '不正', counts: {'あ': 30});
      expect(deck.validate().map((v) => v.message).join(), contains('未知の文字'));
    });

    test('プリセットデッキは主軸となるワードを組める', () {
      expect(starterAggro.buildableWords(), containsAll(['ACE', 'FIRE', 'STAR']));
      expect(starterControl.buildableWords(), containsAll(['HEAL', 'CALM', 'ICE']));
    });
  });

  group('AI による通し対戦', () {
    test('AI 同士の対戦が決着まで進み、盤面が壊れない', () {
      final game = gameFromDecks(starterAggro, starterControl);
      game.start();

      const ai = SimpleAi();
      var turns = 0;
      while (!game.state.isOver && turns < 200) {
        ai.playTurn(game);
        game.endTurn();
        turns++;

        for (final player in [game.state.first, game.state.second]) {
          expect(player.field.lanes.length, Battlefield.laneCount);
          expect(player.energy, greaterThanOrEqualTo(0));
          expect(player.vowelsPlayedThisTurn, lessThanOrEqualTo(kVowelsPerTurn));
        }
      }

      expect(game.state.isOver, isTrue, reason: '200 手番以内に決着しなかった');
    });

    test('複数の乱数シードで決着する', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = gameFromDecks(starterAggro, starterControl, seed: seed);
        game.start();
        const ai = SimpleAi();
        var turns = 0;
        while (!game.state.isOver && turns < 200) {
          ai.playTurn(game);
          game.endTurn();
          turns++;
        }
        expect(game.state.isOver, isTrue, reason: 'seed $seed で決着しなかった');
      }
    });

    test('AI は序盤にマナ源を優先して出す', () {
      final game = gameFromDecks(starterAggro, starterControl);
      game.start();
      final me = game.state.active;
      me.field.clear();
      me.hand
        ..clear()
        ..addAll(['A', 'S']); // 母音とコスト 1 の子音
      me.energy = 5;

      final move = const SimpleAi().bestMove(game);
      expect(move, isNotNull);
      expect(move!.letter, 'A', reason: 'マナ基盤がない序盤は母音が最優先');
    });

    test('AI は陣形が伸びる位置を選ぶ', () {
      final game = gameFromDecks(starterAggro, starterControl);
      game.start();
      final me = game.state.active;
      me.field.clear();
      me.field.place(0, Permanent('A')..summoningSick = false);
      me.field.place(1, Permanent('C')..summoningSick = false);
      me.hand
        ..clear()
        ..addAll(['E']);
      me.energy = 5;
      me.vowelsPlayedThisTurn = 0;

      final move = const SimpleAi().bestMove(game);
      expect(move, isNotNull);
      expect(move!.lane, 2, reason: 'ACE が完成するレーンを選ぶべき');
    });
  });
}
