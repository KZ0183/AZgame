/// デッキの構築と検証。
library;

import '../data/catalog.g.dart';
import 'game_state.dart';

/// デッキ検証で見つかった問題。
class DeckViolation {
  const DeckViolation(this.message);
  final String message;

  @override
  String toString() => message;
}

/// デッキ 1 つぶんの定義。
///
/// カードは文字の多重集合として表現する。同じ文字のカードは互いに
/// 区別できないため、枚数だけを持てば十分。
class DeckList {
  const DeckList({required this.name, required this.counts});

  final String name;

  /// 文字 → 枚数。
  final Map<String, int> counts;

  int get size => counts.values.fold(0, (sum, n) => sum + n);

  /// 山札として使える文字の並びに展開する。順序はこの時点では未シャッフル。
  List<String> toCardList() => [
        for (final entry in counts.entries)
          for (var i = 0; i < entry.value; i++) entry.key,
      ];

  /// ルール違反を列挙する。空リストなら正当なデッキ。
  List<DeckViolation> validate() {
    final violations = <DeckViolation>[];

    if (size != kDeckSize) {
      violations.add(DeckViolation('デッキは $kDeckSize 枚でなければなりません（現在 $size 枚）'));
    }

    for (final entry in counts.entries) {
      final card = cardCatalog[entry.key];
      if (card == null) {
        violations.add(DeckViolation('未知の文字です: ${entry.key}'));
        continue;
      }
      if (entry.value < 0) {
        violations.add(DeckViolation('${entry.key} の枚数が負です'));
      }
      if (entry.value > card.deckLimit) {
        violations.add(DeckViolation(
            '${entry.key} は ${card.deckLimit} 枚までです（現在 ${entry.value} 枚）'));
      }
    }

    return violations;
  }

  bool get isValid => validate().isEmpty;

  /// このデッキで組めるコンボワードを列挙する。
  ///
  /// 必要な文字が必要な枚数だけ入っているかを判定するだけで、
  /// 実際に引ける確率までは考慮しない。デッキ編集画面の指標に使う。
  List<String> buildableWords() {
    final words = <String>[];
    for (final word in wordCatalog.keys) {
      final needed = <String, int>{};
      for (final letter in word.split('')) {
        needed[letter] = (needed[letter] ?? 0) + 1;
      }
      final ok = needed.entries
          .every((entry) => (counts[entry.key] ?? 0) >= entry.value);
      if (ok) words.add(word);
    }
    words.sort((a, b) => a.length != b.length
        ? b.length.compareTo(a.length)
        : a.compareTo(b));
    return words;
  }
}

/// 攻撃的なプリセットデッキ。`ACE` `FIRE` `ZAP` `STAR` を主軸に据える。
const DeckList starterAggro = DeckList(
  name: 'ファイアスターター',
  counts: {
    'A': 4,
    'E': 4,
    'I': 4,
    'R': 3,
    'S': 3,
    'T': 3,
    'C': 2,
    'F': 2,
    'B': 2,
    'P': 2,
    'Z': 1,
  },
);

/// 防御的なプリセットデッキ。`HEAL` `CALM` `OAK` `ICE` で耐えてから削る。
const DeckList starterControl = DeckList(
  name: 'アイスウォール',
  counts: {
    'A': 4,
    'E': 4,
    'I': 3,
    'O': 3,
    'L': 3,
    'S': 3,
    'N': 2,
    'C': 2,
    'H': 2,
    'U': 2,
    'M': 1,
    'K': 1,
  },
);

/// 同梱しているプリセットデッキの一覧。
const List<DeckList> starterDecks = [starterAggro, starterControl];
