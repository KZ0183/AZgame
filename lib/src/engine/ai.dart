/// 対戦相手を務める AI。
///
/// 初期 MTG のバニラ構成が土台なので、判断も素朴でよい。
/// 「土地を置く」「出せる中で一番重いクリーチャーを出す」
/// 「損をしない攻撃だけ仕掛ける」の 3 つで組み立てている。
library;

import '../data/catalog.g.dart';
import 'game.dart';
import 'models.dart';

class SimpleAi {
  const SimpleAi();

  /// 1 ターンぶんを打ち切る。ターン終了は呼び出し側が行う。
  CombatResult takeTurn(Game game) {
    _developBoard(game);
    return game.attack(_chooseAttackers(game));
  }

  /// 土地を置き、出せる中で最も重いクリーチャーを順に唱える。
  void _developBoard(Game game) {
    final player = game.active;

    final land = player.hand.firstWhere(
      (letter) => cardCatalog[letter]!.isLand,
      orElse: () => '',
    );
    if (land.isNotEmpty && game.validatePlay(land) == null) game.play(land);

    while (true) {
      final castable = player.hand
          .where((letter) =>
              cardCatalog[letter]!.isCreature && game.validatePlay(letter) == null)
          .toList()
        ..sort((a, b) =>
            cardCatalog[b]!.cost.compareTo(cardCatalog[a]!.cost));
      if (castable.isEmpty) break;
      game.play(castable.first);
    }
  }

  /// 攻撃するクリーチャーを選ぶ。
  ///
  /// 相手のブロッカーより大きいか、相手に盤面がないときだけ攻める。
  /// 一方的に討ち取られる攻撃は避ける。
  List<Permanent> _chooseAttackers(Game game) {
    final me = game.active;
    final foe = game.inactive;
    final blockers = foe.readyBlockers;

    // 攻撃が通れば勝てるなら全力で攻める。
    final totalPower = me.readyAttackers.fold<int>(
        0, (sum, c) => sum + cardCatalog[c.letter]!.power);
    if (blockers.isEmpty || totalPower >= foe.life) return me.readyAttackers;

    final biggestBlocker = blockers
        .map((b) => cardCatalog[b.letter]!.power)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return me.readyAttackers.where((creature) {
      final card = cardCatalog[creature.letter]!;
      // タフネスが相手の最大パワーを上回るなら、討ち取られずに済む。
      return card.toughness > biggestBlocker;
    }).toList();
  }

  /// ブロックの割り当て。
  ///
  /// 討ち取れる相手を優先し、それが無理でも致死打点は身を挺して止める。
  static Map<Permanent, Permanent?> chooseBlocks(
    List<Permanent> attackers,
    List<Permanent> blockers,
  ) {
    final assignment = <Permanent, Permanent?>{};
    final available = List<Permanent>.of(blockers);

    // 大きい攻撃から順に対処する。
    final ordered = List<Permanent>.of(attackers)
      ..sort((a, b) => cardCatalog[b.letter]!.power
          .compareTo(cardCatalog[a.letter]!.power));

    for (final attacker in ordered) {
      final attackerCard = cardCatalog[attacker.letter]!;

      // 相打ちにならず討ち取れるブロッカーを探す。
      Permanent? best;
      for (final blocker in available) {
        final card = cardCatalog[blocker.letter]!;
        final kills = card.power >= attackerCard.toughness;
        final survives = card.toughness > attackerCard.power;
        if (kills && survives) {
          best = blocker;
          break;
        }
      }
      // 次善。討ち取れるなら相打ちでもよい。
      best ??= available.where((b) {
        final card = cardCatalog[b.letter]!;
        return card.power >= attackerCard.toughness;
      }).firstOrNull;

      if (best != null) {
        assignment[attacker] = best;
        available.remove(best);
      }
    }
    return assignment;
  }
}

/// 何もブロックしない。デバッグと基準測定に使う。
Map<Permanent, Permanent?> blockNothing(
  List<Permanent> attackers,
  List<Permanent> blockers,
) =>
    {};
