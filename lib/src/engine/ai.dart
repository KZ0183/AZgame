/// 非同期対戦で相手デッキを操作する AI。
library;

import '../data/catalog.g.dart';
import 'board.dart';
import 'detection.dart';
import 'game.dart';
import 'models.dart';

/// AI が選んだ 1 手。
class AiMove {
  const AiMove({
    required this.letter,
    required this.lane,
    required this.score,
  });

  final String letter;
  final int lane;
  final int score;

  @override
  String toString() => 'AiMove($letter → レーン$lane, score $score)';
}

/// 1 手先を評価する貪欲な AI。
///
/// 陣形の価値、レーンの相性、マナ基盤の 3 つを重み付けして最善手を選ぶ。
/// 深い読みはしないが、「相手の弱い文字を討ち取れるレーンに置く」「陣形が
/// 伸びる位置に置く」という基本的な判断は成立する。
class SimpleAi {
  const SimpleAi();

  /// 手番が終わるまで文字を出し続ける。
  ///
  /// 出すたびに登場時能力が盤面を変えるため、毎回評価し直す。
  void playTurn(Game game) {
    while (true) {
      final move = bestMove(game);
      if (move == null) break;
      game.playCard(move.letter, move.lane);
    }
  }

  /// 現在の盤面で最善と評価される手を返す。出せる手がなければ `null`。
  AiMove? bestMove(Game game) {
    final me = game.state.active;
    AiMove? best;

    for (final letter in me.hand.toSet()) {
      for (final lane in me.field.emptyIndices) {
        if (game.validatePlay(letter, lane) != null) continue;
        final score = _score(game, letter, lane);
        if (best == null || score > best.score) {
          best = AiMove(letter: letter, lane: lane, score: score);
        }
      }
    }
    return best;
  }

  int _score(Game game, String letter, int lane) {
    final me = game.state.active;
    final foe = game.state.inactive;
    final card = cardCatalog[letter]!;

    final simulated = me.field.copy()..place(lane, Permanent(letter));
    final formations = findFormations(simulated);

    var score = 0;

    // 陣形の価値。ワードは維持するほど効くので重く見る。
    for (final formation in formations.words) {
      score += _effectValue(formation.word.effect) * 4;
    }
    for (final sequence in formations.sequences) {
      score += sequence.powerBonus * 3;
    }

    // レーンの相性。相手と対峙するか、素通しで殴れるか。
    final blocker = foe.field[lane];
    if (blocker == null) {
      score += card.power * 3;
    } else {
      final blockerCard = cardCatalog[blocker.letter]!;
      // 討ち取れるなら大きな得
      if (card.power >= blockerCard.toughness) score += 18;
      // 一方的に討ち取られるなら避けたい
      if (blockerCard.power >= card.toughness) score -= 14;
    }

    // マナ基盤。母音は序盤ほど価値が高い。
    if (card.isVowel) {
      score += 30 - me.energyIncome * 4;
    } else {
      // 重い文字を早く置けるならそれ自体が強み
      score += card.cost * 2;
    }

    return score;
  }

  /// ワード陣形の効果を大まかな点数に均す。
  ///
  /// 継続効果どうしを比べるための粗い指標。厳密さより、AI が「強い陣形を
  /// 優先する」という方向に動くことを重視している。
  int _effectValue(WordEffect effect) {
    var value = 0;
    value += effect.powerBonus * 4;
    value += effect.toughnessBonus * 3;
    value += effect.upkeepDamage * 4;
    value += effect.upkeepHeal * 2;
    value += effect.upkeepShield * 2;
    value += effect.upkeepEnergy * 3;
    value += effect.upkeepDraw * 5;
    value += effect.freeze * 5;
    if (effect.pierce) value += 6;
    return value;
  }
}

/// 盤面評価をデバッグ表示するための補助。
String describeBoard(BoardView board) {
  final buffer = StringBuffer('${board.player.name}: ');
  for (var lane = 0; lane < Battlefield.laneCount; lane++) {
    final permanent = board.field[lane];
    if (permanent == null) {
      buffer.write('[ ] ');
      continue;
    }
    buffer.write('[${permanent.letter} '
        '${board.powerOf(lane)}/${board.toughnessOf(lane)}] ');
  }
  return buffer.toString().trimRight();
}
