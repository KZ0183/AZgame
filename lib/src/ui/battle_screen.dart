/// 対戦画面。
library;

import 'package:flutter/material.dart';

import '../engine/ai.dart';
import '../engine/deck.dart';
import '../engine/game.dart';
import '../engine/models.dart';
import 'theme.dart';
import 'widgets/letter_card_view.dart';

/// プレイヤー（先攻）対 AI（後攻）の対戦画面。
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late Game _game;
  final Set<Permanent> _attackers = {};
  bool _aiThinking = false;
  String? _lastEvent;

  PlayerState get _me => _game.first;
  PlayerState get _foe => _game.second;
  bool get _myTurn => _game.isFirstPlayerTurn && !_aiThinking && !_game.isOver;

  @override
  void initState() {
    super.initState();
    _restart();
  }

  void _restart() {
    _game = Game(
      first: PlayerState(name: 'あなた', deck: starterDeck.toCardList()),
      second: PlayerState(name: '相手', deck: starterDeck.toCardList()),
      // 自分の防御も当面は AI に任せている。ブロック宣言 UI は今後の課題。
      firstBlocker: SimpleAi.chooseBlocks,
      secondBlocker: SimpleAi.chooseBlocks,
    )..start();
    _attackers.clear();
    _aiThinking = false;
    _lastEvent = null;
  }

  void _playCard(String letter) {
    if (!_myTurn || _game.validatePlay(letter) != null) return;
    setState(() => _game.play(letter));
  }

  void _toggleAttacker(Permanent creature) {
    if (!_myTurn || !_me.readyAttackers.contains(creature)) return;
    setState(() {
      if (!_attackers.remove(creature)) _attackers.add(creature);
    });
  }

  Future<void> _endTurn() async {
    if (!_myTurn) return;
    setState(() {
      final result = _game.attack(_attackers.toList());
      _attackers.clear();
      _lastEvent = result.totalDamage > 0
          ? '${result.totalDamage} ダメージを与えた'
          : null;
      _game.endTurn();
    });
    if (_game.isOver) return;
    await _runAiTurn();
  }

  Future<void> _runAiTurn() async {
    setState(() => _aiThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 700));
    if (!mounted) return;
    setState(() {
      final result = const SimpleAi().takeTurn(_game);
      _lastEvent = result.totalDamage > 0
          ? '相手の攻撃で ${result.totalDamage} ダメージを受けた'
          : '相手はターンを終えた';
      _game.endTurn();
      _aiThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _PlayerBar(player: _foe, color: kSecondColor, isOpponent: true),
                _buildCreatures(_foe, interactive: false),
                _buildLands(_foe),
                const Divider(color: kOutline, height: 20),
                _buildBanner(),
                const Divider(color: kOutline, height: 20),
                _buildLands(_me),
                _buildCreatures(_me, interactive: true),
                _PlayerBar(player: _me, color: kFirstColor, isOpponent: false),
                const Spacer(),
                _buildHand(),
                _buildActionBar(),
              ],
            ),
            if (_game.isOver) _buildGameOver(),
          ],
        ),
      ),
    );
  }

  Widget _buildBanner() {
    final text = _aiThinking
        ? '相手が考えています…'
        : _lastEvent ?? (_myTurn ? 'カードを出して攻撃を選ぶ' : '');
    return SizedBox(
      height: 18,
      child: Text(text,
          style: const TextStyle(color: kTextMuted, fontSize: 12)),
    );
  }

  Widget _buildCreatures(PlayerState player, {required bool interactive}) {
    if (player.creatures.isEmpty) {
      return const SizedBox(height: 62);
    }
    return SizedBox(
      height: 62,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          for (final creature in player.creatures)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: CreatureView(
                permanent: creature,
                attacking: _attackers.contains(creature),
                onTap: interactive ? () => _toggleAttacker(creature) : null,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLands(PlayerState player) {
    return SizedBox(
      height: 22,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (final land in player.lands)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2),
              child: Icon(
                Icons.eco,
                size: 15,
                color: land.tapped
                    ? kTextMuted.withValues(alpha: 0.4)
                    : const Color(0xFF4C9A5B),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHand() {
    return SizedBox(
      height: 84,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _me.hand.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final letter = _me.hand[index];
          final playable = _myTurn && _game.validatePlay(letter) == null;
          return Center(
            child: CardView(
              letter: letter,
              dimmed: !playable,
              onTap: playable ? () => _playCard(letter) : null,
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionBar() {
    final label = _attackers.isEmpty
        ? 'ターン終了'
        : '${_attackers.length} 体で攻撃してターン終了';
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Row(
        children: [
          IconButton(
            onPressed: () => _showLog(context),
            icon: const Icon(Icons.receipt_long, color: kTextMuted),
          ),
          Expanded(
            child: FilledButton(
              onPressed: _myTurn ? _endTurn : null,
              style: FilledButton.styleFrom(
                backgroundColor:
                    _attackers.isEmpty ? kOutline : kLifeColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_myTurn ? label : '相手のターン'),
            ),
          ),
          IconButton(
            onPressed: () => setState(_restart),
            icon: const Icon(Icons.refresh, color: kTextMuted),
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
    final won = _game.winner == _me;
    return Container(
      color: kBackground.withValues(alpha: 0.9),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(won ? 'WIN' : 'LOSE',
              style: TextStyle(
                  fontSize: 60,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 4,
                  color: won ? kFirstColor : kSecondColor)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => setState(_restart),
            child: const Text('もう一戦'),
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

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.player,
    required this.color,
    required this.isOpponent,
  });

  final PlayerState player;
  final Color color;
  final bool isOpponent;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
      child: Row(
        children: [
          Text(player.name, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 8),
          Icon(Icons.favorite, size: 15, color: color),
          const SizedBox(width: 3),
          Text('${player.life}',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: color)),
          const Spacer(),
          Icon(Icons.eco, size: 13, color: kTextMuted),
          const SizedBox(width: 2),
          Text('${player.availableMana}/${player.lands.length}',
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(width: 10),
          const Icon(Icons.back_hand_outlined, size: 13, color: kTextMuted),
          const SizedBox(width: 2),
          Text('${player.hand.length}',
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
          const SizedBox(width: 10),
          const Icon(Icons.style, size: 13, color: kTextMuted),
          const SizedBox(width: 2),
          Text('${player.library.length}',
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ],
      ),
    );
  }
}
