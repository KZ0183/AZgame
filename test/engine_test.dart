/// エンジンの検査。
library;

import 'dart:math';

import 'package:azgame/src/data/catalog.g.dart';
import 'package:azgame/src/data/enemies.g.dart';
import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/battle.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/engine/enemy.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// 何もしてこない案山子。攻撃側の規則だけを見たいときに使う。
const EnemyDef dummy = EnemyDef(
  id: 'dummy',
  name: '案山子',
  glyph: '🗿',
  life: 100,
  flavor: '動かない',
  lesson: '検査用',
  pattern: [EnemyAction(kind: EnemyActionKind.empower)],
);

EnemyDef enemyWith(List<EnemyAction> pattern, {int life = 100}) => EnemyDef(
      id: 'test',
      name: '検査体',
      glyph: '🧪',
      life: life,
      flavor: '',
      lesson: '',
      pattern: pattern,
    );

Battle buildBattle({
  EnemyDef enemy = dummy,
  DeckList deck = starterDeck,
  List<String>? cards,
  int seed = 1,
}) =>
    Battle(
      enemy: enemy,
      deck: cards ?? deck.toCardList(),
      rng: Random(seed),
    );

/// 攻撃できる状態のミニオンを直接置く。
Minion put(List<Minion> field, String kana) {
  final minion = Minion(cardCatalog[kana]!)..summoningSick = false;
  field.add(minion);
  return minion;
}

