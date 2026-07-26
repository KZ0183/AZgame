/// 対戦画面。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../data/catalog.g.dart';
import '../engine/ai.dart';
import '../engine/board.dart';
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
  CombatResult? _lastCombat;

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
    _lastCombat = null;
  }

  void _selectCard(String letter) {
    setState(() => _selected = _selected == letter ? null : letter);
  }

  void _playAt(int lane) {
    final letter = _selected;
    if (letter == null || !_myTurn) return;
    if (_game.validatePlay(letter, lane) != null) return;

    setState(() {
      _game.playCard(letter, lane);
      // 同じ文字がまだ手札にあり、続けて出せるなら選択を維持する。
      if (!_me.hand.contains(letter) ||
          _game.validatePlay(letter, _firstEmptyLane() ?? 0) != null) {
        _selected = null;
      }
    });
  }

  int? _firstEmptyLane() {
    final empty = _me.field.emptyIndices;
    return empty.isEmpty ? null : empty.first;
  }

  Future<void> _endTurn() async {
    if (!_myTurn) return;
    setState(() {
      _lastCombat = _game.endTurn();
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
      setState(() => _game.playCard(move.letter, move.lane));
      await Future<void>.delayed(const Duration(milliseconds: 420));
    }
    if (!mounted) return;

    setState(() {
      if (!_game.state.isOver) _lastCombat = _game.endTurn();
      _aiThinking = false;
    });
  }

  /// 選択中の文字が、いずれかのレーンに出せるか。
  bool get _canPlaySelected {
    final letter = _selected;
    if (letter == null || !_myTurn) return false;
    return _me.field.emptyIndices
        .any((lane) => _game.validatePlay(letter, lane) == null);
  }

  @override
  Widget build(BuildContext context) {
    final laneWidth = min(
      (MediaQuery.sizeOf(context).width - 48) / Battlefield.laneCount,
      62.0,
    );
    final myBoard = _game.boardOf(_me);
    final foeBoard = _game.boardOf(_foe);

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _StatusPanel(player: _foe, board: foeBoard, isOpponent: true),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _buildLanes(foeBoard, laneWidth * 0.85,
                            interactive: false),
                        _FormationStrip(board: foeBoard, dimmed: true),
                        _buildCenterBanner(),
                        _FormationStrip(board: myBoard, dimmed: false),
                        _buildLanes(myBoard, laneWidth, interactive: true),
                      ],
                    ),
                  ),
                ),
                _StatusPanel(player: _me, board: myBoard, isOpponent: false),
                const SizedBox(height: 4),
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

  Widget _buildLanes(BoardView board, double laneWidth,
      {required bool interactive}) {
    final canPlace = interactive && _canPlaySelected;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var lane = 0; lane < Battlefield.laneCount; lane++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: LaneView(
              letter: board.field[lane]?.letter,
              width: laneWidth,
              power: board.powerOf(lane),
              toughness: board.toughnessOf(lane),
              damage: board.field[lane]?.damage ?? 0,
              exhausted: board.field[lane] != null && !board.canAttack(lane),
              inFormation: board.formations.includes(lane),
              highlighted: canPlace &&
                  board.field[lane] == null &&
                  _game.validatePlay(_selected!, lane) == null,
              onTap: interactive ? () => _playAt(lane) : null,
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

    final combat = _lastCombat;
    if (combat != null && combat.totalDamage > 0) {
      return _Banner(
        icon: Icons.bolt,
        color: kLifeColor,
        text: '直前の戦闘で ${combat.totalDamage} ダメージ',
      );
    }

    final letter = _selected;
    if (letter != null) {
      final card = cardCatalog[letter]!;
      return _Banner(
        icon: Icons.touch_app_outlined,
        color: classColor(card.klass),
        text: '$letter ${card.abilityName} — ${card.abilityText}',
      );
    }

    return const _Banner(
      icon: Icons.touch_app_outlined,
      color: kTextMuted,
      text: '手札を選んでレーンに出す',
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
          final playable = _myTurn &&
              _me.field.emptyIndices
                  .any((lane) => _game.validatePlay(letter, lane) == null);
          return Center(
            child: LetterCardView(
              letter: letter,
              width: 58,
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
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
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
              icon: const Icon(Icons.local_fire_department),
              label: Text(_myTurn ? '戦闘してターン終了' : '相手のターン'),
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

/// 成立している陣形の一覧。維持できているかどうかが一目で分かるようにする。
class _FormationStrip extends StatelessWidget {
  const _FormationStrip({required this.board, required this.dimmed});

  final BoardView board;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    final formations = board.formations;
    if (formations.isEmpty) return const SizedBox(height: 20);

    return SizedBox(
      height: 20,
      child: ListView(
        scrollDirection: Axis.horizontal,
        shrinkWrap: true,
        children: [
          for (final word in formations.words)
            _Chip2(
              label: word.word.word,
              color: kWordColor.withValues(alpha: dimmed ? 0.5 : 1),
            ),
          for (final sequence in formations.sequences)
            _Chip2(
              label: '連番+${sequence.powerBonus}',
              color: kSequenceColor.withValues(alpha: dimmed ? 0.5 : 1),
            ),
        ],
      ),
    );
  }
}

class _Chip2 extends StatelessWidget {
  const _Chip2({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.6)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

/// LP・シールド・エナジー・山札の状態表示。
class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.player,
    required this.board,
    required this.isOpponent,
  });

  final PlayerState player;
  final BoardView board;
  final bool isOpponent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Text(player.name,
              style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(width: 10),
          _Chip(icon: Icons.favorite, color: kLifeColor, value: '${player.lp}'),
          if (player.shield > 0) ...[
            const SizedBox(width: 6),
            _Chip(
                icon: Icons.shield,
                color: kShieldColor,
                value: '${player.shield}'),
          ],
          const Spacer(),
          _Chip(
            icon: Icons.bolt,
            color: kEnergyColor,
            value: isOpponent
                ? '${player.energyIncome}'
                : '${player.energy} (+${player.energyIncome})',
          ),
          const SizedBox(width: 6),
          _Chip(
              icon: Icons.style, color: kTextMuted, value: '${player.deck.length}'),
          if (isOpponent) ...[
            const SizedBox(width: 6),
            _Chip(
                icon: Icons.back_hand_outlined,
                color: kTextMuted,
                value: '${player.hand.length}'),
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
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              text,
              textAlign: TextAlign.center,
              maxLines: 3,
              style: TextStyle(color: color, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// 陣形の検出をこの画面から直接使えるようにするための別名。
Formations formationsOfField(Battlefield field) => findFormations(field);
