/// タイトル画面。デッキを選んで対戦を始める。
library;

import 'package:flutter/material.dart';

import '../engine/deck.dart';
import 'battle_screen.dart';
import 'catalog_screen.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DeckList _selectedDeck = starterDecks.first;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Title(),
              const SizedBox(height: 36),
              const Text('デッキを選ぶ',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 10),
              for (final deck in starterDecks) ...[
                _DeckTile(
                  deck: deck,
                  selected: identical(deck, _selectedDeck),
                  onTap: () => setState(() => _selectedDeck = deck),
                ),
                const SizedBox(height: 8),
              ],
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: _startBattle,
                icon: const Icon(Icons.sports_kabaddi),
                label: const Text('対戦開始'),
                style: FilledButton.styleFrom(
                  backgroundColor: kWordColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const CatalogScreen()),
                ),
                icon: const Icon(Icons.menu_book_outlined),
                label: const Text('図鑑を見る'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: kTextPrimary,
                  side: const BorderSide(color: kOutline),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _startBattle() {
    // 対戦相手には、自分が選ばなかったほうのデッキを使わせる。
    final opponent = starterDecks.firstWhere(
      (deck) => !identical(deck, _selectedDeck),
      orElse: () => _selectedDeck,
    );
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => BattleScreen(
          playerDeck: _selectedDeck,
          opponentDeck: opponent,
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (final letter in ['A', 'Z'])
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: LetterCardView(letter: letter, width: 62),
              ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'AZ GAME',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w800,
            letterSpacing: 6,
          ),
        ),
        const SizedBox(height: 6),
        const Text(
          '文字を並べ、単語を紡ぎ、削り切る',
          textAlign: TextAlign.center,
          style: TextStyle(color: kTextMuted, fontSize: 13),
        ),
      ],
    );
  }
}

class _DeckTile extends StatelessWidget {
  const _DeckTile({
    required this.deck,
    required this.selected,
    required this.onTap,
  });

  final DeckList deck;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final words = deck.buildableWords();
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? kSurfaceHigh : kSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? kWordColor : kOutline,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  selected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked,
                  size: 18,
                  color: selected ? kWordColor : kTextMuted,
                ),
                const SizedBox(width: 8),
                Text(
                  deck.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const Spacer(),
                Text('${deck.size} 枚',
                    style: const TextStyle(color: kTextMuted, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              '狙えるワード ${words.length} 語: ${words.take(6).join(' · ')}',
              style: const TextStyle(
                  color: kTextMuted, fontSize: 12, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
