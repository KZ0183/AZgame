/// シークエンス検出とワード検出の検査。
library;

import 'package:azgame/src/engine/detection.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `'AC_E_'` のような文字列からスペルラインを組み立てる。`_` は空マス。
SpellLine lineOf(String pattern) {
  assert(pattern.length == SpellLine.slotCount);
  return SpellLine.from([
    for (final char in pattern.split('')) char == '_' ? null : char,
  ]);
}

void main() {
  group('昇順・連番の判定', () {
    test('順位が増えていれば差が 1 でなくても昇順', () {
      expect(ascends('A', 'C'), isTrue);
      expect(ascends('C', 'A'), isFalse);
      expect(ascends('A', 'A'), isFalse);
    });

    test('Z の次の A は環状として繋がる', () {
      expect(ascends('Z', 'A'), isTrue);
      expect(isConsecutive('Z', 'A'), isTrue);
    });

    test('L はワイルドカードとして常に成立する', () {
      expect(ascends('Z', 'L'), isTrue);
      expect(ascends('L', 'A'), isTrue);
      expect(isConsecutive('Z', 'L'), isTrue);
    });

    test('連番はちょうど +1 のときのみ', () {
      expect(isConsecutive('C', 'D'), isTrue);
      expect(isConsecutive('C', 'E'), isFalse);
    });
  });

  group('シークエンス検出', () {
    test('長さ 1 はシークエンスにならない', () {
      expect(findSequences(lineOf('A____')), isEmpty);
    });

    test('空マスは連なりを断ち切る', () {
      expect(findSequences(lineOf('A_C__')), isEmpty);
    });

    test('連番はランとして扱われ、倍率が上がる', () {
      final plain = findSequences(lineOf('AC___')).single;
      final run = findSequences(lineOf('AB___')).single;
      expect(plain.isRun, isFalse);
      expect(run.isRun, isTrue);
      expect(run.multiplier, greaterThan(plain.multiplier));
    });

    test('降順が挟まると、そこで区切って次のシークエンスを探す', () {
      // A(1) C(3) B(2) D(4) → [A,C] と [B,D] の 2 本
      final hits = findSequences(lineOf('ACBD_'));
      expect(hits.length, 2);
      expect(hits[0].letters, ['A', 'C']);
      expect(hits[1].letters, ['B', 'D']);
    });

    test('5 マスすべてが連番ならラン倍率 1.5 が適用される', () {
      // A B C D E: パワー合計 2+6+6+4+2 = 20 → 20 * 1.5 = 30
      final hit = findSequences(lineOf('ABCDE')).single;
      expect(hit.length, 5);
      expect(hit.isRun, isTrue);
      expect(hit.powerSum, 20);
      expect(hit.damage, 30);
    });

    test('K はワードに含まれないときパワー +4 される', () {
      // A(2) K(10+4=14) → 昇順、長さ 2、倍率 0.25
      final hit = findSequences(lineOf('AK___')).single;
      expect(hit.powerSum, 2 + 14);
      expect(hit.damage, 4);
    });

    test('ダメージは切り捨てで計算される', () {
      // A(2) B(6) → ラン長 2、倍率 0.4 → 8 * 0.4 = 3.2 → 3
      expect(findSequences(lineOf('AB___')).single.damage, 3);
      // A(2) C(6) → 昇順長 2、倍率 0.25 → 2
      expect(findSequences(lineOf('AC___')).single.damage, 2);
    });
  });

  group('ワード検出', () {
    test('隙間なく並んだ登録ワードを検出する', () {
      final hit = findBestWord(lineOf('ACE__'));
      expect(hit, isNotNull);
      expect(hit!.word.word, 'ACE');
      expect(hit.start, 0);
    });

    test('空マスを跨ぐ並びは成立しない', () {
      expect(findBestWord(lineOf('AC_E_')), isNull);
    });

    test('先頭以外のマスから始まるワードも検出する', () {
      final hit = findBestWord(lineOf('__ICE'));
      expect(hit!.word.word, 'ICE');
      expect(hit.start, 2);
      expect(hit.indices, [2, 3, 4]);
    });

    test('複数成立する場合は最長のワードが優先される', () {
      // BLAZE の中には登録ワードが含まれないため、明示的に長短が並ぶ例を使う。
      // 'SUN' と 'SO' が同時に読める盤面はないので 'ICE' と 'ICED' 相当を検証。
      // ここでは 'STAR' (4) と 'AT' (2) が同居する 'STAR_' を使う。
      final hit = findBestWord(lineOf('STAR_'));
      expect(hit!.word.word, 'STAR');
    });

    test('登録されていない並びは成立しない', () {
      expect(findBestWord(lineOf('XQJ__')), isNull);
    });

    test('5 文字ワードは全マスを占有する', () {
      final hit = findBestWord(lineOf('BLAZE'));
      expect(hit!.word.word, 'BLAZE');
      expect(hit.indices, [0, 1, 2, 3, 4]);
    });
  });
}
