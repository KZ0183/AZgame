/// ワード図鑑。成立しうる単語の一覧。
library;

import 'package:flutter/material.dart';

import '../data/catalog.g.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

/// 登録された単語だけが盤上で成立するため、この一覧が攻略情報そのものになる。
class CatalogScreen extends StatefulWidget {
  const CatalogScreen({super.key});

  @override
  State<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends State<CatalogScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final words = wordSet.where((w) => w.contains(_query.toUpperCase())).toList()
      ..sort((a, b) =>
          a.length != b.length ? a.length.compareTo(b.length) : a.compareTo(b));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSurface,
        title: Text('ワード図鑑（${wordSet.length}）'),
      ),
      body: Column(
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
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '成立した単語は、その文字数と同じ枚数だけ相手の駒を奪える。'
              'アルファベットの連番（DEF など）も同じ資格で成立する。',
              style: TextStyle(color: kTextMuted, fontSize: 12, height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 20),
              itemCount: words.length,
              itemBuilder: (context, index) {
                final word = words[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      for (final letter in word.split(''))
                        Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: HandPieceView(letter: letter, size: 34),
                        ),
                      const Spacer(),
                      Text('${word.length} 枚 奪取',
                          style: const TextStyle(
                              color: kTextMuted, fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
