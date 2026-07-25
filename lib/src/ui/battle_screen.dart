/// 対戦画面。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/ai.dart';
import '../engine/deck.dart';
import '../engine/detection.dart';
import '../engine/game.dart';
import '../engine/game_state.dart';
import '../engine/models.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

/// プレイヤー対 AI の対戦画面。
///
/// プレイヤーは常に先攻側（[GameState.first]）を操作する。
class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.playerDeck,
    required this.opponentDeck,
  });

  final DeckList playerDeck;
  final DeckList opponentDeck;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late Game _game;
  String? _selected;
  bool _aiThinking = false;
  JudgementResult? _lastResult;

  PlayerState get _me => _game.state.first;
  PlayerState get _foe => _game.state.second;
  bool get _myTurn => _game.state.isFirstPlayerTurn && !_aiThinking;

  @override
  void initState() {
    super.initState();
    _startNewGame();
  }

  void _startNewGame() {
    final state = GameState(
      first: PlayerState(name: 'あなた', deck: widget.playerDeck.toCardList()),
      second: PlayerState(name: '相手', deck: widget.opponentDeck.toCardList()),
      rng: Random(),
    );
    _game = Game(
      state: state,
      firstChooser: const HeuristicChooser(),
      secondChooser: const HeuristicChooser(),
    );
    _game.start();
    _selected = null;
    _aiThinking = false;
    _lastResult = null;
  }

  void _selectCard(String letter) {
    setState(() => _selected = _selected == letter ? null : letter);
  }

  void _placeSelected(int slot) {
    final letter = _selected;
    if (letter == null || !_myTurn) return;
    if (_game.validatePlacement(letter, slot) != null) return;

    setState(() {
      _game.placeCard(letter, slot);
      // 同じ文字がまだ手札にあり、続けて置けるなら選択を維持する。
      if (!_me.hand.contains(letter) || _me.remainingPlacements <= 0) {
        _selected = null;
      }
    });
  }

  Future<void> _endTurn() async {
    if (!_myTurn) return;
    setState(() {
      _lastResult = _game.endTurn();
      _selected = null;
    });
    if (_game.state.isOver) return;
    await _runAiTurn();
  }

  Future<void> _runAiTurn() async {
    setState(() => _aiThinking = true);
    const ai = SimpleAi();

    await Future<void>.delayed(const Duration(milliseconds: 500));
    while (mounted && !_game.state.isOver) {
      final move = ai.bestMove(_game);
      if (move == null) break;
      setState(() => _game.placeCard(move.letter, move.slot));
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    if (!mounted) return;

    setState(() {
      if (!_game.state.isOver) _lastResult = _game.endTurn();
      _aiThinking = false;
    });
  }

  /// ターン終了時に何が起きるかの予告。
  ///
  /// 覚えるべきワードが 48 語あるため、盤面から「今なにが成立しているか」が
  /// 読めないと学習が進まない。予告はチュートリアルを兼ねる。
  ({WordHit? word, int sequenceDamage}) _preview(PlayerState player) {
    final sequences = findSequences(player.line)
        .where((hit) => hit.indices.any(player.slotsPlacedThisTurn.contains));
    return (
      word: findBestWord(player.line),
      sequenceDamage: sequences.fold<int>(0, (sum, hit) => sum + hit.damage),
    );
  }

  @override
  Widget build(BuildContext context) {
    final slotWidth = min(
      (MediaQuery.sizeOf(context).width - 48) / SpellLine.slotCount,
      64.0,
    );

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _StatusPanel(player: _foe, isOpponent: true),
                // 相手ライン・予告・自分ラインを均等に配置する。盤面が縦に
                // 散らばると、どちらのラインを見ているのか一瞬迷うため、
                // 3 つのまとまりとして等間隔に置く。
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLine(_foe, slotWidth * 0.82, interactive: false),
                        _buildCenterBanner(),
                        _buildLine(_me, slotWidth, interactive: true),
                      ],
                    ),
                  ),
                ),
                _StatusPanel(player: _me, isOpponent: false),
                const SizedBox(height: 6),
                _buildHand(),
                _buildActionBar(),
              ],
            ),
            if (_game.state.isOver) _buildGameOver(),
          ],
        ),
      ),
    );
  }

  Widget _buildLine(PlayerState player, double slotWidth,
      {required bool interactive}) {
    final wordHit = findBestWord(player.line);
    final wordIndices = wordHit?.indices ?? const <int>[];
    final canPlace = interactive &&
        _myTurn &&
        _selected != null &&
        _game.validatePlacement(_selected!, 0) == null;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < SpellLine.slotCount; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: SpellSlotView(
              letter: player.line[i],
              width: slotWidth,
              highlighted: canPlace,
              wordHighlighted: wordIndices.contains(i),
              onTap: interactive ? () => _placeSelected(i) : null,
            ),
          ),
      ],
    );
  }

  Widget _buildCenterBanner() {
    if (_aiThinking) {
      return const _Banner(
        icon: Icons.psychology_outlined,
        color: kTextMuted,
        text: '相手が考えています…',
      );
    }

    final preview = _preview(_me);
    final word = preview.word;
    if (word != null) {
      return _Banner(
        icon: Icons.auto_awesome,
        color: kWordColor,
        text: 'ターン終了で ${word.word.word} が発動\n${word.word.effectText}',
      );
    }
    if (preview.sequenceDamage > 0) {
      return _Banner(
        icon: Icons.trending_up,
        color: kSequenceColor,
        text: 'ターン終了でシークエンス ${preview.sequenceDamage} ダメージ',
      );
    }

    final last = _lastResult;
    if (last != null && last.hasWord) {
      return _Banner(
        icon: Icons.history,
        color: kTextMuted,
        text: '直前: ${last.word!.word.word}'
            '${last.wordNegated ? "（無効化）" : "（${last.wordDamage} ダメージ）"}',
      );
    }
    return const _Banner(
      icon: Icons.touch_app_outlined,
      color: kTextMuted,
      text: '手札を選んでマスに置く',
    );
  }

  Widget _buildHand() {
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _me.hand.length,
        separatorBuilder: (_, _) => const SizedBox(width: 6),
        itemBuilder: (context, index) {
          final letter = _me.hand[index];
          final playable =
              _myTurn && _game.validatePlacement(letter, 0) == null;
          return Center(
            child: LetterCardView(
              letter: letter,
              width: 60,
              selected: _selected == letter,
              dimmed: !playable,
              onTap: playable ? () => _selectCard(letter) : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showLog(context),
            icon: const Icon(Icons.receipt_long, color: kTextMuted),
            tooltip: 'ログ',
          ),
          Expanded(
            child: FilledButton.icon(
              onPressed: _myTurn ? _endTurn : null,
              icon: const Icon(Icons.done_all),
              label: Text(
                _myTurn
                    ? 'ターン終了（残り ${_me.remainingPlacements} 枚）'
                    : '相手のターン',
              ),
              style: FilledButton.styleFrom(
                backgroundColor: kWordColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLog(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('対戦ログ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final entry in _game.log.entries.reversed.take(60))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(entry,
                  style: const TextStyle(color: kTextMuted, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  Widget _buildGameOver() {
    final winner = _game.state.winner;
    final won = identical(winner, _me);
    return Container(
      color: kBackground.withValues(alpha: 0.88),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            won ? 'WIN' : 'LOSE',
            style: TextStyle(
              fontSize: 64,
              fontWeight: FontWeight.w800,
              color: won ? kEnergyColor : kLifeColor,
              letterSpacing: 4,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _foe.deckedOut || _me.deckedOut ? 'デッキ切れ' : 'LP 0',
            style: const TextStyle(color: kTextMuted),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => setState(_startNewGame),
            child: const Text('もう一度'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('タイトルへ'),
          ),
        ],
      ),
    );
  }
}

/// LP・シールド・エナジー・山札の状態表示。
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.player, required this.isOpponent});

  final PlayerState player;
  final bool isOpponent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      child: Row(
        children: [
          Text(
            player.name,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 10),
          _Chip(
            icon: Icons.favorite,
            color: kLifeColor,
            value: '${player.lp}',
          ),
          if (player.shield > 0) ...[
            const SizedBox(width: 6),
            _Chip(
              icon: Icons.shield,
              color: kShieldColor,
              value: '${player.shield}',
            ),
          ],
          const Spacer(),
          _Chip(
            icon: Icons.bolt,
            color: kEnergyColor,
            value: '${player.energy}/${player.maxEnergy}',
          ),
          const SizedBox(width: 6),
          _Chip(
            icon: Icons.style,
            color: kTextMuted,
            value: '${player.deck.length}',
          ),
          if (isOpponent) ...[
            const SizedBox(width: 6),
            _Chip(
              icon: Icons.back_hand_outlined,
              color: kTextMuted,
              value: '${player.hand.length}',
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.color, required this.value});

  final IconData icon;
  final Color color;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 3),
        Text(value,
            style: TextStyle(
                color: color, fontSize: 13, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              style: TextStyle(color: color, fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}
