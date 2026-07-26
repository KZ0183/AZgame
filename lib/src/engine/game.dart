/// 対戦の進行。エンジンの入口となるクラス。
library;

import 'detection.dart';
import 'models.dart';

/// 駒を置けなかった理由。
enum MoveError {
  /// その文字を持ち駒に持っていない。
  notInHand,

  /// 指定したマスがすでに埋まっている。
  cellOccupied,

  /// すでに決着がついている。
  gameOver,
}

/// 1 手の結果。
class MoveResult {
  const MoveResult({
    required this.letter,
    required this.cell,
    required this.formations,
    required this.captured,
  });

  final String letter;
  final Cell cell;

  /// この手で成立した並び。
  final List<Formation> formations;

  /// 奪った駒（文字）。
  final List<String> captured;

  bool get scored => formations.isNotEmpty;

  @override
  String toString() => '$letter→$cell'
      '${formations.isEmpty ? "" : " ${formations.join(",")}"}'
      '${captured.isEmpty ? "" : " 捕獲:${captured.join()}"}';
}

/// 捕獲する駒を選ぶ関数。候補から [limit] 枚までを選んで返す。
typedef CaptureChooser = List<Cell> Function(
  Formation formation,
  List<Cell> candidates,
  int limit,
);

/// 既定の捕獲選択。読む順に先頭から取る。
List<Cell> takeInReadingOrder(
  Formation formation,
  List<Cell> candidates,
  int limit,
) =>
    candidates.take(limit).toList();

/// 対戦中に起きた出来事の記録。
class GameLog {
  final List<String> entries = [];

  void add(String message) => entries.add(message);

  @override
  String toString() => entries.join('\n');
}

/// 対戦を進行させるエンジン。
///
/// 乱数を一切使わない。同じ手順を再生すれば必ず同じ局面になる。
class AzGame {
  AzGame({GameLog? log}) : log = log ?? GameLog() {
    for (final owner in Owner.values) {
      _hands[owner] = [
        for (var i = 0; i < 26; i++) String.fromCharCode(65 + i),
      ];
    }
  }

  /// 手数の上限。これを超えたら盤上の駒数で決着する。
  static const int maxMoves = 24;

  final Board board = Board();
  final GameLog log;

  final Map<Owner, List<String>> _hands = {};

  /// 手番。
  Owner turn = Owner.first;

  /// これまでに指された手数。
  int moveCount = 0;

  /// [owner] の持ち駒。読み取り専用。
  List<String> handOf(Owner owner) => List<String>.unmodifiable(_hands[owner]!);

  /// [owner] が持っている文字の種類（重複を除く）。表示と探索に使う。
  List<String> distinctHandOf(Owner owner) {
    final letters = _hands[owner]!.toSet().toList()..sort();
    return letters;
  }

  /// [owner] が同じ文字を何枚持っているか。
  int countInHand(Owner owner, String letter) =>
      _hands[owner]!.where((l) => l == letter).length;

  bool _canMove(Owner owner) =>
      _hands[owner]!.isNotEmpty && !board.isFull;

  bool get isOver =>
      moveCount >= maxMoves ||
      board.isFull ||
      (!_canMove(Owner.first) && !_canMove(Owner.second));

  /// 勝者。引き分けなら `null`。
  Owner? get winner {
    if (!isOver) return null;
    final first = board.countOf(Owner.first);
    final second = board.countOf(Owner.second);
    if (first == second) return null;
    return first > second ? Owner.first : Owner.second;
  }

  /// 手番プレイヤーが置けるマス。
  List<Cell> get legalCells => board.emptyCells;

  /// [letter] を [cell] に置けるか。置けるなら `null` を返す。
  MoveError? validate(String letter, Cell cell) {
    if (isOver) return MoveError.gameOver;
    if (!_hands[turn]!.contains(letter)) return MoveError.notInHand;
    if (!board.isEmptyAt(cell)) return MoveError.cellOccupied;
    return null;
  }

  /// 手番プレイヤーが [letter] を [cell] に置く。
  ///
  /// 置いた直後に縦横の並びを判定し、成立した並びごとに、その文字数と
  /// 同じ枚数まで隣接する相手の駒を奪う。奪った駒は持ち駒に加わる。
  MoveResult play(
    String letter,
    Cell cell, {
    CaptureChooser chooser = takeInReadingOrder,
  }) {
    final error = validate(letter, cell);
    if (error != null) {
      throw StateError('$letter を $cell に置けません: $error');
    }

    final mover = turn;
    _hands[mover]!.remove(letter);
    board.place(cell, Piece(letter, mover));

    final formations = findFormationsAt(board, cell, mover);
    final captured = <String>[];
    final alreadyTaken = <Cell>{};

    for (final formation in formations) {
      final candidates = captureCandidates(board, formation, mover)
          .where((c) => !alreadyTaken.contains(c))
          .toList();
      if (candidates.isEmpty) continue;

      final chosen = chooser(formation, candidates, formation.captureLimit)
          .where(candidates.contains)
          .take(formation.captureLimit);

      for (final target in chosen) {
        final taken = board.removeAt(target);
        if (taken == null) continue;
        alreadyTaken.add(target);
        _hands[mover]!.add(taken.letter);
        captured.add(taken.letter);
      }
    }

    log.add('${mover.name}: $letter を $cell へ'
        '${formations.isEmpty ? "" : "。${formations.join("・")} 成立"}'
        '${captured.isEmpty ? "" : "。${captured.join()} を奪取"}');

    moveCount++;
    // 置ける手がない側は飛ばす。両者置けなければ isOver が真になる。
    turn = mover.opponent;
    if (!isOver && !_canMove(turn)) turn = turn.opponent;

    return MoveResult(
      letter: letter,
      cell: cell,
      formations: formations,
      captured: captured,
    );
  }
}
