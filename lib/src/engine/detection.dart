/// スペルライン上の判定処理。シークエンス検出とワード検出。
///
/// どちらも副作用を持たない純粋関数として実装しており、盤面を渡せば
/// 検出結果が返る。実際の効果適用は [resolveJudgement] 側の責務。
library;

import '../data/catalog.g.dart';
import 'models.dart';

/// シークエンス長ごとの倍率。索引は長さ（2〜5）。
///
/// docs/game-design.md 6.1 の表に対応する。
const Map<int, double> sequenceMultiplier = {
  2: 1.0,
  3: 1.5,
  4: 2.0,
  5: 3.0,
};

/// 全ステップが連番だった場合（ラン）の倍率。
const Map<int, double> runMultiplier = {
  2: 1.5,
  3: 2.5,
  4: 4.0,
  5: 6.0,
};

/// ワイルドカードとして振る舞う文字。
///
/// `L`（リンク）はシークエンス判定において順位を任意の値として扱えるため、
/// 昇順判定・連番判定の両方で常に成立する。
const String linkLetter = 'L';

/// 検出された 1 本のシークエンス。
class SequenceHit {
  const SequenceHit({
    required this.start,
    required this.letters,
    required this.isRun,
    required this.powerSum,
    required this.damage,
  });

  /// スペルライン上の開始マス索引。
  final int start;

  /// 構成する文字（左から右の順）。
  final List<String> letters;

  /// 全ステップがちょうど +1 だったか（ラン成立）。
  final bool isRun;

  /// 構成カードのパワー合計。
  final int powerSum;

  /// このシークエンスが与えるダメージ。
  final int damage;

  int get length => letters.length;

  double get multiplier =>
      (isRun ? runMultiplier[length] : sequenceMultiplier[length]) ?? 1.0;

  @override
  String toString() =>
      'SequenceHit(${letters.join()}, run: $isRun, dmg: $damage)';
}

/// 検出されたワード。
class WordHit {
  const WordHit({
    required this.start,
    required this.word,
  });

  /// スペルライン上の開始マス索引。
  final int start;

  /// 成立したワード。
  final ComboWord word;

  int get length => word.length;

  /// このワードが占有しているマスの索引一覧。
  List<int> get indices => [for (var i = 0; i < length; i++) start + i];

  @override
  String toString() => 'WordHit(${word.word} @$start)';
}

/// `K`（ナイト）がワードに含まれていないときのパワー加算量。
const int kKnightSoloBonus = 4;

/// 状況を加味した実効パワー。
///
/// `K` は「ワードに含まれていない間、パワー+4」という passive を持つため、
/// シークエンスダメージでは加算され、ワード威力の計算では加算されない。
int effectivePower(String letter, {required bool inWord}) {
  final base = cardCatalog[letter]!.power;
  if (letter == 'K' && !inWord) return base + kKnightSoloBonus;
  return base;
}

/// [a] の次に [b] を置いたとき、シークエンスが昇順として継続するか。
///
/// - 通常は順位が増加していれば成立する（差は 1 でなくてよい）
/// - `Z` の次の `A` は環状として繋がる
/// - `L` はワイルドカードとして常に成立する
bool ascends(String a, String b) {
  if (a == linkLetter || b == linkLetter) return true;
  if (a == 'Z' && b == 'A') return true;
  return cardCatalog[b]!.rank > cardCatalog[a]!.rank;
}

/// [a] の次の [b] がちょうど +1 の連番か（ラン成立の条件）。
bool isConsecutive(String a, String b) {
  if (a == linkLetter || b == linkLetter) return true;
  if (a == 'Z' && b == 'A') return true;
  return cardCatalog[b]!.rank == cardCatalog[a]!.rank + 1;
}

/// スペルライン上のシークエンスをすべて検出する。
///
/// 空マスは連なりを断ち切る。左から貪欲に最長の昇順連結を取り、
/// 取り切ったら次のマスから再開する。長さ 1 はシークエンスにならない。
List<SequenceHit> findSequences(SpellLine line) {
  final hits = <SequenceHit>[];
  var i = 0;

  while (i < SpellLine.slotCount) {
    final head = line[i];
    if (head == null) {
      i++;
      continue;
    }

    var end = i;
    var isRun = true;
    while (end + 1 < SpellLine.slotCount) {
      final current = line[end]!;
      final next = line[end + 1];
      if (next == null || !ascends(current, next)) break;
      if (!isConsecutive(current, next)) isRun = false;
      end++;
    }

    final length = end - i + 1;
    if (length >= 2) {
      final letters = [for (var k = i; k <= end; k++) line[k]!];
      final powerSum = letters.fold<int>(
        0,
        (sum, l) => sum + effectivePower(l, inWord: false),
      );
      final multiplier =
          (isRun ? runMultiplier[length] : sequenceMultiplier[length]) ?? 1.0;
      hits.add(SequenceHit(
        start: i,
        letters: letters,
        isRun: isRun,
        powerSum: powerSum,
        damage: (powerSum * multiplier).floor(),
      ));
      i = end + 1;
    } else {
      i++;
    }
  }

  return hits;
}

/// スペルライン上で成立する最良のワードを 1 つ返す。成立しなければ `null`。
///
/// 隙間なく並んだ 2 文字以上の並びのみが対象。複数成立する場合は
/// 最長のワードが優先され、同長なら左にあるものが優先される。
WordHit? findBestWord(SpellLine line) {
  WordHit? best;

  for (var start = 0; start < SpellLine.slotCount; start++) {
    if (line[start] == null) continue;

    final buffer = StringBuffer();
    for (var end = start; end < SpellLine.slotCount; end++) {
      final letter = line[end];
      if (letter == null) break;
      buffer.write(letter);
      if (buffer.length < 2) continue;
      if (buffer.length > maxWordLength) break;

      final word = wordCatalog[buffer.toString()];
      if (word == null) continue;
      if (best == null || word.length > best.length) {
        best = WordHit(start: start, word: word);
      }
    }
  }

  return best;
}
