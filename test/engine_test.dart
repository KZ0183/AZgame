/// v0.5 エンジンの検査。
library;

import 'dart:math';

import 'package:azgame/src/data/catalog.g.dart';
import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

Game buildGame({List<String>? deck, int seed = 1}) => Game(
      first: PlayerState(name: '先攻', deck: deck ?? starterDeck.toCardList()),
      second: PlayerState(name: '後攻', deck: deck ?? starterDeck.toCardList()),
      firstBlocker: SimpleAi.chooseBlocks,
      secondBlocker: SimpleAi.chooseBlocks,
      rng: Random(seed),
    );

/// 戦場に攻撃可能なクリーチャーを直接置く。
Permanent putCreature(PlayerState player, String letter) {
  final creature = Permanent(letter)..summoningSick = false;
  player.creatures.add(creature);
  return creature;
}

void main() {
  group('カード', () {
    test('26 枚あり、母音 5 種が土地、子音 21 種がクリーチャー', () {
      expect(cardCatalog.length, 26);
      final lands = cardCatalog.values.where((c) => c.isLand).toList();
      expect(lands.map((c) => c.letter).toSet(), {'A', 'E', 'I', 'O', 'U'});
      expect(cardCatalog.values.where((c) => c.isCreature).length, 21);
    });

    test('クリーチャーはコストがそのままパワーとタフネスになる（バニラ）', () {
      for (final card in cardCatalog.values.where((c) => c.isCreature)) {
        expect(card.power, card.cost, reason: card.letter);
        expect(card.toughness, card.cost, reason: card.letter);
        expect(card.cost, inInclusiveRange(1, 7));
      }
    });

    test('土地はコストもパワーも 0', () {
      for (final card in cardCatalog.values.where((c) => c.isLand)) {
        expect(card.cost, 0);
        expect(card.power, 0);
      }
    });
  });

  group('マナと土地', () {
    test('土地は 1 ターンに 1 枚しか置けない', () {
      final game = buildGame()..start();
      game.first.hand.addAll(['A', 'E']);
      game.play('A');
      expect(game.validatePlay('E'), PlayError.landAlreadyPlayed);
    });

    test('マナが足りないクリーチャーは唱えられない', () {
      final game = buildGame()..start();
      game.first.hand.add('Z'); // コスト 7
      expect(game.validatePlay('Z'), PlayError.notEnoughMana);
    });

    test('クリーチャーを唱えると土地がタップされる', () {
      final game = buildGame()..start();
      game.first.lands.addAll([
        Permanent('A')..summoningSick = false,
        Permanent('E')..summoningSick = false,
      ]);
      game.first.hand.add('D'); // コスト 2
      game.play('D');
      expect(game.first.availableMana, 0);
      expect(game.first.creatures.single.letter, 'D');
    });

    test('ターンが来ると土地はアンタップされる', () {
      final game = buildGame()..start();
      game.first.lands.add(Permanent('A')..tapped = true);
      game.endTurn(); // 後攻へ
      game.endTurn(); // 先攻に戻る
      expect(game.first.availableMana, 1);
    });
  });

  group('召喚酔い', () {
    test('出したターンは攻撃できない', () {
      final game = buildGame()..start();
      game.first.lands.add(Permanent('A')..summoningSick = false);
      game.first.hand.add('L'); // コスト 1
      game.play('L');
      expect(game.first.readyAttackers, isEmpty);
    });

    test('次のターンには攻撃できる', () {
      final game = buildGame()..start();
      game.first.lands.add(Permanent('A')..summoningSick = false);
      game.first.hand.add('L');
      game.play('L');
      game.endTurn();
      game.endTurn();
      expect(game.first.readyAttackers.length, 1);
    });
  });

  group('戦闘', () {
    test('ブロックされなければライフが減る', () {
      final game = buildGame()..start();
      final attacker = putCreature(game.first, 'F'); // 4/4
      final result = game.attack([attacker]);

      expect(result.totalDamage, 4);
      expect(game.second.life, kStartingLife - 4);
      expect(attacker.tapped, isTrue);
    });

    test('ブロックされるとライフは減らず、互いにダメージを受ける', () {
      final game = buildGame()..start();
      final attacker = putCreature(game.first, 'B'); // 3/3
      putCreature(game.second, 'F'); // 4/4。討ち取れて生き残るのでブロックされる

      game.attack([attacker]);
      expect(game.second.life, kStartingLife);
      expect(game.first.creatures, isEmpty, reason: 'B は 4 ダメージで破壊される');
      expect(game.second.creatures.single.damage, 3, reason: 'F は生存する');
    });

    test('討ち取れない攻撃を AI は身を挺して止めない', () {
      // 3/3 で 4/4 を止めても一方的に失うだけなので、ブロックしないのが正しい。
      final game = buildGame()..start();
      final attacker = putCreature(game.first, 'F'); // 4/4
      putCreature(game.second, 'B'); // 3/3

      final result = game.attack([attacker]);
      expect(result.totalDamage, 4);
      expect(game.second.creatures.length, 1);
    });

    test('相打ちになると両方が破壊される', () {
      final game = buildGame()..start();
      final attacker = putCreature(game.first, 'F');
      putCreature(game.second, 'H'); // 4/4

      game.attack([attacker]);
      expect(game.first.creatures, isEmpty);
      expect(game.second.creatures, isEmpty);
    });

    test('ダメージはターン終了時に回復する', () {
      final game = buildGame()..start();
      final attacker = putCreature(game.first, 'B'); // 3/3
      putCreature(game.second, 'F'); // 4/4。ブロックして生き残る

      game.attack([attacker]);
      expect(game.second.creatures.single.damage, 3);
      game.endTurn();
      expect(game.second.creatures.single.damage, 0);
    });

    test('タップ済みのクリーチャーはブロックできない', () {
      final game = buildGame()..start();
      final attacker = putCreature(game.first, 'L'); // 1/1
      putCreature(game.second, 'F')..tapped = true;

      final result = game.attack([attacker]);
      expect(result.totalDamage, 1);
    });
  });

  group('決着', () {
    test('ライフが 0 になった側が負ける', () {
      final game = buildGame()..start();
      game.second.life = 3;
      final attacker = putCreature(game.first, 'F');
      game.attack([attacker]);

      expect(game.isOver, isTrue);
      expect(game.winner, game.first);
    });

    test('空のデッキから引くと負ける', () {
      // 先攻だけ山札を薄くする。先攻は 1 ターン目にドローしないため、
      // 2 巡目のドローで敗北が確定する。
      final game = Game(
        first: PlayerState(
            name: '先攻', deck: List.filled(kStartingHand, 'A')),
        second: PlayerState(name: '後攻', deck: starterDeck.toCardList()),
        firstBlocker: SimpleAi.chooseBlocks,
        secondBlocker: SimpleAi.chooseBlocks,
        rng: Random(1),
      )..start();

      expect(game.first.library, isEmpty);
      game.endTurn(); // 後攻
      game.endTurn(); // 先攻がドローできない
      expect(game.first.deckedOut, isTrue);
      expect(game.winner, game.second);
    });
  });

  group('デッキ', () {
    test('基準デッキは 30 枚で、土地を 12 枚積んでいる', () {
      expect(starterDeck.validate(), isEmpty);
      expect(starterDeck.size, kDeckSize);
      expect(starterDeck.landCount, 12);
    });

    test('投入上限を超えたデッキは弾かれる', () {
      const deck = DeckList(name: '超過', counts: {'A': 5, 'L': 25});
      expect(deck.validate().join(), contains('A は 4 枚まで'));
    });
  });

  group('AI', () {
    test('AI 同士の対戦が決着まで進む', () {
      final game = buildGame();
      game.start();
      const ai = SimpleAi();
      var turns = 0;
      while (!game.isOver && turns < 200) {
        ai.takeTurn(game);
        game.endTurn();
        turns++;
      }
      expect(game.isOver, isTrue, reason: '200 ターン以内に決着しなかった');
    });

    test('AI は土地を置き、出せるクリーチャーを唱える', () {
      final game = buildGame()..start();
      game.first.hand
        ..clear()
        ..addAll(['A', 'L', 'F']); // 土地・1 マナ・4 マナ

      const SimpleAi().takeTurn(game);
      expect(game.first.lands.length, 1, reason: '土地を置くべき');
      expect(game.first.creatures.single.letter, 'L',
          reason: '1 マナで唱えられるのは L だけ');
    });

    test('複数の乱数シードで決着する', () {
      for (var seed = 0; seed < 20; seed++) {
        final game = buildGame(seed: seed)..start();
        const ai = SimpleAi();
        var turns = 0;
        while (!game.isOver && turns < 200) {
          ai.takeTurn(game);
          game.endTurn();
          turns++;
        }
        expect(game.isOver, isTrue, reason: 'seed $seed');
      }
    });
  });
}
