/// v0.4 エンジンの検査。
library;

import 'package:azgame/src/data/catalog.g.dart';
import 'package:azgame/src/engine/ai.dart';
import 'package:azgame/src/engine/detection.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `'FIRE.'` のような行文字列から盤を組む。大文字は先手、小文字は後手、`.` は空。
Board boardOf(List<String> rows) {
  final board = Board();
  for (var row = 0; row < rows.length; row++) {
    for (var col = 0; col < rows[row].length; col++) {
      final char = rows[row][col];
      if (char == '.') continue;
      final owner = char == char.toUpperCase() ? Owner.first : Owner.second;
      board.place(Cell(row, col), Piece(char.toUpperCase(), owner));
    }
  }
  return board;
}

void main() {
  group('カタログ', () {
    test('A〜Z の 26 種がそろい、順位が一致する', () {
      expect(cardCatalog.length, 26);
      for (final entry in cardCatalog.entries) {
        expect(entry.value.rank, entry.key.codeUnitAt(0) - 64);
      }
    });

    test('単語はすべて大文字 2〜5 文字', () {
      for (final word in wordSet) {
        expect(word, matches(RegExp(r'^[A-Z]{2,5}$')));
      }
      expect(maxWordLength, lessThanOrEqualTo(Board.size));
    });
  });

  group('単語の成立', () {
    test('横に並んだ登録単語が成立する', () {
      final board = boardOf(['ACE..', '.....', '.....', '.....', '.....']);
      final formations = findFormationsAt(board, const Cell(0, 2), Owner.first);
      expect(formations.map((f) => f.text), contains('ACE'));
    });

    test('縦に並んだ登録単語が成立する', () {
      final board = boardOf(['F....', 'I....', 'R....', 'E....', '.....']);
      final formations = findFormationsAt(board, const Cell(3, 0), Owner.first);
      expect(formations.map((f) => f.text), contains('FIRE'));
    });

    test('相手の駒が混じった並びは成立しない', () {
      final board = boardOf(['AcE..', '.....', '.....', '.....', '.....']);
      expect(findFormationsAt(board, const Cell(0, 2), Owner.first), isEmpty);
    });

    test('置いたマスを含まない並びは検出されない', () {
      // ACE は成立しているが、判定するのは (0,4) を含む並びだけ。
      final board = boardOf(['ACE.Z', '.....', '.....', '.....', '.....']);
      expect(findFormationsAt(board, const Cell(0, 4), Owner.first), isEmpty);
    });

    test('縦と横で同時に成立しうる', () {
      // (0,0) に A を置くと、横 AT と縦 AI が同時に成立する。
      final board = boardOf(['AT...', 'I....', 'R....', '.....', '.....']);
      final formations = findFormationsAt(board, const Cell(0, 0), Owner.first);
      expect(formations.map((f) => f.text), containsAll(['AT', 'AIR']));
    });

    test('連番も単語と同じ資格で成立する', () {
      final board = boardOf(['DEF..', '.....', '.....', '.....', '.....']);
      final formations = findFormationsAt(board, const Cell(0, 2), Owner.first);
      final def = formations.firstWhere((f) => f.text == 'DEF');
      expect(def.isSequence, isTrue);
      expect(def.captureLimit, 3);
    });

    test('Z の次の A も連番として繋がる', () {
      expect(isConsecutiveRun('ZA'), isTrue);
      expect(isConsecutiveRun('ZB'), isFalse);
      expect(isConsecutiveRun('ACE'), isFalse);
    });

    test('捕獲できる枚数は並びの文字数に等しい', () {
      final board = boardOf(['ACE..', '.....', '.....', '.....', '.....']);
      final ace =
          findFormationsAt(board, const Cell(0, 2), Owner.first).first;
      expect(ace.captureLimit, 3);
    });
  });

  group('捕獲', () {
    test('並びに隣接する相手の駒だけが候補になる', () {
      final board = boardOf(['ACE..', 'xy..z', '.....', '.....', '.....']);
      final ace = findFormationsAt(board, const Cell(0, 2), Owner.first)
          .firstWhere((f) => f.text == 'ACE');
      final candidates = captureCandidates(board, ace, Owner.first);
      // (1,0) と (1,1) は隣接、(1,4) は離れている
      expect(candidates, containsAll([const Cell(1, 0), const Cell(1, 1)]));
      expect(candidates, isNot(contains(const Cell(1, 4))));
    });

    test('奪った駒は自分の持ち駒になり、盤から消える', () {
      final game = AzGame();
      game.play('A', const Cell(0, 0)); // 先手
      game.play('X', const Cell(1, 0)); // 後手。A の真下
      game.play('C', const Cell(0, 1)); // 先手
      game.play('Q', const Cell(4, 4)); // 後手。無関係な場所
      final result = game.play('E', const Cell(0, 2)); // ACE 成立

      expect(result.formations.map((f) => f.text), contains('ACE'));
      expect(result.captured, contains('X'));
      expect(game.board.at(const Cell(1, 0)), isNull);
      expect(game.handOf(Owner.first), contains('X'));
    });

    test('奪える枚数は並びの文字数までに制限される', () {
      final game = AzGame();
      // 2 文字の AT を作り、隣接する相手の駒が 3 枚ある状況にする。
      game.play('A', const Cell(0, 0));
      game.play('X', const Cell(1, 0));
      game.play('Z', const Cell(4, 4)); // 先手の捨て手
      game.play('Q', const Cell(1, 1));
      game.play('B', const Cell(3, 3)); // 先手の捨て手
      game.play('J', const Cell(0, 2));

      final result = game.play('T', const Cell(0, 1)); // AT 成立（2 文字）
      expect(result.formations.map((f) => f.text), contains('AT'));
      expect(result.captured.length, lessThanOrEqualTo(2));
    });
  });

  group('対戦の進行', () {
    test('最初は両者が A〜Z を 1 枚ずつ持つ', () {
      final game = AzGame();
      for (final owner in Owner.values) {
        expect(game.handOf(owner).length, 26);
        expect(game.handOf(owner).toSet().length, 26);
      }
    });

    test('置いた駒は持ち駒から消える', () {
      final game = AzGame();
      game.play('E', const Cell(2, 2));
      expect(game.handOf(Owner.first).contains('E'), isFalse);
      expect(game.board.at(const Cell(2, 2))!.letter, 'E');
    });

    test('持っていない文字は置けない', () {
      final game = AzGame();
      game.play('E', const Cell(0, 0));
      game.play('E', const Cell(1, 1)); // 後手の E
      expect(game.validate('E', const Cell(2, 2)), MoveError.notInHand);
    });

    test('埋まっているマスには置けない', () {
      final game = AzGame();
      game.play('E', const Cell(0, 0));
      expect(game.validate('A', const Cell(0, 0)), MoveError.cellOccupied);
    });

    test('手番は交互に移る', () {
      final game = AzGame();
      expect(game.turn, Owner.first);
      game.play('A', const Cell(0, 0));
      expect(game.turn, Owner.second);
      game.play('B', const Cell(1, 1));
      expect(game.turn, Owner.first);
    });

    test('手数の上限で終了し、盤上の駒が多い方が勝つ', () {
      final game = AzGame();
      const ai = SimpleAi();
      while (!game.isOver) {
        expect(ai.playTurn(game), isNotNull);
      }
      expect(game.moveCount, lessThanOrEqualTo(AzGame.maxMoves));

      final first = game.board.countOf(Owner.first);
      final second = game.board.countOf(Owner.second);
      if (first == second) {
        expect(game.winner, isNull);
      } else {
        expect(game.winner, first > second ? Owner.first : Owner.second);
      }
    });

    test('運の要素がなく、同じ手順は必ず同じ局面になる', () {
      String replay() {
        final game = AzGame();
        const ai = SimpleAi();
        while (!game.isOver) {
          ai.playTurn(game);
        }
        return game.board.toString();
      }

      expect(replay(), replay());
    });
  });

  group('AI', () {
    test('奪える手があれば必ず取りに行く', () {
      final game = AzGame();
      game.play('A', const Cell(0, 0));
      game.play('X', const Cell(1, 0)); // A の真下に置いてしまった
      game.play('C', const Cell(0, 1));
      game.play('Q', const Cell(4, 4));

      final move = const SimpleAi().bestMove(game);
      expect(move, isNotNull);
      // ACE を完成させて X を奪うのが最善
      expect(move!.letter, 'E');
      expect(move.cell, const Cell(0, 2));
    });

    test('盤が埋まるまで打ち続けても壊れない', () {
      final game = AzGame();
      const ai = SimpleAi();
      var guard = 0;
      while (!game.isOver && guard++ < 100) {
        ai.playTurn(game);
        expect(game.board.countOf(Owner.first) +
            game.board.countOf(Owner.second), lessThanOrEqualTo(Board.cellCount));
      }
      expect(game.isOver, isTrue);
    });
  });
}
