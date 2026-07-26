/// カード図鑑とワード図鑑。
///
/// 成立するワードは登録された 48 語だけなので、この一覧がゲームの
/// 攻略情報そのものになる。いつでも引けることが前提のルール設計
/// （docs/game-design.md 1.3）なので、対戦中からも開けるようにしたい。
library;

import 'package:flutter/material.dart';

import '../data/catalog.g.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

class CatalogScreen extends StatelessWidget {
  const CatalogScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: kSurface,
          title: const Text('図鑑'),
          bottom: const TabBar(
            indicatorColor: kWordColor,
            tabs: [
              Tab(text: 'カード（26）'),
              Tab(text: 'ワード（48）'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_CardList(), _WordList()],
        ),
      ),
    );
  }
}

class _CardList extends StatelessWidget {
  const _CardList();

  @override
  Widget build(BuildContext context) {
    final cards = cardCatalog.values.toList()
      ..sort((a, b) => a.rank.compareTo(b.rank));

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: cards.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final card = cards[index];
        return Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: kSurface,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LetterCardView(letter: card.letter, width: 52),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          card.abilityName,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        const SizedBox(width: 8),
                        _Tag(
                          label: classLabel(card.klass),
                          color: classColor(card.klass),
                        ),
                        const SizedBox(width: 4),
                        _Tag(
                          label: card.isVowel
                              ? 'マナ +${card.energyProduced}'
                              : 'コスト ${card.cost}',
                          color: kEnergyColor,
                        ),
                        const SizedBox(width: 4),
                        _Tag(
                          label: '${card.power}/${card.toughness}',
                          color: kTextMuted,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      card.abilityText,
                      style: const TextStyle(
                          color: kTextMuted, fontSize: 12.5, height: 1.5),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WordList extends StatefulWidget {
  const _WordList();

  @override
  State<_WordList> createState() => _WordListState();
}

class _WordListState extends State<_WordList> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final words = wordCatalog.values
        .where((w) => w.word.contains(_query.toUpperCase()))
        .toList()
      ..sort((a, b) =>
          a.length != b.length ? a.length.compareTo(b.length) : a.word.compareTo(b.word));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            onChanged: (value) => setState(() => _query = value),
            decoration: InputDecoration(
              hintText: '文字で絞り込む（例: Z）',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: kSurface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            itemCount: words.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final word = words[index];
              return Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: kSurface,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: [
                            for (final letter in word.word.split(''))
                              Padding(
                                padding: const EdgeInsets.only(right: 3),
                                child: LetterCardView(
                                  letter: letter,
                                  width: 26,
                                  showStats: false,
                                ),
                              ),
                          ],
                        ),
                        const Spacer(),
                        _Tag(label: '${word.length} 文字', color: kTextMuted),
                      ],
                    ),
                    ...[
                      const SizedBox(height: 8),
                      Text(
                        word.text,
                        style: const TextStyle(
                            color: kTextMuted, fontSize: 12.5, height: 1.5),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10.5, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
