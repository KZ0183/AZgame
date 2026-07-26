/// タイトル画面。
library;

import 'package:flutter/material.dart';

import 'battle_screen.dart';
import 'catalog_screen.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

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
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    HandPieceView(letter: 'A', size: 56),
                    SizedBox(width: 8),
                    HandPieceView(letter: 'Z', size: 56),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'AZ GAME',
                  style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 6),
                ),
                const SizedBox(height: 8),
                const Text(
                  '同じ 26 文字を、置く場所だけで戦う',
                  style: TextStyle(color: kTextMuted, fontSize: 13),
                ),
                const SizedBox(height: 32),
                const _Rules(),
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => const BattleScreen()),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: kWordColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      textStyle: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    child: const Text('対戦開始'),
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
                    child: const Text('ワード図鑑'),
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
      '両者が A〜Z を 1 枚ずつ持ち、交互に 5×5 の盤へ置く',
      '縦か横に自分の駒だけで単語か連番が並ぶと成立',
      '成立した文字数ぶんだけ、隣接する相手の駒を奪える',
      '奪った駒は自分の持ち駒になる',
      '24 手を終えた時点で、盤上の駒が多い方の勝ち',
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
