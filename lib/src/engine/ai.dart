/// 対戦相手を務める AI。
library;

import '../data/catalog.g.dart';
import 'game.dart';
import 'models.dart';

class SimpleAi {
  const SimpleAi();

  /// 1 ターンぶんを打ち切る。ターン終了は呼び出し側が行う。
  void takeTurn(Game game) {
    _playCards(game);
    _attack(game);
  }

  /// 出せる中で最も重いクリーチャーから順に、マナを使い切るまで出す。
  void _playCards(Game game) {
    while (true) {
      final playable = game.active.hand
          .where((letter) => game.validatePlay(letter) == null)
          .toList()
        ..sort((a, b) => cardCatalog[b]!.cost.compareTo(cardCatalog[a]!.cost));
      if (playable.isEmpty) break;
      game.play(playable.first);
    }
  }

  void _attack(Game game) {
    while (true) {
      final me = game.active;
      final foe = game.inactive;
      final attackers = me.readyAttackers;
      if (attackers.isEmpty || game.isOver) break;

      // 本体を殴り切って勝てるなら、盤面を無視して顔に行く。
      final totalPower = attackers.fold<int>(
          0, (sum, c) => sum + cardCatalog[c.letter]!.power);
      if (totalPower >= foe.life) {
        game.attack(attackers.first, null);
        continue;
      }

      final attacker = attackers.first;
      game.attack(attacker, _chooseTarget(attacker, foe.creatures));
    }
  }

  /// 攻撃対象を選ぶ。
  ///
  /// 「一方的に討ち取れる相手」を最優先し、次に「相打ちでも大物を倒せる相手」。
  /// どちらもなければ本体を殴る。
  Permanent? _chooseTarget(Permanent attacker, List<Permanent> enemies) {
    final card = cardCatalog[attacker.letter]!;

    Permanent? oneSided;
    Permanent? trade;

    for (final enemy in enemies) {
      final enemyCard = cardCatalog[enemy.letter]!;
      final kills = card.power >= enemyCard.toughness - enemy.damage;
      final survives = enemyCard.power < card.toughness - attacker.damage;
      if (!kills) continue;

      if (survives) {
        // 一方的に討ち取れるなら、より大きい相手を選ぶ。
        if (oneSided == null ||
            enemyCard.cost > cardCatalog[oneSided.letter]!.cost) {
          oneSided = enemy;
        }
      } else if (enemyCard.cost > card.cost) {
        // 相打ちでも、自分より重い相手を倒せるなら得。
        if (trade == null || enemyCard.cost > cardCatalog[trade.letter]!.cost) {
          trade = enemy;
        }
      }
    }

    return oneSided ?? trade;
  }
}
