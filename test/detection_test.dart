/// 陣形の検出の検査。
library;

import 'package:azgame/src/engine/detection.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

/// `'AC_E_'` のような文字列から戦場を組み立てる。`_` は空レーン。
Battlefield fieldOf(String pattern) {
  assert(pattern.length == Battlefield.laneCount);
  return Battlefield.from([
    for (final char in pattern.split(''))
      char == '_' ? null : Permanent(char),
  ]);
}

void main() {
  group('ワード陣形', () {
    test('隙間なく並んだ登録ワードを検出する', () {
      final formations = findWordFormations(fieldOf('ACE__'));
      expect(formations.map((f) => f.word.word), contains('ACE'));
      expect(formations.first.lanes, [0, 1, 2]);
    });

    test('空レーンを跨ぐ並びは成立しない', () {
      expect(findWordFormations(fieldOf('AC_E_')), isEmpty);
    });

    test('先頭以外のレーンから始まるワードも検出する', () {
      final formations = findWordFormations(fieldOf('__ICE'));
      final ice = formations.firstWhere((f) => f.word.word == 'ICE');
      expect(ice.start, 2);
      expect(ice.lanes, [2, 3, 4]);
    });

    test('重なり合う複数の陣形が同時に成立する', () {
      // ON と NO が同居する並び。どちらも独立に有効。
      final formations = findWordFormations(fieldOf('ONO__'));
      expect(formations.map((f) => f.word.word), containsAll(['ON', 'NO']));
    });

    test('L はワイルドカードとして任意の文字に化ける', () {
      // A L E → ACE として成立する
      final formations = findWordFormations(fieldOf('ALE__'));
      expect(formations.map((f) => f.word.word), contains('ACE'));
    });

    test('登録されていない並びは成立しない', () {
      expect(findWordFormations(fieldOf('XQJ__')), isEmpty);
    });

    test('複数の陣形の効果は合算される', () {
      final formations = findFormations(fieldOf('ONO__'));
      final merged = formations.combinedWordEffect;
      // ON は毎ターンエナジー+1、NO は相手 1 体を拘束
      expect(merged.upkeepEnergy, greaterThan(0));
      expect(merged.freeze, greaterThan(0));
    });
  });

  group('連番陣形', () {
    test('長さ 1 は陣形にならない', () {
      expect(findSequenceFormations(fieldOf('A____')), isEmpty);
    });

    test('空レーンは連なりを断ち切る', () {
      expect(findSequenceFormations(fieldOf('A_C__')), isEmpty);
    });

    test('昇順なら差が 1 でなくても成立する', () {
      final sequence = findSequenceFormations(fieldOf('AC___')).single;
      expect(sequence.length, 2);
      expect(sequence.isRun, isFalse);
      expect(sequence.powerBonus, 1);
    });

    test('連番はランとして扱われ、加算が 1 増える', () {
      final sequence = findSequenceFormations(fieldOf('AB___')).single;
      expect(sequence.isRun, isTrue);
      expect(sequence.powerBonus, 2);
    });

    test('5 レーンすべてが連番ならパワー+5', () {
      final sequence = findSequenceFormations(fieldOf('ABCDE')).single;
      expect(sequence.length, 5);
      expect(sequence.isRun, isTrue);
      expect(sequence.powerBonus, 5);
    });

    test('降順が挟まると、そこで区切って次を探す', () {
      final sequences = findSequenceFormations(fieldOf('ACBD_'));
      expect(sequences.length, 2);
      expect(sequences[0].lanes, [0, 1]);
      expect(sequences[1].lanes, [2, 3]);
    });

    test('Z の次の A は環状として繋がる', () {
      expect(ascends('Z', 'A'), isTrue);
      expect(isConsecutive('Z', 'A'), isTrue);
    });

    test('L はワイルドカードとして常に繋がる', () {
      expect(ascends('Z', 'L'), isTrue);
      expect(isConsecutive('L', 'A'), isTrue);
    });
  });

  group('陣形の集合', () {
    test('指定レーンが陣形に含まれるかを判定できる', () {
      final formations = findFormations(fieldOf('ACE__'));
      expect(formations.includes(0), isTrue);
      expect(formations.includes(4), isFalse);
    });

    test('連番の加算はその陣形に属するレーンだけに効く', () {
      final formations = findFormations(fieldOf('AB___'));
      expect(formations.sequenceBonusFor(0), 2);
      expect(formations.sequenceBonusFor(4), 0);
    });
  });
}
