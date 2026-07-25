/// ターン進行・ダメージ計算・効果解決の検査。
library;

import 'dart:math';

import 'package:azgame/src/engine/effects.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/game_state.dart';
import 'package:flutter_test/flutter_test.dart';

/// 検証用に、決定的な山札を持つ対戦を組み立てる。
///
/// 山札はシャッフルされるため、内容を固定したいテストでは
/// [Game.start] を呼ばずに手札とスペルラインを直接操作する。
Game buildGame({
  List<String>? firstDeck,
  List<String>? secondDeck,
  int seed = 42,
}) {
  final state = GameState(
    first: PlayerState(
      name: '先攻',
      deck: firstDeck ?? List<String>.filled(30, 'A'),
    ),
    second: PlayerState(
      name: '後攻',
      deck: secondDeck ?? List<String>.filled(30, 'A'),
    ),
    rng: Random(seed),
  );
  return Game(
    state: state,
    firstChooser: const HeuristicChooser(),
    secondChooser: const HeuristicChooser(),
  );
}

/// スペルラインを `'ACE__'` 形式で直接セットする。
void setLine(PlayerState player, String pattern) {
  player.line.clear();
  for (var i = 0; i < pattern.length; i++) {
    final char = pattern[i];
    if (char != '_') player.line.place(i, char);
  }
}

