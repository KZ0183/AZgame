/// 道中。敵を順に相手にし、**戦う前に相手の行動表を見てデッキを選ぶ。**
///
/// この「見てから組み替える」がこのゲームの主要な選択で、
/// カードを増やさずに遊びを増やすための唯一の軸でもある。
library;

import 'package:flutter/material.dart';

import '../data/catalog.g.dart';
import '../engine/battle.dart';
import '../engine/deck.dart';
import '../engine/enemy.dart';
import '../engine/run.dart';
import 'battle_screen.dart';
import 'theme.dart';

class RunScreen extends StatefulWidget {
  const RunScreen({super.key});

  @override
  State<RunScreen> createState() => _RunScreenState();
}

class _RunScreenState extends State<RunScreen> {
  Run _run = Run();
  Battle? _battle;
  bool? _lastResult;

  void _start(DeckList deck) {
    setState(() {
      _run.deck = deck;
      _battle = _run.begin()..start();
      _lastResult = null;
    });
  }

  void _finish(bool won) {
    setState(() => _lastResult = won);
  }

  void _next() {
    final battle = _battle!;
    setState(() {
      _run.advance(battle.playerLife);
      _battle = null;
      _lastResult = null;
    });
  }

  void _restart() {
    setState(() {
      _run = Run();
      _battle = null;
      _lastResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_run.isCleared) {
      return _EndScreen(
        title: '制 覇',
        color: kEnergyColor,
        message: '${_run.total} 体すべてを退けた。',
        onRestart: _restart,
      );
    }

    final battle = _battle;
    if (battle == null) {
      return _BriefScreen(run: _run, onStart: _start);
    }

    return Stack(
      children: [
        BattleScreen(battle: battle, onFinished: _finish),
        if (_lastResult == true)
          _Overlay(
            title: '撃 破',
            color: kEnergyColor,
            message: '残りライフ ${battle.playerLife}'
                '（次の相手の前に $kVictoryHeal 回復する）',
            actionLabel: _run.stage + 1 >= _run.total ? '結果へ' : '次の相手へ',
            onAction: _next,
          ),
        if (_lastResult == false)
          _Overlay(
            title: '敗 北',
            color: kEnemyColor,
            message: '${battle.enemy.name} に届かなかった。',
            actionLabel: '最初からやり直す',
            onAction: _restart,
          ),
      ],
    );
  }
}

/// 戦う前の画面。相手の行動表を見せ、デッキを選ばせる。
class _BriefScreen extends StatelessWidget {
  const _BriefScreen({required this.run, required this.onStart});

  final Run run;
  final void Function(DeckList) onStart;

  @override
  Widget build(BuildContext context) {
    final enemy = run.current;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: kSurface,
        title: Text('${run.stage + 1} / ${run.total} 体目'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          Row(
            children: [
              Text(enemy.glyph, style: const TextStyle(fontSize: 40)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(enemy.name,
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w800)),
                    Text('ライフ ${enemy.life}　/　こちら ${run.life}',
                        style:
                            const TextStyle(fontSize: 12, color: kTextMuted)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(enemy.flavor,
              style: const TextStyle(fontSize: 12.5, color: kTextMuted, height: 1.6)),
          const SizedBox(height: 16),
          _Section(title: '行動表（この順に繰り返す）'),
          _PatternList(enemy: enemy),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kEnergyColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline,
                    size: 16, color: kEnergyColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(enemy.lesson,
                      style: const TextStyle(fontSize: 12, height: 1.6)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _Section(title: 'デッキを選ぶ'),
          for (final deck in presetDecks) _DeckCard(deck: deck, onTap: () => onStart(deck)),
        ],
      ),
    );
  }
}

class _PatternList extends StatelessWidget {
  const _PatternList({required this.enemy});

  final EnemyDef enemy;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < enemy.pattern.length; i++)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              children: [
                SizedBox(
                  width: 26,
                  child: Text('${i + 1}',
                      style:
                          const TextStyle(fontSize: 11, color: kTextMuted)),
                ),
                Expanded(
                  child: Text(enemy.pattern[i].label(0),
                      style: const TextStyle(fontSize: 12.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DeckCard extends StatelessWidget {
  const _DeckCard({required this.deck, required this.onTap});

  final DeckList deck;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final kinds = deck.counts.keys.toList()
      ..sort((a, b) => cardCatalog[a]!.order.compareTo(cardCatalog[b]!.order));

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kOutline),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(deck.name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Text('平均 ${deck.averageCost.toStringAsFixed(1)} マナ',
                    style: const TextStyle(fontSize: 11, color: kTextMuted)),
                const Spacer(),
                const Icon(Icons.chevron_right, color: kTextMuted, size: 18),
              ],
            ),
            const SizedBox(height: 4),
            Text(deck.concept,
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final kana in kinds)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: cardColor(cardCatalog[kana]!)
                          .withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text('$kana×${deck.counts[kana]}',
                        style: const TextStyle(fontSize: 11)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(title,
          style: const TextStyle(
              fontSize: 12, fontWeight: FontWeight.w800, color: kTextMuted)),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.title,
    required this.color,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final Color color;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: kBackground.withValues(alpha: 0.92),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title,
              style: TextStyle(
                  fontSize: 46,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: color)),
          const SizedBox(height: 10),
          Text(message,
              style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
          const SizedBox(height: 24),
          FilledButton(onPressed: onAction, child: Text(actionLabel)),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('タイトルへ'),
          ),
        ],
      ),
    );
  }
}

class _EndScreen extends StatelessWidget {
  const _EndScreen({
    required this.title,
    required this.color,
    required this.message,
    required this.onRestart,
  });

  final String title;
  final Color color;
  final String message;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: TextStyle(
                    fontSize: 46,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 6,
                    color: color)),
            const SizedBox(height: 10),
            Text(message,
                style: const TextStyle(fontSize: 12.5, color: kTextMuted)),
            const SizedBox(height: 24),
            FilledButton(onPressed: onRestart, child: const Text('もう一度')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('タイトルへ'),
            ),
          ],
        ),
      ),
    );
  }
}
