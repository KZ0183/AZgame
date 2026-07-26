/// 対戦相手を務める AI。
///
/// 完全情報ゲームなので隠された情報はなく、AI は人間と同じ盤面を見る。
library;

import '../data/catalog.g.dart';
import 'detection.dart';
import 'game.dart';
import 'models.dart';

/// AI が選んだ 1 手。
class AiMove {
  const AiMove({
    required this.letter,
    required this.cell,
    required this.score,
  });

  final String letter;
  final Cell cell;
  final int score;

  @override
  String toString() => 'AiMove($letter → $cell, score $score)';
}

/// 1 手先までを評価する貪欲な AI。
///
/// 「今この手で何枚奪えるか」を最優先し、次に並びの長さ、
/// 最後に将来単語を作れる見込みを見る。読みの深さはないが、
/// 見えている捕獲を逃さない程度には打てる。
class SimpleAi {
  const SimpleAi();

  /// 現在の局面で最善と評価される手を返す。置ける手がなければ `null`。
  AiMove? bestMove(AzGame game) {
    final me = game.turn;
    AiMove? best;

    for (final letter in game.distinctHandOf(me)) {
      for (final cell in game.legalCells) {
        final score = _score(game, letter, cell, me);
        if (best == null || score > best.score) {
          best = AiMove(letter: letter, cell: cell, score: score);
        }
      }
    }
    return best;
  }

  /// 手番が終わるまで 1 手打つ。
  MoveResult? playTurn(AzGame game) {
    final move = bestMove(game);
    if (move == null) return null;
    return game.play(move.letter, move.cell);
  }

  int _score(AzGame game, String letter, Cell cell, Owner me) {
    final board = game.board.copy()..place(cell, Piece(letter, me));
    final formations = findFormationsAt(board, cell, me);

    var score = 0;

    // 実際に奪える枚数。盤上の駒数を競うルールなので、1 枚の捕獲は
    // 相手 −1・自分 +1 の 2 点ぶんに相当する。最優先で評価する。
    final taken = <Cell>{};
    for (final formation in formations) {
      final candidates = captureCandidates(board, formation, me)
          .where((c) => !taken.contains(c))
          .take(formation.captureLimit);
      taken.addAll(candidates);
    }
    score += taken.length * 24;

    // 並びそのものの価値。奪う相手がいなくても、長い並びは
    // 次の手で捕獲網になるため評価しておく。
    for (final formation in formations) {
      score += formation.cells.length * 5;
    }

    // 将来の見込み。この駒が縦横で自分の駒と繋がるほど、単語が伸びやすい。
    score += _adjacentOwn(board, cell, me) * 3;

    // 相手の並びの隣は危険地帯。置けば次の手で奪われうる。
    score -= _adjacentOpponentFormation(game.board, cell, me) * 8;

    // 同じ文字を複数持っているなら、余っている方から使う。
    if (game.countInHand(me, letter) > 1) score += 2;

    // 中央は縦横どちらの並びにも関与しやすい。
    score += (2 - (cell.row - 2).abs()) + (2 - (cell.col - 2).abs());

    return score;
  }

  int _adjacentOwn(Board board, Cell cell, Owner me) => cell.neighbours
      .where((neighbour) => board.at(neighbour)?.owner == me)
      .length;

  /// [cell] の隣に、相手の駒が何枚あるか。
  ///
  /// 相手の駒が固まっている場所ほど、相手が単語を成立させたときに
  /// 巻き込まれて奪われやすい。
  int _adjacentOpponentFormation(Board board, Cell cell, Owner me) =>
      cell.neighbours
          .where((neighbour) => board.at(neighbour)?.owner == me.opponent)
          .length;
}

/// 盤面を人間が読める形に整える。デバッグとログ表示に使う。
String describeBoard(Board board) {
  final buffer = StringBuffer();
  for (var row = 0; row < Board.size; row++) {
    for (var col = 0; col < Board.size; col++) {
      final piece = board.at(Cell(row, col));
      buffer.write(piece == null
          ? ' . '
          : piece.owner == Owner.first
              ? ' ${piece.letter} '
              : '(${piece.letter})');
    }
    buffer.writeln();
  }
  return buffer.toString();
}

/// 文字が母音かどうか。序盤の駒選びで参照する。
bool isVowel(String letter) => cardCatalog[letter]!.isVowel;
