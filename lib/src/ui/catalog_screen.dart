/// カード一覧。
library;

import 'package:flutter/material.dart';

import '../data/catalog.g.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cards = cardCatalog.values.toList()
      ..sort((a, b) => a.cost != b.cost
          ? a.cost.compareTo(b.cost)
          : a.rank.compareTo(b.rank));

    return Scaffold(
      appBar: AppBar(backgroundColor: kSurface, title: const Text('カード一覧')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            '26 枚すべてクリーチャーで、いまはまだ能力を持たない。'
            'コストがそのままパワーとタフネスになる。'
            'マナは毎ターン自動で増えるため、土地カードはない。',
            style: TextStyle(color: kTextMuted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final card in cards) CardView(letter: card.letter, width: 56),
            ],
          ),
        ],
      ),
    );
  }
}