void main() {
  group('カード', () {
    test('46 枚あり、段がそのままコストになっている', () {
      expect(cardCatalog.length, 46);
      const danCost = {
        'あいうえお': [1, 2, 3, 4, 5],
      };
      for (final entry in danCost.entries) {
        for (var i = 0; i < entry.key.length; i++) {
          expect(cardCatalog[entry.key[i]]!.cost, entry.value[i]);
        }
      }
      expect(cardCatalog['こ']!.cost, 5, reason: 'こ は お段');
      expect(cardCatalog['ん']!.cost, 6, reason: 'ん だけ 6');
    });

    test('行が能力を決めている', () {
      expect(cardCatalog['か']!.has(Keyword.charge), isTrue);
      expect(cardCatalog['た']!.has(Keyword.taunt), isTrue);
      expect(cardCatalog['な']!.has(Keyword.lifesteal), isTrue);
      expect(cardCatalog['は']!.has(Keyword.pierce), isTrue);
      expect(cardCatalog['さ']!.onPlay, OnPlay.snipe);
      expect(cardCatalog['ら']!.onPlay, OnPlay.draw);
      expect(cardCatalog['わ']!.onPlay, OnPlay.heal);
      expect(cardCatalog['あ']!.keywords, isEmpty);
    });

    test('同じ行では上の段が下の段の上位互換になっている', () {
      for (final row in ['あ行', 'か行', 'さ行', 'た行', 'な行', 'は行', 'ま行', 'ら行']) {
        final cards = cardCatalog.values.where((c) => c.row == row).toList()
          ..sort((a, b) => a.cost.compareTo(b.cost));
        for (var i = 1; i < cards.length; i++) {
          expect(cards[i].power + cards[i].toughness,
              greaterThan(cards[i - 1].power + cards[i - 1].toughness),
              reason: '$row の ${cards[i].kana}');
        }
      }
    });

    test('マナカーブが 1 から 6 まで途切れていない', () {
      final costs = cardCatalog.values.map((c) => c.cost).toSet();
      expect(costs, {1, 2, 3, 4, 5, 6});
    });
  });

  group('マナ', () {
    test('ターンごとに自動で 1 増え、毎ターン全回復する', () {
      final battle = buildBattle()..start();
      expect(battle.maxMana, 1);
      battle.endTurn();
      expect(battle.maxMana, 2);
      expect(battle.mana, 2);
    });

    test('マナ上限は 10 で頭打ちになる', () {
      final battle = buildBattle()..start();
      for (var i = 0; i < 20; i++) {
        battle.endTurn();
      }
      expect(battle.maxMana, kMaxMana);
    });

    test('マナが足りないカードは出せない', () {
      final battle = buildBattle()..start();
      battle.hand.add('ん'); // コスト 6
      expect(battle.validatePlay('ん'), PlayError.notEnoughMana);
    });

    test('カードを出すとマナが減る', () {
      final battle = buildBattle()..start();
      battle.mana = 5;
      battle.hand.add('う'); // コスト 3
      battle.play('う');
      expect(battle.mana, 2);
      expect(battle.playerMinions.single.kana, 'う');
    });

    test('場が埋まっていると出せない', () {
      final battle = buildBattle()..start();
      battle.mana = 10;
      for (var i = 0; i < kPlayerFieldLimit; i++) {
        put(battle.playerMinions, 'あ');
      }
      battle.hand.add('あ');
      expect(battle.validatePlay('あ'), PlayError.fieldFull);
    });
  });

  group('召喚酔いと突撃', () {
    test('出したターンは攻撃できない', () {
      final battle = buildBattle()..start();
      battle.mana = 5;
      battle.hand.add('あ');
      battle.play('あ');
      expect(battle.readyAttackers, isEmpty);
      expect(battle.validateAttack(battle.playerMinions.single),
          AttackError.summoningSick);
    });

    test('突撃は出したターンから殴れる', () {
      final battle = buildBattle()..start();
      battle.mana = 5;
      battle.hand.add('か');
      battle.play('か');
      expect(battle.readyAttackers.length, 1);
    });
  });

  group('攻撃', () {
    test('本体を殴ると敵のライフが減る', () {
      final battle = buildBattle()..start();
      final attacker = put(battle.playerMinions, 'え'); // 4/4
      battle.attack(attacker, null);
      expect(battle.enemyLife, dummy.life - 4);
      expect(attacker.attacked, isTrue);
    });

    test('雑魚を殴ると互いにダメージを受ける', () {
      final battle = buildBattle()..start();
      final attacker = put(battle.playerMinions, 'え'); // 4/4
      final target = put(battle.enemyMinions, 'う'); // 3/3

      battle.attack(attacker, target);
      expect(battle.enemyMinions, isEmpty, reason: 'う は倒れる');
      expect(battle.playerMinions.single.damage, 3, reason: 'え は生き残る');
      expect(battle.enemyLife, dummy.life, reason: '本体には入らない');
    });

    test('同じミニオンは 1 ターンに 1 回しか攻撃できない', () {
      final battle = buildBattle()..start();
      final attacker = put(battle.playerMinions, 'あ');
      battle.attack(attacker, null);
      expect(battle.validateAttack(attacker), AttackError.alreadyAttacked);
    });

    test('敵の挑発がいる間は本体もほかの雑魚も殴れない', () {
      final battle = buildBattle()..start();
      final attacker = put(battle.playerMinions, 'え');
      final wall = put(battle.enemyMinions, 'ち'); // 1/3 挑発
      final other = put(battle.enemyMinions, 'あ');

      expect(battle.validateAttack(attacker), AttackError.tauntInTheWay);
      expect(battle.validateAttack(attacker, target: other),
          AttackError.tauntInTheWay);
      expect(battle.validateAttack(attacker, target: wall), isNull);
    });

    test('貫通は壁を倒した余りが本体に入る', () {
      final battle = buildBattle()..start();
      final attacker = put(battle.playerMinions, 'ほ'); // 5/4 貫通
      final wall = put(battle.enemyMinions, 'ち'); // 1/3 挑発

      battle.attack(attacker, wall);
      expect(battle.enemyMinions, isEmpty);
      expect(battle.enemyLife, dummy.life - 2, reason: '5 - 3 が抜ける');
    });

    test('絆魂は与えたダメージぶんライフを戻す', () {
      final battle = buildBattle()..start();
      battle.playerLife = 10;
      final attacker = put(battle.playerMinions, 'ね'); // 3/4 絆魂
      battle.attack(attacker, null);
      expect(battle.playerLife, 13);
    });

    test('絆魂でも最大ライフは超えない', () {
      final battle = buildBattle()..start();
      final attacker = put(battle.playerMinions, 'ね');
      battle.attack(attacker, null);
      expect(battle.playerLife, kPlayerLife);
    });
  });

  group('出したときの効果', () {
    test('狙撃は敵の雑魚を焼く', () {
      final battle = buildBattle()..start();
      put(battle.enemyMinions, 'あ'); // 1/1
      battle.mana = 5;
      battle.hand.add('さ'); // 狙撃 1
      battle.play('さ');
      expect(battle.enemyMinions, isEmpty);
    });

    test('ドローは手札を増やす', () {
      final battle = buildBattle()..start();
      final before = battle.hand.length;
      battle.mana = 5;
      battle.hand.add('ら');
      battle.play('ら');
      expect(battle.hand.length, before + 1, reason: 'ら を出して 1 枚引く');
    });

    test('回復はライフを戻す', () {
      final battle = buildBattle()..start();
      battle.playerLife = 10;
      battle.mana = 5;
      battle.hand.add('を'); // コスト 5、回復 5
      battle.play('を');
      expect(battle.playerLife, 15);
    });
  });

  group('敵の手番', () {
    test('行動表を順になぞり、末尾まで来たら先頭に戻る', () {
      final enemy = enemyWith(const [
        EnemyAction(kind: EnemyActionKind.strike, value: 3),
        EnemyAction(kind: EnemyActionKind.strike, value: 5),
      ]);
      final battle = buildBattle(enemy: enemy)..start();

      expect(battle.nextActionLabel, contains('3'));
      battle.endTurn();
      expect(battle.playerLife, kPlayerLife - 3);
      expect(battle.nextActionLabel, contains('5'));
      battle.endTurn();
      expect(battle.playerLife, kPlayerLife - 8);
      expect(battle.nextActionLabel, contains('3'), reason: '先頭に戻る');
    });

    test('本体の一撃は挑発では防げない', () {
      final enemy = enemyWith(const [
        EnemyAction(kind: EnemyActionKind.strike, value: 6),
      ]);
      final battle = buildBattle(enemy: enemy)..start();
      final wall = put(battle.playerMinions, 'と'); // 4/6 挑発

      battle.endTurn();
      expect(battle.playerLife, kPlayerLife - 6);
      expect(wall.damage, 0);
    });

    test('雑魚の攻撃は挑発が引き受ける', () {
      final enemy = enemyWith(const [
        EnemyAction(kind: EnemyActionKind.summon, summons: ['い']),
        EnemyAction(kind: EnemyActionKind.empower),
      ]);
      final battle = buildBattle(enemy: enemy)..start();
      final wall = put(battle.playerMinions, 'と'); // 4/6 挑発

      battle.endTurn(); // 召喚。出たターンは殴れない
      expect(battle.playerLife, kPlayerLife);
      battle.endTurn(); // い (2/2) が と (4/6) を殴る
      expect(battle.playerLife, kPlayerLife, reason: '壁が受けている');
      expect(wall.damage, 2);
      expect(battle.enemyMinions, isEmpty, reason: '反撃 4 で い は倒れる');
    });

    test('薙ぎ払いはこちらの盤面全部に入る', () {
      final enemy = enemyWith(const [
        EnemyAction(kind: EnemyActionKind.sweep, value: 2),
      ]);
      final battle = buildBattle(enemy: enemy)..start();
      put(battle.playerMinions, 'あ'); // 1/1 — 死ぬ
      final tough = put(battle.playerMinions, 'む'); // 2/5 — 生き残る

      battle.endTurn();
      expect(battle.playerMinions, [tough]);
      expect(tough.damage, 2);
    });

    test('力を溜めると以降の一撃が重くなる', () {
      final enemy = enemyWith(const [
        EnemyAction(kind: EnemyActionKind.empower, value: 4),
        EnemyAction(kind: EnemyActionKind.strike, value: 5),
      ]);
      final battle = buildBattle(enemy: enemy)..start();

      battle.endTurn();
      expect(battle.nextActionLabel, contains('9'), reason: '予告にも乗る');
      battle.endTurn();
      expect(battle.playerLife, kPlayerLife - 9);
    });

    test('回復しても最大ライフは超えない', () {
      final enemy = enemyWith(
        const [EnemyAction(kind: EnemyActionKind.heal, value: 10)],
        life: 20,
      );
      final battle = buildBattle(enemy: enemy)..start();
      battle.enemyLife = 15;
      battle.endTurn();
      expect(battle.enemyLife, 20);
    });
  });

  group('決着', () {
    test('敵のライフを 0 にすれば勝ち', () {
      final battle = buildBattle()..start();
      battle.enemyLife = 3;
      battle.attack(put(battle.playerMinions, 'え'), null);
      expect(battle.playerWon, isTrue);
      expect(battle.isOver, isTrue);
    });

    test('自分のライフが 0 になれば負け', () {
      final enemy = enemyWith(const [
        EnemyAction(kind: EnemyActionKind.strike, value: 99),
      ]);
      final battle = buildBattle(enemy: enemy)..start();
      battle.endTurn();
      expect(battle.playerLost, isTrue);
    });

    test('山札が尽きると疲労で少しずつ削れる', () {
      final battle = buildBattle(cards: List.filled(kStartingHand, 'あ'))
        ..start();
      // start() の中の 1 ターン目のドローで、すでに 1 点受けている。
      expect(battle.library, isEmpty);
      expect(battle.fatigue, 1);
      expect(battle.playerLife, kPlayerLife - 1);

      battle.endTurn(); // 2 点
      battle.endTurn(); // 3 点
      expect(battle.fatigue, 3);
      expect(battle.playerLife, kPlayerLife - 6);
    });
  });

  group('デッキ', () {
    test('プリセットはすべて 30 枚で妥当', () {
      for (final deck in presetDecks) {
        expect(deck.validate(), isEmpty, reason: deck.name);
        expect(deck.size, kDeckSize);
        expect(deck.averageCost, inInclusiveRange(1.5, 3.5), reason: deck.name);
      }
    });

    test('投入上限を超えたデッキは弾かれる', () {
      const deck = DeckList(name: '超過', concept: '', counts: {'あ': 5, 'い': 25});
      expect(deck.validate().join(), contains('あ は 4 枚まで'));
    });

    test('ん は 1 枚しか入らない', () {
      expect(cardCatalog['ん']!.deckLimit, 1);
    });
  });

  group('自動プレイヤー', () {
    test('どのデッキでも、どの敵とも決着する', () {
      for (final deck in presetDecks) {
        for (final enemy in enemyRoster) {
          final battle = buildBattle(enemy: enemy, deck: deck)..start();
          const player = AutoPlayer();
          var turns = 0;
          while (!battle.isOver && turns < 60) {
            player.takeTurn(battle);
            battle.endTurn();
            turns++;
          }
          expect(battle.isOver, isTrue,
              reason: '${deck.name} vs ${enemy.name}');
        }
      }
    });

    test('挑発を無視して本体を殴ろうとはしない', () {
      final battle = buildBattle()..start();
      put(battle.playerMinions, 'え'); // 4/4
      final wall = put(battle.enemyMinions, 'ち'); // 1/3 挑発

      const AutoPlayer().takeTurn(battle);
      expect(battle.enemyLife, dummy.life, reason: '本体には届かない');
      expect(battle.enemyMinions.contains(wall), isFalse, reason: '壁を倒す');
    });

    test('複数の乱数シードで決着する', () {
      for (var seed = 0; seed < 20; seed++) {
        final battle = buildBattle(enemy: enemyRoster.last, seed: seed)..start();
        const player = AutoPlayer();
        var turns = 0;
        while (!battle.isOver && turns < 60) {
          player.takeTurn(battle);
          battle.endTurn();
          turns++;
        }
        expect(battle.isOver, isTrue, reason: 'seed $seed');
      }
    });
  });
}
