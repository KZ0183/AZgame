/// エンジンの検査。
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
      rng: Random(seed),
    );

/// 攻撃できる状態のクリーチャーを直接置く。
Permanent put(PlayerState player, String letter) {
  final creature = Permanent(letter)..summoningSick = false;
  player.creatures.add(creature);
  return creature;
}

void main() {
  group('カード', () {
    test('26 枚すべてクリーチャーで、コストがパワーとタフネスに等しい', () {
      expect(cardCatalog.length, 26);
      for (final card in cardCatalog.values) {
        expect(card.power, card.cost, reason: card.letter);
        expect(card.toughness, card.cost, reason: card.letter);
        expect(card.cost, inInclusiveRange(1, 8));
      }
    });

    test('マナカーブが 1 から 8 まで途切れなく揃っている', () {
      final costs = cardCatalog.values.map((c) => c.cost).toSet();
      expect(costs, {1, 2, 3, 4, 5, 6, 7, 8});
    });
  });

  group('マナ', () {
    test('ターンごとに自動で 1 増え、毎ターン全回復する', () {
      final game = buildGame()..start();
      expect(game.first.maxMana, 1);
      expect(game.first.mana, 1);

      game.endTurn(); // 後攻の 1 ターン目
      expect(game.second.maxMana, 1);

      game.endTurn(); // 先攻の 2 ターン目
      expect(game.first.maxMana, 2);
      expect(game.first.mana, 2);
    });

    test('マナ上限は 10 で頭打ちになる', () {
      final game = buildGame()..start();
      for (var i = 0; i < 30; i++) {
        game.endTurn();
      }
      expect(game.first.maxMana, kMaxMana);
    });

    test('マナが足りないカードは出せない', () {
      final game = buildGame()..start();
      game.first.hand.add('Z'); // コスト 8
      expect(game.validatePlay('Z'), PlayError.notEnoughMana);
    });

    test('カードを出すとマナが減る', () {
      final game = buildGame()..start();
      game.first.mana = 5;
      game.first.hand.add('D'); // コスト 3
      game.play('D');
      expect(game.first.mana, 2);
      expect(game.first.creatures.single.letter, 'D');
    });

    test('場が埋まっていると出せない', () {
      final game = buildGame()..start();
      game.first.mana = 10;
      for (var i = 0; i < kFieldLimit; i++) {
        put(game.first, 'A');
      }
      game.first.hand.add('A');
      expect(game.validatePlay('A'), PlayError.fieldFull);
    });
  });

  group('召喚酔い', () {
    test('出したターンは攻撃できない', () {
      final game = buildGame()..start();
      game.first.mana = 5;
      game.first.hand.add('A');
      game.play('A');
      expect(game.first.readyAttackers, isEmpty);
      expect(game.validateAttack(game.first.creatures.single),
          AttackError.summoningSick);
    });

    test('次の自分のターンには攻撃できる', () {
      final game = buildGame()..start();
      game.first.mana = 5;
      game.first.hand.add('A');
      game.play('A');
      game.endTurn();
      game.endTurn();
      expect(game.first.readyAttackers.length, 1);
    });
  });

  group('攻撃', () {
    test('本体を殴るとライフが減る', () {
      final game = buildGame()..start();
      final attacker = put(game.first, 'M'); // 4/4
      final result = game.attack(attacker, null);

      expect(result.damageToPlayer, 4);
      expect(game.second.life, kStartingLife - 4);
      expect(attacker.attacked, isTrue);
    });

    test('クリーチャーを殴ると互いにダメージを受ける', () {
      final game = buildGame()..start();
      final attacker = put(game.first, 'M'); // 4/4
      final target = put(game.second, 'D'); // 3/3

      game.attack(attacker, target);
      expect(game.second.creatures, isEmpty, reason: 'D は倒れる');
      expect(game.first.creatures.single.damage, 3, reason: 'M は生き残る');
      expect(game.second.life, kStartingLife, reason: '本体には入らない');
    });

    test('相打ちになると両方倒れる', () {
      final game = buildGame()..start();
      final attacker = put(game.first, 'M'); // 4/4
      final target = put(game.second, 'P'); // 4/4

      game.attack(attacker, target);
      expect(game.first.creatures, isEmpty);
      expect(game.second.creatures, isEmpty);
    });

    test('同じクリーチャーは 1 ターンに 1 回しか攻撃できない', () {
      final game = buildGame()..start();
      final attacker = put(game.first, 'A');
      game.attack(attacker, null);
      expect(game.validateAttack(attacker), AttackError.alreadyAttacked);
    });

    test('相手のクリーチャーでは攻撃できない', () {
      final game = buildGame()..start();
      final enemy = put(game.second, 'A');
      expect(game.validateAttack(enemy), AttackError.notYourCreature);
    });

    test('ブロックは存在せず、選んだ相手にだけダメージが入る', () {
      final game = buildGame()..start();
      final attacker = put(game.first, 'A'); // 1/1
      put(game.second, 'Z'); // 8/8。守りに入ることはない

      final result = game.attack(attacker, null);
      expect(result.damageToPlayer, 1);
      expect(game.second.creatures.single.damage, 0);
    });
  });

  group('決着', () {
    test('ライフが 0 になった側が負ける', () {
      final game = buildGame()..start();
      game.second.life = 3;
      game.attack(put(game.first, 'M'), null);
      expect(game.isOver, isTrue);
      expect(game.winner, game.first);
    });

    test('空のデッキから引くと負ける', () {
      final game = Game(
        first: PlayerState(name: '先攻', deck: List.filled(kStartingHand, 'A')),
        second: PlayerState(name: '後攻', deck: starterDeck.toCardList()),
        rng: Random(1),
      )..start();

      expect(game.first.library, isEmpty);
      game.endTurn();
      game.endTurn();
      expect(game.first.deckedOut, isTrue);
      expect(game.winner, game.second);
    });
  });

  group('デッキ', () {
    test('基準デッキは 30 枚で妥当なカーブを持つ', () {
      expect(starterDeck.validate(), isEmpty);
      expect(starterDeck.size, kDeckSize);
      expect(starterDeck.averageCost, inInclusiveRange(2.0, 3.5));
    });

    test('投入上限を超えたデッキは弾かれる', () {
      const deck = DeckList(name: '超過', counts: {'A': 5, 'E': 25});
      expect(deck.validate().join(), contains('A は 4 枚まで'));
    });
  });

  group('AI', () {
    test('AI 同士の対戦が決着する', () {
      final game = buildGame()..start();
      const ai = SimpleAi();
      var turns = 0;
      while (!game.isOver && turns < 200) {
        ai.takeTurn(game);
        game.endTurn();
        turns++;
      }
      expect(game.isOver, isTrue);
    });

    test('AI は一方的に討ち取れる相手を狙う', () {
      final game = buildGame()..start();
      final attacker = put(game.first, 'M'); // 4/4
      final weak = put(game.second, 'A'); // 1/1
      put(game.second, 'Z'); // 8/8。狙うと自分が倒れる

      const SimpleAi().takeTurn(game);
      expect(game.second.creatures.contains(weak), isFalse,
          reason: '討ち取れる A を狙うべき');
      expect(game.first.creatures.contains(attacker), isTrue);
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
