/// 戦場の並びから陣形を検出する。
///
/// 副作用を持たない純粋関数として実装している。陣形は文字を消費せず、
/// 成立している間ずっと効果が続くため、毎ターン評価し直される。
library;

import '../data/catalog.g.dart';
import 'models.dart';

/// `L`（リンク）は陣形の判定において任意の文字として扱える。
const String wildcardLetter = 'L';

/// 成立しているワード陣形。
class WordFormation {
  const WordFormation({required this.start, required this.word});

  /// 戦場上の開始レーン。
  final int start;

  final ComboWord word;

  int get length => word.length;

  /// この陣形が占有しているレーンの索引。
  List<int> get lanes => [for (var i = 0; i < length; i++) start + i];

  @override
  String toString() => 'WordFormation(${word.word} @$start)';
}

/// 成立している連番陣形。
class SequenceFormation {
  const SequenceFormation({
    required this.start,
    required this.length,
    required this.isRun,
  });

  /// 戦場上の開始レーン。
  final int start;

  /// 連なっている文字数。
  final int length;

  /// 全ステップがちょうど +1 だったか。
  final bool isRun;

  List<int> get lanes => [for (var i = 0; i < length; i++) start + i];

  /// この陣形に属する文字が得るパワー加算。
  ///
  /// 長さ n で `n - 1`、ランならさらに +1。2 連なら +1、5 連のランなら +5。
  int get powerBonus => (length - 1) + (isRun ? 1 : 0);

  @override
  String toString() =>
      'SequenceFormation(@$start x$length${isRun ? " run" : ""})';
}

/// 戦場に成立しているすべての陣形。
class Formations {
  const Formations({required this.words, required this.sequences});

  final List<WordFormation> words;
  final List<SequenceFormation> sequences;

  bool get isEmpty => words.isEmpty && sequences.isEmpty;

  int get count => words.length + sequences.length;

  /// ワード陣形の効果をすべて合算したもの。
  WordEffect get combinedWordEffect => words.fold(
        WordEffect.none,
        (merged, formation) => merged.merge(formation.word.effect),
      );

  /// 指定レーンの文字が、連番陣形から得るパワー加算。
  int sequenceBonusFor(int lane) {
    for (final sequence in sequences) {
      if (sequence.lanes.contains(lane)) return sequence.powerBonus;
    }
    return 0;
  }

  /// 指定レーンの文字が、いずれかの陣形に含まれているか。
  bool includes(int lane) =>
      words.any((w) => w.lanes.contains(lane)) ||
      sequences.any((s) => s.lanes.contains(lane));

  static const Formations empty = Formations(words: [], sequences: []);
}

/// 戦場上の [lane] にいる文字が、ワードの [expected] 文字として通用するか。
bool _matches(Battlefield field, int lane, String expected) {
  final permanent = field[lane];
  if (permanent == null) return false;
  if (permanent.letter == wildcardLetter) return true;
  return permanent.letter == expected;
}

/// 成立しているワード陣形をすべて検出する。
///
/// 隙間なく並んだ 2 文字以上が対象。重なり合う陣形も、それぞれ独立に成立する。
/// `L` はワイルドカードとして任意の文字に化ける。
List<WordFormation> findWordFormations(Battlefield field) {
  final found = <WordFormation>[];

  for (final word in wordCatalog.values) {
    for (var start = 0; start + word.length <= Battlefield.laneCount; start++) {
      var ok = true;
      for (var i = 0; i < word.length; i++) {
        if (!_matches(field, start + i, word.word[i])) {
          ok = false;
          break;
        }
      }
      if (ok) found.add(WordFormation(start: start, word: word));
    }
  }

  found.sort((a, b) =>
      a.start != b.start ? a.start.compareTo(b.start) : b.length.compareTo(a.length));
  return found;
}

/// [a] の次に [b] が来たとき、連番陣形として昇順に継続するか。
///
/// - 順位が増加していれば成立する（差は 1 でなくてよい）
/// - `Z` の次の `A` は環状として繋がる
/// - `L` はワイルドカードとして常に成立する
bool ascends(String a, String b) {
  if (a == wildcardLetter || b == wildcardLetter) return true;
  if (a == 'Z' && b == 'A') return true;
  return cardCatalog[b]!.rank > cardCatalog[a]!.rank;
}

/// [a] の次の [b] がちょうど +1 の連番か（ラン成立の条件）。
bool isConsecutive(String a, String b) {
  if (a == wildcardLetter || b == wildcardLetter) return true;
  if (a == 'Z' && b == 'A') return true;
  return cardCatalog[b]!.rank == cardCatalog[a]!.rank + 1;
}

/// 成立している連番陣形をすべて検出する。
///
/// 空きレーンは連なりを断ち切る。左から貪欲に最長の昇順連結を取る。
List<SequenceFormation> findSequenceFormations(Battlefield field) {
  final found = <SequenceFormation>[];
  var i = 0;

  while (i < Battlefield.laneCount) {
    if (field[i] == null) {
      i++;
      continue;
    }

    var end = i;
    var isRun = true;
    while (end + 1 < Battlefield.laneCount) {
      final current = field[end]!;
      final next = field[end + 1];
      if (next == null || !ascends(current.letter, next.letter)) break;
      if (!isConsecutive(current.letter, next.letter)) isRun = false;
      end++;
    }

    final length = end - i + 1;
    if (length >= 2) {
      found.add(SequenceFormation(start: i, length: length, isRun: isRun));
      i = end + 1;
    } else {
      i++;
    }
  }

  return found;
}

/// 戦場の陣形をすべて検出する。
Formations findFormations(Battlefield field) => Formations(
      words: findWordFormations(field),
      sequences: findSequenceFormations(field),
    );
