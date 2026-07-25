/// 非同期対戦で相手デッキを操作する AI。
///
/// 相手プレイヤーのデッキデータだけを借りて AI が動かす、という
/// 対戦形式（docs/game-design.md 2.2）を支える思考ルーチン。
library;

import '../data/catalog.g.dart';
import 'detection.dart';
import 'game.dart';
import 'game_state.dart';
import 'models.dart';

/// AI が選んだ 1 手。
class AiMove {
  const AiMove({
    required this.letter,
    required this.slot,
    required this.score,
  });

  final String letter;
  final int slot;
  final int score;

  @override
  String toString() => 'AiMove($letter → $slot, score $score)';
}

/// 1 手先までを評価する貪欲な AI。
///
/// 「ワードが完成する手」を最優先し、次にシークエンスの伸び、
/// 最後に将来ワードを作れる見込み（ポテンシャル）を見る。
/// 深い読みはしないが、予約プレイ（`A _ E` と置いて `C` を待つ）は
/// ポテンシャル評価によって自然に発生する。
class SimpleAi {
  const SimpleAi();

  /// ワードを完成させる手に与える基礎点。他の要素を必ず上回るようにする。
  static const int _wordCompletionBase = 1000;

  /// 手番が終わるまでカードを置き続ける。
  ///
  /// 配置のたびに固有能力が手札やエナジーを変えるため、毎回評価し直す。
  void playTurn(Game game) {
    while (true) {
      final move = bestMove(game);
      if (move == null) break;
      game.placeCard(move.letter, move.slot);
    }
  }

  /// 現在の盤面で最善と評価される手を返す。置ける手がなければ `null`。
  AiMove? bestMove(Game game) {
    final me = game.state.active;
    if (me.remainingPlacements <= 0) return null;

    AiMove? best;
    for (final letter in me.hand.toSet()) {
      for (var slot = 0; slot < SpellLine.slotCount; slot++) {
        if (game.validatePlacement(letter, slot) != null) continue;
        final score = _score(me, letter, slot);
        if (best == null || score > best.score) {
          best = AiMove(letter: letter, slot: slot, score: score);
        }
      }
    }
    return best;
  }

  int _score(PlayerState me, String letter, int slot) {
    final simulated = me.line.copy()
      ..removeAt(slot)
      ..place(slot, letter);
    var score = 0;

    // 上書きは既存のカードを失うぶん、明確に得でなければ選ばない。
    if (!me.line.isEmptyAt(slot)) score -= 30;

    final word = findBestWord(simulated);
    if (word != null) {
      score += _wordCompletionBase + word.word.damage * 5;
    }

    for (final hit in findSequences(simulated)) {
      score += hit.damage;
    }

    final remainingHand = List<String>.of(me.hand)..remove(letter);
    score += _potential(simulated, remainingHand);

    // 配置時能力のおおまかな価値。コストが高いカードほど効果も大きい。
    score += cardCatalog[letter]!.cost;

    return score;
  }

  /// この盤面から将来完成させられるワードの見込みを点数化する。
  ///
  /// すでに置いた文字と矛盾せず配置できるワードのうち、
  /// 最も有望なものの点数を返す。不足文字が手札にそろっていれば加点する。
  int _potential(SpellLine line, List<String> hand) {
    var best = 0;

    for (final word in wordCatalog.values) {
      for (var start = 0;
          start + word.length <= SpellLine.slotCount;
          start++) {
        final missing = <String>[];
        var compatible = true;

        for (var i = 0; i < word.length; i++) {
          final onBoard = line[start + i];
          final needed = word.word[i];
          if (onBoard == null) {
            missing.add(needed);
          } else if (onBoard != needed) {
            compatible = false;
            break;
          }
        }
        if (!compatible) continue;

        final progress = word.length - missing.length;
        if (progress == 0) continue; // まだ 1 文字も置けていない

        var value = word.damage + progress * 4;
        if (_canSupply(missing, hand)) value += 20;
        if (value > best) best = value;
      }
    }

    return best;
  }

  /// [needed] の文字をすべて [hand] から供給できるか。
  bool _canSupply(List<String> needed, List<String> hand) {
    final pool = List<String>.of(hand);
    for (final letter in needed) {
      if (!pool.remove(letter)) return false;
    }
    return true;
  }
}
