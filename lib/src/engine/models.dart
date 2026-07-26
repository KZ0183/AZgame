/// AZgame のコアデータモデル。
///
/// Flutter に依存しない純粋な Dart で書く。
library;

/// 文字の分類。v0.4 では能力を持たないため、UI の色分けと
/// デッキ構成の指標としてのみ使う。
enum LetterClass { vowel, core, heavy, rare }

/// 文字 1 種のマスターデータ。
class LetterCard {
  const LetterCard({
    required this.letter,
    required this.rank,
    required this.klass,
  });

  /// 'A' 〜 'Z'。
  final String letter;

  /// アルファベット順位 1〜26。連番の判定に使う。
  final int rank;

  final LetterClass klass;

  bool get isVowel => klass == LetterClass.vowel;

  @override
  String toString() => letter;
}

/// 対戦者。
enum Owner {
  first,
  second;

  Owner get opponent => this == first ? second : first;
}

/// 盤上のマス。行と列で表す。左上が (0, 0)。
class Cell {
  const Cell(this.row, this.col);

  final int row;
  final int col;

  bool get isValid =>
      row >= 0 && row < Board.size && col >= 0 && col < Board.size;

  /// 上下左右に隣接するマス。盤外は含まない。
  List<Cell> get neighbours => [
        for (final cell in [
          Cell(row - 1, col),
          Cell(row + 1, col),
          Cell(row, col - 1),
          Cell(row, col + 1),
        ])
          if (cell.isValid) cell,
      ];

  @override
  bool operator ==(Object other) =>
      other is Cell && other.row == row && other.col == col;

  @override
  int get hashCode => row * Board.size + col;

  @override
  String toString() => '($row,$col)';
}

/// 盤上に置かれた駒。文字と所有者を持つ。
class Piece {
  const Piece(this.letter, this.owner);

  final String letter;
  final Owner owner;

  /// 所有者だけを入れ替えた駒を返す。
  Piece capturedBy(Owner newOwner) => Piece(letter, newOwner);

  @override
  String toString() => owner == Owner.first ? letter : letter.toLowerCase();
}

/// 5×5 の盤。
class Board {
  Board() : _cells = List<Piece?>.filled(size * size, null);

  Board._(this._cells);

  /// 一辺のマス数。
  static const int size = 5;

  /// 総マス数。
  static const int cellCount = size * size;

  final List<Piece?> _cells;

  Piece? at(Cell cell) => _cells[cell.row * size + cell.col];

  Piece? operator [](Cell cell) => at(cell);

  bool isEmptyAt(Cell cell) => at(cell) == null;

  bool get isFull => _cells.every((piece) => piece != null);

  /// 空いているマス。
  List<Cell> get emptyCells => [
        for (var row = 0; row < size; row++)
          for (var col = 0; col < size; col++)
            if (_cells[row * size + col] == null) Cell(row, col),
      ];

  /// [owner] の駒がいるマス。
  List<Cell> cellsOf(Owner owner) => [
        for (var row = 0; row < size; row++)
          for (var col = 0; col < size; col++)
            if (_cells[row * size + col]?.owner == owner) Cell(row, col),
      ];

  /// [owner] の盤上の駒数。勝敗はこの値で決まる。
  int countOf(Owner owner) =>
      _cells.where((piece) => piece?.owner == owner).length;

  void place(Cell cell, Piece piece) {
    if (at(cell) != null) throw StateError('$cell はすでに埋まっています');
    _cells[cell.row * size + cell.col] = piece;
  }

  Piece? removeAt(Cell cell) {
    final removed = at(cell);
    _cells[cell.row * size + cell.col] = null;
    return removed;
  }

  Board copy() => Board._(List<Piece?>.of(_cells));

  @override
  String toString() {
    final buffer = StringBuffer();
    for (var row = 0; row < size; row++) {
      for (var col = 0; col < size; col++) {
        buffer.write(at(Cell(row, col))?.toString() ?? '.');
      }
      if (row < size - 1) buffer.write('/');
    }
    return buffer.toString();
  }
}

/// 盤上に成立した並び。単語と連番の 2 種類がある。
class Formation {
  const Formation({
    required this.cells,
    required this.text,
    required this.isSequence,
  });

  /// 構成するマス。読む順（左→右 または 上→下）に並ぶ。
  final List<Cell> cells;

  /// 成立した並びの文字列。
  final String text;

  /// 連番として成立したか。偽なら登録単語。
  final bool isSequence;

  /// 奪える駒の枚数。文字数がそのまま強さになる。
  int get captureLimit => cells.length;

  @override
  String toString() => '$text${isSequence ? "(連番)" : ""}';
}
