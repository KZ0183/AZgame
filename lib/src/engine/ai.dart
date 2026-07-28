/// プレイヤー側を自動で打つヒューリスティック。
///
/// 対戦相手ではない（相手は [EnemyDef] の行動表）。
/// バランス実測で「そこそこ上手い人」の代わりを務めるためのもの。
library;

import '../data/catalog.g.dart';
import 'battle.dart';
import 'models.dart';

class AutoPlayer {
  const AutoPlayer();

  /// 1 ターンぶんを打ち切る。ターン終了は呼び出し側が行う。
  void takeTurn(Battle battle) {
    _playCards(battle);
    _attack(battle);
  }

  /// 出せる中で最も重いカードから順に、マナを使い切るまで出す。
  void _playCards(Battle battle) {
    while (true) {
      final playable = battle.hand
          .where((kana) => battle.validatePlay(kana) == null)
          .toList()
        ..sort((a, b) => cardCatalog[b]!.cost.compareTo(cardCatalog[a]!.cost));
      if (playable.isEmpty) break;
      battle.play(playable.first);
    }
  }

  void _attack(Battle battle) {
    while (!battle.isOver) {
      final attackers = battle.readyAttackers;
      if (attackers.isEmpty) break;
      final attacker = attackers.first;
      battle.attack(attacker, _chooseTarget(battle, attacker));
    }
  }

  /// 攻撃対象を選ぶ。
  ///
  /// 挑発がいれば選択の余地はない。いなければ、削り切れるなら本体、
  /// そうでなければ「一方的に討ち取れる雑魚」を優先する。
  Minion? _chooseTarget(Battle battle, Minion attacker) {
    final taunts = battle.enemyTaunts;
    if (taunts.isNotEmpty) {
      final killable =
          taunts.where((t) => t.remaining <= attacker.card.power).toList();
      final pool = killable.isNotEmpty ? killable : taunts;
      pool.sort((a, b) => a.remaining.compareTo(b.remaining));
      return pool.first;
    }

    // このターンで削り切れるなら、盤面を無視して本体へ。
    final reach = battle.readyAttackers
        .fold<int>(0, (sum, m) => sum + m.card.power);
    if (reach >= battle.enemyLife) return null;

    Minion? oneSided;
    for (final enemy in battle.enemyMinions) {
      final kills = attacker.card.power >= enemy.remaining;
      final survives = enemy.card.power < attacker.remaining;
      if (!kills || !survives) continue;
      if (oneSided == null || enemy.card.cost > oneSided.card.cost) {
        oneSided = enemy;
      }
    }
    return oneSided;
  }
}
