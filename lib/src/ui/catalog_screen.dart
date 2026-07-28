/// カード一覧。行ごとに並べる。
library;

import 'package:flutter/material.dart';

import '../data/catalog.g.dart';
import '../engine/models.dart';
import 'theme.dart';
import 'widgets/kana_card_view.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rows = <String, List<KanaCard>>{};
    for (final card in cardCatalog.values) {
      rows.putIfAbsent(card.row, () => []).add(card);
    }
    for (final cards in rows.values) {
      cards.sort((a, b) => a.order.compareTo(b.order));
    }

    return Scaffold(
      appBar: AppBar(backgroundColor: kSurface, title: const Text('カード一覧')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text(
            '行が種族、段がコスト。あ段が 1 マナ、お段が 5 マナ。'
            '文字を見ればコストと役割が分かるようにしてある。',
            style: TextStyle(color: kTextMuted, fontSize: 12, height: 1.6),
          ),
          const SizedBox(height: 8),
          const _KeywordLegend(),
          const SizedBox(height: 16),
          for (final entry in rows.entries) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: rowColor(entry.key),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(entry.key,
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.w800)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(kRowTraits[entry.key] ?? '',
                        style: const TextStyle(
                            fontSize: 11, color: kTextMuted)),
                  ),
                ],
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final card in entry.value)
                  CardView(kana: card.kana, width: 58),
              ],
            ),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }
}

class _KeywordLegend extends StatelessWidget {
  const _KeywordLegend();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final keyword in Keyword.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(keywordName(keyword),
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w700)),
                  ),
                  Expanded(
                    child: Text(keywordDescription(keyword),
                        style: const TextStyle(
                            fontSize: 11.5, color: kTextMuted, height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
