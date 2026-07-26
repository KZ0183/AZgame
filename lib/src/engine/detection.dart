/// 盤上の並びから成立した陣形を検出する。
///
/// 副作用を持たない純粋関数として実装している。
library;

import '../data/catalog.g.dart';
import 'models.dart';

/// [cell] に駒を置いた結果、[owner] のものとして成立した並びをすべて返す。
///
/// 判定するのは、置いたマスを含む縦横の並びだけ。盤全体を毎回洗い直すと、
/// 過去に成立済みの並びが何度も捕獲を起こしてしまうため。
List<Formation> findFormationsAt(Board board, Cell cell, Owner owner) {
  return [
    ..._scan(board, cell, owner, horizontal: true),
    ..._scan(board, cell, owner, horizontal: false),
  ];
}

/// 盤上に成立しているすべての並びを返す。UI の強調表示に使う。
List<Formation> findAllFormations(Board board, Owner owner) {
  final found = <Formation>[];
  final seen = <String>{};

  for (final cell in board.cellsOf(owner)) {
    for (final formation in findFormationsAt(board, cell, owner)) {
      final key = '${formation.cells.first}-${formation.text}';
      if (seen.add(key)) found.add(formation);
    }
  }
  return found;
}

List<Formation> _scan(
  Board board,
  Cell cell,
  Owner owner, {
  required bool horizontal,
}) {
  final found = <Formation>[];
  final fixed = horizontal ? cell.row : cell.col;
  final moving = horizontal ? cell.col : cell.row;

  Cell at(int index) => horizontal ? Cell(fixed, index) : Cell(index, fixed);

  for (var start = 0; start <= moving; start++) {
    for (var length = 2; length <= maxWordLength; length++) {
      final end = start + length - 1;
      if (end >= Board.size) break;
      // 置いたマスを含む並びだけが捕獲を起こす。
      if (moving < start || moving > end) continue;

      final cells = [for (var i = start; i <= end; i++) at(i)];
      final pieces = cells.map(board.at).toList();
      if (pieces.any((piece) => piece == null || piece.owner != owner)) continue;

      final text = pieces.map((piece) => piece!.letter).join();
      if (wordSet.contains(text)) {
        found.add(Formation(cells: cells, text: text, isSequence: false));
      } else if (isConsecutiveRun(text)) {
        found.add(Formation(cells: cells, text: text, isSequence: true));
      }
    }
  }

  return found;
}

/// [text] がアルファベットの連番になっているか。`Z` の次の `A` も繋がる。
bool isConsecutiveRun(String text) {
  if (text.length < 2) return false;
  for (var i = 0; i + 1 < text.length; i++) {
    if (!_followsDirectly(text[i], text[i + 1])) return false;
  }
  return true;
}

bool _followsDirectly(String a, String b) {
  if (a == 'Z' && b == 'A') return true;
  return cardCatalog[b]!.rank == cardCatalog[a]!.rank + 1;
}

/// [formation] によって奪える候補となる、相手の駒がいるマス。
///
/// 並びを構成するいずれかの駒と上下左右で隣接しているものが対象。
/// 読む順（上から下、左から右）に並べて返す。
List<Cell> captureCandidates(Board board, Formation formation, Owner owner) {
  final candidates = <Cell>{};
  for (final cell in formation.cells) {
    for (final neighbour in cell.neighbours) {
      if (board.at(neighbour)?.owner == owner.opponent) {
        candidates.add(neighbour);
      }
    }
  }
  final sorted = candidates.toList()
    ..sort((a, b) => a.row != b.row ? a.row.compareTo(b.row) : a.col.compareTo(b.col));
  return sorted;
}
