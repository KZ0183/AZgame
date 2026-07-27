/// デッキの定義と検証。
library;

import '../data/catalog.g.dart';
import 'game.dart';

class DeckList {
  const DeckList({required this.name, required this.counts});

  final String name;

  /// 文字 → 枚数。
  final Map<String, int> counts;

  int get size => counts.values.fold(0, (sum, n) => sum + n);

  /// 土地の枚数。MTG と同じく、ここが最初の設計判断になる。
  int get landCount => counts.entries
      .where((e) => cardCatalog[e.key]!.isLand)
      .fold(0, (sum, e) => sum + e.value);

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

/// 標準的なマナカーブを持つ基準デッキ。土地 12 枚。
const DeckList starterDeck = DeckList(
  name: 'スターター',
  counts: {
    // 土地 12
    'A': 4, 'E': 4, 'I': 4,
    // 1 マナ 1/1
    'L': 4, 'N': 4, 'R': 2,
    // 2 マナ 2/2
    'D': 2, 'G': 2,
    // 3 マナ 3/3
    'B': 2,
    // 4 マナ 4/4
    'F': 1, 'H': 1,
  },
);
