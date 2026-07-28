/// 1 回の道中。敵を順に相手にし、ライフだけを持ち越す。
///
/// デッキは戦闘ごとに元通りに戻る。**道中でカードが増えることはない。**
/// 増えるのを許すと結局カードを供給し続ける必要が出てくるので、
/// 変わるのは敵だけ、という線をここで引いている。
library;

import 'dart:math';

import '../data/enemies.g.dart';
import 'battle.dart';
import 'deck.dart';
import 'enemy.dart';

/// 1 体倒すごとの回復量。
const int kVictoryHeal = 8;

class Run {
  Run({this.deck = starterDeck});

  /// 次に使うデッキ。**敵ごとに組み替えてよい。**
  ///
  /// 相手の行動表は戦う前から見えているので、
  /// 「この相手に何を持ち込むか」がこのゲームの主要な選択になる。
  DeckList deck;

  /// 何体目に挑んでいるか。0 始まり。
  int stage = 0;

  /// 持ち越しライフ。
  int life = kPlayerLife;

  bool get isCleared => stage >= enemyRoster.length;
  int get total => enemyRoster.length;
  EnemyDef get current => enemyRoster[stage];

  Battle begin({Random? rng}) => Battle(
        enemy: current,
        deck: deck.toCardList(),
        playerLife: life,
        rng: rng,
      );

  /// 撃破後。残ライフを持ち越し、少しだけ回復して次へ進む。
  void advance(int remainingLife) {
    life = min(kPlayerLife, remainingLife + kVictoryHeal);
    stage++;
  }
}