void main() {
  group('ダメージ適用', () {
    test('シールドが先に削られ、超過分が LP に入る', () {
      final target = PlayerState(name: 'T', deck: []);
      target.gainShield(10);
      dealDamage(target, 15);
      expect(target.shield, 0);
      expect(target.lp, kStartingLp - 5);
    });

    test('貫通ダメージはシールドを無視して LP に入る', () {
      final target = PlayerState(name: 'T', deck: []);
      target.gainShield(10);
      dealDamage(target, 8, pierce: true);
      expect(target.shield, 10);
      expect(target.lp, kStartingLp - 8);
    });

    test('T がスペルライン上にあるとダメージが 2 減る', () {
      final target = PlayerState(name: 'T', deck: []);
      setLine(target, 'T____');
      dealDamage(target, 10);
      expect(target.lp, kStartingLp - 8);
    });

    test('VEIL 中はダメージが半減する', () {
      final target = PlayerState(name: 'T', deck: []);
      target.halveIncomingDamage = true;
      dealDamage(target, 11);
      expect(target.lp, kStartingLp - 5); // 11 ~/ 2 = 5
    });

    test('軽減しきったダメージは 0 になり LP は減らない', () {
      final target = PlayerState(name: 'T', deck: []);
      setLine(target, 'T____');
      dealDamage(target, 2);
      expect(target.lp, kStartingLp);
    });
  });

  group('ワード解決', () {
    test('ACE は 固有 8 + パワー 10 + A の先頭ボーナス 3 = 21', () {
      final game = buildGame();
      setLine(game.state.first, 'ACE__');
      final result = game.resolveJudgement();
      expect(result.word!.word.word, 'ACE');
      expect(result.wordDamage, 21);
    });

    test('S を含むワードは最後に 1.5 倍される', () {
      final game = buildGame();
      setLine(game.state.first, 'STAR_');
      final result = game.resolveJudgement();
      // 固有 10 + パワー(2+2+2+2)=8 → 18 → S で 27
      expect(result.wordDamage, 27);
    });

    test('Z を含むワードは +15 され、BLAZE は 59 ダメージになる', () {
      final game = buildGame();
      setLine(game.state.first, 'BLAZE');
      final result = game.resolveJudgement();
      // 固有 16 + パワー 28 + Z の 15 = 59
      expect(result.wordDamage, 59);
    });

    test('P を含むワードはシールドを無視して LP を削る', () {
      final game = buildGame();
      game.state.second.gainShield(100);
      setLine(game.state.first, 'ZAP__');
      final result = game.resolveJudgement();

      // シークエンスぶんはシールドに吸われ、ワードぶんは貫通して LP に入る。
      final rawSequenceDamage =
          result.sequences.fold<int>(0, (sum, hit) => sum + hit.damage);
      expect(result.wordDamage, greaterThan(0));
      expect(result.sequenceDamage, 0, reason: 'シークエンスはシールドで吸い切られる');
      expect(game.state.second.shield, 100 - rawSequenceDamage);
      expect(game.state.second.lp, kStartingLp - result.wordDamage);
    });

    test('ワードを構成したカードは墓地へ送られる', () {
      final game = buildGame();
      setLine(game.state.first, 'ACE__');
      game.resolveJudgement();
      // E はエコーで残るため、墓地に行くのは A と C
      expect(game.state.first.graveyard, containsAll(['A', 'C']));
      expect(game.state.first.line.slots.contains('E'), isTrue);
    });

    test('E（エコー）はワード成立後もスペルラインに残る', () {
      final game = buildGame();
      setLine(game.state.first, 'ACE__');
      game.resolveJudgement();
      expect(game.state.first.line[2], 'E');
      expect(game.state.first.graveyard.contains('E'), isFalse);
    });

    test('negateNextWord が立っているとワードは不発になるがカードは消費される', () {
      final game = buildGame();
      game.state.first.negateNextWord = true;
      setLine(game.state.first, 'ACE__');
      final result = game.resolveJudgement();
      expect(result.wordNegated, isTrue);
      expect(result.wordDamage, 0);
      // シークエンスは無効化されないため、その分だけは LP が減る。
      expect(game.state.second.lp, kStartingLp - result.sequenceDamage);
      expect(game.state.first.graveyard, containsAll(['A', 'C']));
      expect(game.state.first.negateNextWord, isFalse);
    });

    test('WIN は相手の LP が 15 以下のときだけ +20 される', () {
      final low = buildGame();
      low.state.second.lp = 15;
      setLine(low.state.first, 'WIN__');
      final boosted = low.resolveJudgement().wordDamage;

      final high = buildGame();
      high.state.second.lp = 40;
      setLine(high.state.first, 'WIN__');
      final normal = high.resolveJudgement().wordDamage;

      expect(boosted - normal, 20);
    });

    test('UP のボーナスは次に発動したワードに乗り、使うと消える', () {
      final game = buildGame();
      game.state.first.nextWordBonus = 8;
      setLine(game.state.first, 'ACE__');
      final result = game.resolveJudgement();
      expect(result.wordDamage, 21 + 8);
      expect(game.state.first.nextWordBonus, 0);
    });

    test('1 ターンに成立するワードは 1 語だけ', () {
      final game = buildGame();
      setLine(game.state.first, 'STAR_');
      final result = game.resolveJudgement();
      expect(result.word!.word.word, 'STAR');
      // AT も部分的に読めるが、最長の STAR のみが発動する
      expect(game.state.first.line.isEmpty, isTrue);
    });
  });

  group('シークエンスとワードの同時解決', () {
    test('シークエンスが先に解決され、その後ワードでカードが消える', () {
      final game = buildGame();
      // A(1) C(3) E(5) は昇順 3 連（ランではない）かつ ACE が成立する
      setLine(game.state.first, 'ACE__');
      final result = game.resolveJudgement();

      expect(result.sequences.length, 1);
      expect(result.sequences.single.letters, ['A', 'C', 'E']);
      // パワー合計 10 × 倍率 1.5 = 15
      expect(result.sequences.single.damage, 15);
      expect(result.sequenceDamage, 15);
      expect(result.wordDamage, 21);
      expect(game.state.second.lp, kStartingLp - 15 - 21);
    });
  });

  group('ターン進行', () {
    test('エナジーはターンごとに最大値が 1 増えて全回復する', () {
      final game = buildGame();
      game.start();
      expect(game.state.first.maxEnergy, 1);
      expect(game.state.first.energy, 1);

      game.endTurn(); // 後攻の 1 ターン目
      expect(game.state.second.maxEnergy, 1);

      game.endTurn(); // 先攻の 2 ターン目
      expect(game.state.first.maxEnergy, 2);
      expect(game.state.first.energy, 2);
    });

    test('エナジーの最大値は 10 で頭打ちになる', () {
      final game = buildGame();
      game.start();
      for (var i = 0; i < 30; i++) {
        game.endTurn();
      }
      expect(game.state.first.maxEnergy, kMaxEnergyCap);
    });

    test('後攻は先攻より 1 枚多く初期手札を持つ', () {
      final game = buildGame();
      game.start();
      // 先攻は 5 枚配って 1 ターン目に 1 枚引くので 6 枚
      expect(game.state.first.hand.length, kStartingHandSize + 1);
      expect(game.state.second.hand.length, kStartingHandSize + 1);
    });

    test('エナジーが足りないカードは配置できない', () {
      final game = buildGame();
      game.start();
      game.state.first.hand.add('Z'); // コスト 8
      expect(game.validatePlacement('Z', 0), PlacementError.notEnoughEnergy);
    });

    test('1 ターンの配置枚数は基本 2 枚まで', () {
      final game = buildGame();
      game.start();
      game.state.first.energy = 10;
      game.state.first.hand.addAll(['A', 'A', 'A']);

      expect(game.state.first.remainingPlacements, kBasePlacementsPerTurn);
      game.placeCard('A', 0);
      game.placeCard('A', 1);
      expect(game.state.first.remainingPlacements, 0);
      expect(game.validatePlacement('A', 2), PlacementError.noPlacementsLeft);
    });

    test('R（ラッシュ）は配置枚数を 1 増やす', () {
      final game = buildGame();
      game.start();
      game.state.first.energy = 10;
      game.state.first.hand.addAll(['R', 'A', 'A']);

      game.placeCard('R', 0);
      expect(game.state.first.remainingPlacements, kBasePlacementsPerTurn);
    });

    test('埋まっているマスには置けない', () {
      final game = buildGame();
      game.start();
      game.state.first.energy = 10;
      game.state.first.hand.addAll(['A', 'A']);
      game.placeCard('A', 0);
      expect(game.validatePlacement('A', 0), PlacementError.slotOccupied);
    });

    test('ICE は相手の次のターンの配置枚数を 1 に制限する', () {
      final game = buildGame();
      game.start();
      setLine(game.state.first, 'ICE__');
      game.endTurn(); // 判定 → 後攻のターンが始まる
      expect(game.state.second.remainingPlacements, 1);
    });

    test('LOCK は相手の次のターンの配置を完全に封じる', () {
      final game = buildGame();
      game.start();
      // LOCK はシークエンスと合わせて 50 を超えるダメージになるため、
      // 決着せずに次ターンへ進めるよう LP を厚くしておく。
      game.state.second.lp = 300;
      setLine(game.state.first, 'LOCK_');
      game.endTurn();
      expect(game.state.second.remainingPlacements, 0);
    });

    test('FROST の制限は 2 ターン続く', () {
      final game = buildGame();
      game.start();
      game.state.second.lp = 300;
      setLine(game.state.first, 'FROST');
      game.endTurn();
      expect(game.state.second.remainingPlacements, 1);
      game.endTurn(); // 先攻の 2 ターン目
      game.endTurn(); // 後攻の 2 ターン目
      expect(game.state.second.remainingPlacements, 1);
      game.endTurn();
      game.endTurn(); // 後攻の 3 ターン目 — 制限が切れている
      expect(game.state.second.remainingPlacements, kBasePlacementsPerTurn);
    });
  });

  group('配置時能力', () {
    test('B はシールドを 3 得る', () {
      final game = buildGame();
      game.start();
      game.state.first.energy = 10;
      game.state.first.hand.add('B');
      game.placeCard('B', 0);
      expect(game.state.first.shield, 3);
    });

    test('Z は配置しただけで 10 ダメージを与える', () {
      final game = buildGame();
      game.start();
      game.state.first.energy = 10;
      game.state.first.hand.add('Z');
      game.placeCard('Z', 0);
      expect(game.state.second.lp, kStartingLp - 10);
    });

    test('X は相手のスペルラインを全破壊する', () {
      final game = buildGame();
      game.start();
      setLine(game.state.second, 'ACE__');
      game.state.first.energy = 10;
      game.state.first.hand.add('X');
      game.placeCard('X', 0);
      expect(game.state.second.line.isEmpty, isTrue);
      expect(game.state.second.graveyard, containsAll(['A', 'C', 'E']));
    });

    test('W は相手のラインを右へずらし、はみ出したカードを破壊する', () {
      final game = buildGame();
      game.start();
      setLine(game.state.second, 'ACE_Z');
      game.state.first.energy = 10;
      game.state.first.hand.add('W');
      game.placeCard('W', 0);
      expect(game.state.second.line.toString(), '_ACE_');
      expect(game.state.second.graveyard, contains('Z'));
    });

    test('Y は LP を 3 失う代わりに 3 枚引く', () {
      final game = buildGame(firstDeck: List<String>.filled(30, 'C'));
      game.start();
      final before = game.state.first.hand.length;
      game.state.first.energy = 10;
      game.state.first.hand.add('Y');
      game.placeCard('Y', 0);
      expect(game.state.first.lp, kStartingLp - 3);
      expect(game.state.first.hand.length, before + 3);
    });
  });

  group('決着', () {
    test('LP が 0 以下になった側が敗北する', () {
      final game = buildGame();
      game.state.second.lp = 5;
      setLine(game.state.first, 'ACE__');
      game.resolveJudgement();
      expect(game.state.isOver, isTrue);
      expect(game.state.winner, game.state.first);
    });

    test('デッキが尽きた状態でドローすると敗北する', () {
      final game = buildGame(firstDeck: ['A', 'A', 'A', 'A', 'A', 'A']);
      game.start();
      expect(game.state.first.deck, isEmpty);
      expect(game.state.first.deckedOut, isFalse);
      game.endTurn(); // 後攻
      game.endTurn(); // 先攻 — 引けずにデッキ切れ
      expect(game.state.first.deckedOut, isTrue);
      expect(game.state.winner, game.state.second);
    });
  });
}
