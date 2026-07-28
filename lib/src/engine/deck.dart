/// デッキの定義と検証。
library;

import '../data/catalog.g.dart';
import 'game.dart';

class DeckList {
  const DeckList({required this.name, required this.counts});

  final String name;
  final Map<String, int> counts;

  int get size => counts.values.fold(0, (sum, n) => sum + n);

  /// 平均コスト。デッキの重さの指標になる。
  double get averageCost => counts.entries
          .fold<int>(0, (sum, e) => sum + cardCatalog[e.key]!.cost * e.value) /
      size;

  List<String> toCardList() => [
        for (final entry in counts.entries)
          for (var i = 0; i < entry.value; i++) entry.key,
      ];

  List<String> validate() {
    final problems = <String>[];
    if (size != kDeckSize) problems.add('デッキは $kDeckSize 枚（現在 $size 枚）');
    for (final entry in counts.entries) {
      final card = cardCatalog[entry.key];
      if (card == null) {
        problems.add('未知の文字: ${entry.key}');
        continue;
      }
      if (entry.value > card.deckLimit) {
        problems.add('${entry.key} は ${card.deckLimit} 枚まで（現在 ${entry.value} 枚）');
      }
    }
    return problems;
  }

  bool get isValid => validate().isEmpty;
}

/// 素直なマナカーブの基準デッキ。
const DeckList starterDeck = DeckList(
  name: 'スターター',
  counts: {
    // 1 マナ
    'A': 4, 'E': 4,
    // 2 マナ
    'N': 4, 'O': 4,
    // 3 マナ
    'U': 3, 'D': 3,
    // 4 マナ
    'M': 3, 'P': 2,
    // 5 マナ
    'V': 2,
    // 7 マナ
    'X': 1,
  },
);
