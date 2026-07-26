/// マナ・戦闘・陣形・ターン進行の検査。
library;

import 'dart:math';

import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/game_state.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

Game buildGame({
  List<String>? firstDeck,
  List<String>? secondDeck,
  int seed = 42,
}) {
  final state = GameState(
    first: PlayerState(name: '先攻', deck: firstDeck ?? List.filled(30, 'A')),
    second: PlayerState(name: '後攻', deck: secondDeck ?? List.filled(30, 'A')),
    rng: Random(seed),
  );
  return Game(
    state: state,
    firstChooser: const HeuristicChooser(),
    secondChooser: const HeuristicChooser(),
  );
}

/// 戦場を `'FIRE_'` 形式で直接組む。既定では召喚酔いを解いた状態にする。
void setField(PlayerState player, String pattern, {bool ready = true}) {
  player.field.clear();
  for (var i = 0; i < pattern.length; i++) {
    if (pattern[i] == '_') continue;
    player.field.place(i, Permanent(pattern[i])..summoningSick = !ready);
  }
}

void main() {
  group('マナ', () {
    test('母音は毎ターンエナジーを生み、E は 2 生む', () {
      final game = buildGame();
      setField(game.state.first, 'AE___');
      expect(game.state.first.energyIncome, 3);
    });

    test('母音は 1 ターンに 1 枚しか出せない', () {
      final game = buildGame();
      game.start();
      game.state.first.hand.addAll(['A', 'E']);

      game.playCard('A', 0);
      expect(game.validatePlay('E', 1), PlayError.vowelLimitReached);
    });

    test('母音は出したターンからマナを生む', () {
      final game = buildGame();
      game.start();
      game.state.first.hand.add('E');
      final before = game.state.first.energy;
      game.playCard('E', 0);
      expect(game.state.first.energy, before + 2);
    });

    test('エナジーが足りない子音は出せない', () {
      final game = buildGame();
      game.start();
      game.state.first.hand.add('Z');
      expect(game.validatePlay('Z', 0), PlayError.notEnoughEnergy);
    });

    test('エナジーは持ち越されず、ターン開始時に母音の生産量に戻る', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'A____');
      game.state.first.energy = 99;

      game.endTurn(); // 後攻へ
      game.endTurn(); // 先攻に戻る
      expect(game.state.first.energy, 1);
    });

    test('埋まっているレーンには出せない', () {
      final game = buildGame();
      game.start();
      game.state.first.hand.addAll(['A', 'E']);
      game.playCard('A', 0);
      expect(game.validatePlay('E', 0), PlayError.laneOccupied);
    });
  });

  group('召喚酔い', () {
    test('出したターンは攻撃できない', () {
      final game = buildGame();
      game.start();
      game.state.first.hand.add('A');
      game.playCard('A', 0);

      final board = game.boardOf(game.state.first);
      expect(board.canAttack(0), isFalse);
    });

    test('次の自分のターンには攻撃できる', () {
      final game = buildGame();
      game.start();
      game.state.first.hand.add('A');
      game.playCard('A', 0);

      game.endTurn(); // 後攻へ
      game.endTurn(); // 先攻に戻る
      expect(game.boardOf(game.state.first).canAttack(0), isTrue);
    });

    test('R がいると召喚酔いを受けない', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'R____');
      game.state.first.energy = 10;
      game.state.first.hand.add('B');
      game.playCard('B', 1);

      expect(game.boardOf(game.state.first).canAttack(1), isTrue);
    });
  });

  group('レーン戦闘', () {
    test('相手のレーンが空なら本体にダメージが入る', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'F____'); // 4/4
      final result = game.resolveCombat();

      expect(result.totalDamage, 4);
      expect(game.state.second.lp, kStartingLp - 4);
    });

    test('対峙している場合は互いにダメージを与え合う', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'F____');  // 4/4
      setField(game.state.second, 'B____'); // 3/3

      game.resolveCombat();
      // B はタフネス 3 に 4 ダメージで破壊される
      expect(game.state.second.field[0], isNull);
      // F はタフネス 4 に 3 ダメージなので生存
      expect(game.state.first.field[0], isNotNull);
      expect(game.state.first.field[0]!.damage, 3);
      // 本体にはダメージが入らない
      expect(game.state.second.lp, kStartingLp);
    });

    test('相打ちになると両方が破壊される', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'F____');
      setField(game.state.second, 'F____');

      game.resolveCombat();
      expect(game.state.first.field[0], isNull);
      expect(game.state.second.field[0], isNull);
    });

    test('T は自分のレーンで受ける戦闘ダメージを 2 減らす', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'B____');  // 3/3
      setField(game.state.second, 'T____'); // 1/1 だが 2 軽減

      game.resolveCombat();
      // 3 - 2 = 1 ダメージ。タフネス 1 なので破壊される
      expect(game.state.second.field[0], isNull);
    });

    test('P は対峙する文字を無視して本体に通る', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'P____');  // 3/3 貫通
      setField(game.state.second, 'Z____'); // 8/8

      game.resolveCombat();
      expect(game.state.second.lp, kStartingLp - 3);
      // 貫通したので Z との殴り合いは起きない
      expect(game.state.first.field[0]!.damage, 0);
    });

    test('蓄積したダメージはターン終了時に回復する', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'F____');
      setField(game.state.second, 'Z____'); // 8/8。F は 8 受けるが…

      // F(4/4) は Z(8/8) に討ち取られる。代わりに H(4/4) で試す
      setField(game.state.first, 'H____');
      setField(game.state.second, 'T____'); // 1/1、2 軽減
      game.endTurn();
      for (final permanent in game.state.first.field.occupants) {
        expect(permanent.damage, 0);
      }
    });
  });

  group('陣形の継続効果', () {
    test('ワード陣形は文字を消費せず、盤面に残り続ける', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'FIRE_');

      game.endTurn();
      game.endTurn();
      // FIRE の 4 文字は健在
      expect(game.state.first.field.count, 4);
    });

    test('パワー加算の陣形は実効パワーに反映される', () {
      final withFormation = buildGame();
      setField(withFormation.state.first, 'WAR__'); // WAR = 全文字パワー+3
      final boosted = withFormation.boardOf(withFormation.state.first);

      final plain = buildGame();
      setField(plain.state.first, 'W_R__'); // 隙間があり陣形は不成立
      final normal = plain.boardOf(plain.state.first);

      expect(boosted.powerOf(0), greaterThan(normal.powerOf(0)));
    });

    test('毎ターン効果の陣形はターン開始時に発動する', () {
      final game = buildGame();
      game.start();
      setField(game.state.first, 'FIRE_'); // 毎ターン 5 ダメージ

      final before = game.state.second.lp;
      game.endTurn(); // 後攻へ
      game.endTurn(); // 先攻のターン開始 → FIRE が発動
      // 戦闘ぶんも入るため、少なくとも 5 は削れている
      expect(game.state.second.lp, lessThanOrEqualTo(before - 5));
    });

    test('陣形が崩れると効果は即座に消える', () {
      final game = buildGame();
      setField(game.state.first, 'WAR__');
      final before = game.boardOf(game.state.first).powerOf(0);

      game.state.first.destroyAt(1); // A を失って陣形が崩れる
      final after = game.boardOf(game.state.first).powerOf(0);
      expect(after, lessThan(before));
    });

    test('拘束の陣形は相手の文字を攻撃できなくする', () {
      // 戦闘を挟むと FROST 自身が討ち取られて陣形が崩れてしまうため、
      // 盤面を組んだうえでターン開始処理だけを走らせて検証する。
      final game = buildGame();
      setField(game.state.second, 'FROST'); // 相手 3 体を拘束
      setField(game.state.first, 'BCFHZ');

      game.beginTurn(); // 先攻のターン開始。ここで拘束を受ける
      final board = game.boardOf(game.state.first);
      final frozen = game.state.first.field.occupiedIndices
          .where((lane) => !board.canAttack(lane))
          .length;
      expect(frozen, 3);
    });
  });

  group('常在能力', () {
    test('A は隣のレーンの文字のパワーを上げる', () {
      final game = buildGame();
      setField(game.state.first, 'AB___');
      final board = game.boardOf(game.state.first);
      // B は基礎 3、隣の A で +1
      expect(board.powerOf(1), greaterThanOrEqualTo(4));
    });

    test('D は隣のレーンの文字のタフネスを上げる', () {
      final withD = buildGame();
      setField(withD.state.first, 'DB___');
      final withoutD = buildGame();
      setField(withoutD.state.first, '_B___');

      expect(withD.boardOf(withD.state.first).toughnessOf(1),
          greaterThan(withoutD.boardOf(withoutD.state.first).toughnessOf(1)));
    });

    test('K は陣形に含まれていない間だけパワーが上がる', () {
      // 単騎なら基礎 5 に +3。KEY の陣形に入ると加算が消えて 5 に戻る。
      // KEY を選んだのは、K が隣接強化も連番陣形も受けない並びだから。
      final solo = buildGame();
      setField(solo.state.first, 'K____');
      expect(solo.boardOf(solo.state.first).powerOf(0), 8);

      final inFormation = buildGame();
      setField(inFormation.state.first, 'KEY__');
      expect(inFormation.boardOf(inFormation.state.first).powerOf(0), 5);
    });
  });

  group('登場時能力', () {
    test('J は相手の文字を 1 体破壊する', () {
      final game = buildGame();
      game.start();
      setField(game.state.second, 'B____');
      game.state.first.energy = 10;
      game.state.first.hand.add('J');

      game.playCard('J', 1);
      expect(game.state.second.field.isEmpty, isTrue);
    });

    test('X は相手の全ての文字に 4 ダメージを与える', () {
      final game = buildGame();
      game.start();
      setField(game.state.second, 'BBB__'); // 3/3 が 3 体
      game.state.first.energy = 10;
      game.state.first.hand.add('X');

      game.playCard('X', 4);
      expect(game.state.second.field.isEmpty, isTrue);
    });

    test('W は相手の戦場を右へずらし、はみ出した文字を破壊する', () {
      final game = buildGame();
      game.start();
      setField(game.state.second, 'ACE_Z');
      game.state.first.energy = 10;
      game.state.first.hand.add('W');

      game.playCard('W', 0);
      expect(game.state.second.field.toString(), '_ACE_');
      expect(game.state.second.graveyard, contains('Z'));
    });
  });

  group('決着', () {
    test('LP が 0 以下になった側が敗北する', () {
      final game = buildGame();
      game.start();
      game.state.second.lp = 3;
      setField(game.state.first, 'F____');

      game.resolveCombat();
      expect(game.state.isOver, isTrue);
      expect(game.state.winner, game.state.first);
    });

    test('デッキが尽きた状態でドローすると敗北する', () {
      // 初手 5 枚を配った時点で山札が尽きる構成。先攻は 1 手番目に
      // ドローしないため、2 巡目のドローで敗北が確定する。
      final game = buildGame(firstDeck: List.filled(kStartingHandSize, 'A'));
      game.start();
      expect(game.state.first.deck, isEmpty);
      game.endTurn();
      game.endTurn();
      expect(game.state.first.deckedOut, isTrue);
      expect(game.state.winner, game.state.second);
    });
  });
}
