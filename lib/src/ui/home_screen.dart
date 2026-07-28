/// タイトル画面。
library;

import 'package:flutter/material.dart';

import 'catalog_screen.dart';
import 'run_screen.dart';
import 'theme.dart';
import 'widgets/kana_card_view.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CardView(kana: 'あ', width: 52),
                    SizedBox(width: 8),
                    CardView(kana: 'ん', width: 52),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'かな戦記',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 8),
                ),
                const SizedBox(height: 8),
                const Text(
                  'あ〜ん の 46 枚で、敵を順に退ける',
                  style: TextStyle(color: kTextMuted, fontSize: 13),
                ),
                const SizedBox(height: 28),
                const _Rules(),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const RunScreen()),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: kAccentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('道中を始める'),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const CatalogScreen()),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: kTextPrimary,
                      side: const BorderSide(color: kOutline),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('カード一覧'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Rules extends StatelessWidget {
  const _Rules();

  @override
  Widget build(BuildContext context) {
    const rules = [
      'カードを使うのはこちらだけ。相手は決まった行動表をなぞる敵',
      '敵の次の一手は常に見えている。運ではなく段取りで解く',
      '行が種族、段がコスト。「か行は突撃」「た行は挑発」',
      'マナは毎ターン自動で 1 増える。土地を置く操作はない',
      'ミニオンをタップ → 攻撃相手をタップ。ブロックはない',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final rule in rules)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('・', style: TextStyle(color: kTextMuted)),
                  Expanded(
                    child: Text(rule,
                        style: const TextStyle(fontSize: 12.5, height: 1.5)),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
