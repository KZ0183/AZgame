/// 対戦画面。
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../engine/ai.dart';
import '../engine/detection.dart';
import '../engine/game.dart';
import '../engine/models.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

/// プレイヤー（先手）対 AI（後手）の対戦画面。
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late AzGame _game;
  String? _selected;
  bool _aiThinking = false;
  MoveResult? _lastMove;

  static const Owner _me = Owner.first;
  static const Owner _foe = Owner.second;

  bool get _myTurn => _game.turn == _me && !_aiThinking && !_game.isOver;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _game = AzGame();
    _selected = null;
    _aiThinking = false;
    _lastMove = null;
  }

  void _selectLetter(String letter) {
    setState(() => _selected = _selected == letter ? null : letter);
  }

  Future<void> _placeAt(Cell cell) async {
    final letter = _selected;
    if (letter == null || !_myTurn) return;
    if (_game.validate(letter, cell) != null) return;

    setState(() {
      _lastMove = _game.play(letter, cell);
      _selected = null;
    });
    if (_game.isOver) return;
    await _runAiTurn();
  }

  Future<void> _runAiTurn() async {
    setState(() => _aiThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    setState(() {
      if (!_game.isOver && _game.turn == _foe) {
        _lastMove = const SimpleAi().playTurn(_game);
      }
      _aiThinking = false;
    });
  }

  /// 直前の手で成立した並びのマス。
  Set<Cell> get _formationCells =>
      {for (final f in _lastMove?.formations ?? const <Formation>[]) ...f.cells};

  /// 選択中の文字を置くと並びが成立するマス。狙いどころを示す。
  Set<Cell> get _scoringCells {
    final letter = _selected;
    if (letter == null || !_myTurn) return const {};
    return {
      for (final cell in _game.legalCells)
        if (findFormationsAt(
          _game.board.copy()..place(cell, Piece(letter, _me)),
          cell,
          _me,
        ).isNotEmpty)
          cell,
    };
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final cellSize = min((width - 56) / Board.size, 62.0);
    final scoring = _scoringCells;
    final formation = _formationCells;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildScoreBar(),
                const SizedBox(height: 6),
                _buildBanner(),
                const SizedBox(height: 8),
                _buildBoard(cellSize, scoring, formation),
                const Spacer(),
                _buildHandLabel(),
                Expanded(flex: 3, child: _buildHand()),
                _buildActionBar(),
              ],
            ),
            if (_game.isOver) _buildGameOver(),
          ],
        ),
      ),
    );
  }

  Widget _buildScoreBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Row(
        children: [
          _Score(
            label: 'あなた',
            count: _game.board.countOf(_me),
            color: kFirstColor,
            hand: _game.handOf(_me).length,
          ),
          const Spacer(),
          Text(
            '${_game.moveCount} / ${AzGame.maxMoves} 手',
            style: const TextStyle(color: kTextMuted, fontSize: 12),
          ),
          const Spacer(),
          _Score(
            label: '相手',
            count: _game.board.countOf(_foe),
            color: kSecondColor,
            hand: _game.handOf(_foe).length,
          ),
        ],
      ),
    );
  }

  Widget _buildBanner() {
    if (_aiThinking) {
      return const _Banner(text: '相手が考えています…', color: kTextMuted);
    }
    final move = _lastMove;
    if (move != null && move.scored) {
      final words = move.formations.map((f) => f.text).join('・');
      return _Banner(
        text: move.captured.isEmpty
            ? '$words 成立'
            : '$words 成立 → ${move.captured.join()} を奪取',
        color: kWordColor,
      );
    }
    if (_selected != null) {
      return _Banner(
        text: '$_selected を置くマスを選ぶ（紫のマスで並びが成立）',
        color: kTextMuted,
      );
    }
    return const _Banner(text: '持ち駒から 1 枚選ぶ', color: kTextMuted);
  }

  Widget _buildBoard(double cellSize, Set<Cell> scoring, Set<Cell> formation) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: kSurface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var row = 0; row < Board.size; row++)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var col = 0; col < Board.size; col++)
                    Padding(
                      padding: const EdgeInsets.all(2),
                      child: Builder(builder: (context) {
                        final cell = Cell(row, col);
                        return BoardCellView(
                          piece: _game.board.at(cell),
                          size: cellSize,
                          highlighted: scoring.contains(cell),
                          inFormation: formation.contains(cell),
                          onTap: _myTurn ? () => _placeAt(cell) : null,
                        );
                      }),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHandLabel() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
      child: Row(
        children: [
          const Text('持ち駒',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(width: 8),
          Text('${_game.handOf(_me).length} 枚',
              style: const TextStyle(color: kTextMuted, fontSize: 12)),
        ],
      ),
    );
  }

  Widget _buildHand() {
    final letters = _game.distinctHandOf(_me);
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Wrap(
        spacing: 5,
        runSpacing: 5,
        children: [
          for (final letter in letters)
            HandPieceView(
              letter: letter,
              count: _game.countInHand(_me, letter),
              selected: _selected == letter,
              onTap: _myTurn ? () => _selectLetter(letter) : null,
            ),
        ],
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
            tooltip: '棋譜',
          ),
          Expanded(
            child: Text(
              _myTurn ? 'あなたの手番' : '相手の手番',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _myTurn ? kFirstColor : kSecondColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          IconButton(
            onPressed: () => setState(_restart),
            icon: const Icon(Icons.refresh, color: kTextMuted),
            tooltip: '最初から',
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
          const Text('棋譜',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          for (final entry in _game.log.entries.reversed)
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
    final winner = _game.winner;
    final label = winner == null
        ? 'DRAW'
        : winner == _me
            ? 'WIN'
            : 'LOSE';
    return Container(
      color: kBackground.withValues(alpha: 0.9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 60,
              fontWeight: FontWeight.w800,
              letterSpacing: 4,
              color: winner == null
                  ? kTextMuted
                  : winner == _me
                      ? kFirstColor
                      : kSecondColor,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${_game.board.countOf(_me)} 対 ${_game.board.countOf(_foe)}',
            style: const TextStyle(color: kTextMuted, fontSize: 16),
          ),
          const SizedBox(height: 28),
          FilledButton(
            onPressed: () => setState(_restart),
            child: const Text('もう一局'),
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

class _Score extends StatelessWidget {
  const _Score({
    required this.label,
    required this.count,
    required this.color,
    required this.hand,
  });

  final String label;
  final int count;
  final Color color;
  final int hand;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: kTextMuted)),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text('$count',
                style: TextStyle(
                    fontSize: 24, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(width: 4),
            Text('手駒 $hand',
                style: const TextStyle(fontSize: 11, color: kTextMuted)),
          ],
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: TextStyle(color: color, fontSize: 12.5),
      ),
    );
  }
}
