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
///
/// 操作は「手札をタップして出す」「自分のクリーチャーをタップ →
/// 攻撃対象をタップ」の 2 つだけ。ブロックも土地もない。
class BattleScreen extends StatefulWidget {
  const BattleScreen({super.key});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  late Game _game;
  Permanent? _selectedAttacker;
  bool _aiThinking = false;
  String? _message;

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
    )..start();
    _selectedAttacker = null;
    _aiThinking = false;
    _message = null;
  }

  void _playCard(String letter) {
    if (_game.validatePlay(letter) != null) return;
    setState(() => _game.play(letter));
  }

  void _selectAttacker(Permanent creature) {
    if (_game.validateAttack(creature) != null) return;
    setState(() => _selectedAttacker =
        _selectedAttacker == creature ? null : creature);
  }

  /// 攻撃対象を指定して解決する。[target] が `null` なら本体を殴る。
  void _resolveAttack(Permanent? target) {
    final attacker = _selectedAttacker;
    if (attacker == null || !_myTurn) return;
    setState(() {
      final result = _game.attack(attacker, target);
      _message = result.target == null
          ? '本体に ${result.damageToPlayer} ダメージ'
          : '${result.attacker} で ${result.target} を攻撃';
      _selectedAttacker = null;
    });
  }

  Future<void> _endTurn() async {
    if (!_myTurn) return;
    setState(() {
      _selectedAttacker = null;
      _game.endTurn();
    });
    if (_game.isOver) return;

    setState(() => _aiThinking = true);
    await Future<void>.delayed(const Duration(milliseconds: 650));
    if (!mounted) return;
    setState(() {
      final before = _me.life;
      const SimpleAi().takeTurn(_game);
      final taken = before - _me.life;
      _message = taken > 0 ? '相手の攻撃で $taken ダメージ' : '相手はターンを終えた';
      _game.endTurn();
      _aiThinking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final attacking = _selectedAttacker != null;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _PlayerBar(
                  player: _foe,
                  color: kSecondColor,
                  targetable: attacking,
                  onTap: attacking ? () => _resolveAttack(null) : null,
                ),
                _buildCreatures(_foe, isOpponent: true, targetable: attacking),
                const Spacer(),
                _buildMessage(),
                const Spacer(),
                _buildCreatures(_me, isOpponent: false, targetable: false),
                _PlayerBar(player: _me, color: kFirstColor),
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

  Widget _buildMessage() {
    final text = _aiThinking
        ? '相手のターン…'
        : _selectedAttacker != null
            ? '攻撃する相手をタップ（相手の名前をタップで本体を殴る）'
            : _message ?? 'カードを出して、クリーチャーをタップして攻撃';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(text,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: _selectedAttacker != null ? kLifeColor : kTextMuted,
            fontSize: 12.5,
          )),
    );
  }

  Widget _buildCreatures(
    PlayerState player, {
    required bool isOpponent,
    required bool targetable,
  }) {
    return SizedBox(
      height: 74,
      child: player.creatures.isEmpty
          ? Center(
              child: Text(isOpponent ? '相手の場は空' : '自分の場は空',
                  style: const TextStyle(color: kTextMuted, fontSize: 11)))
          : ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final creature in player.creatures)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: CreatureView(
                      permanent: creature,
                      width: 54,
                      selected: _selectedAttacker == creature,
                      targetable: targetable,
                      canAct: !isOpponent &&
                          _myTurn &&
                          _game.validateAttack(creature) == null,
                      onTap: isOpponent
                          ? (targetable ? () => _resolveAttack(creature) : null)
                          : (_myTurn ? () => _selectAttacker(creature) : null),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _buildHand() {
    return SizedBox(
      height: 86,
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
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
                backgroundColor: kWordColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_myTurn ? 'ターン終了' : '相手のターン'),
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
              child: const Text('もう一戦')),
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('タイトルへ')),
        ],
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({
    required this.player,
    required this.color,
    this.targetable = false,
    this.onTap,
  });

  final PlayerState player;
  final Color color;

  /// 攻撃対象として選べる状態か。
  final bool targetable;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: targetable ? kLifeColor.withValues(alpha: 0.16) : null,
          borderRadius: BorderRadius.circular(10),
          border: targetable ? Border.all(color: kLifeColor, width: 2) : null,
        ),
        child: Row(
          children: [
            Text(player.name, style: const TextStyle(fontSize: 12)),
            const SizedBox(width: 8),
            Icon(Icons.favorite, size: 16, color: color),
            const SizedBox(width: 3),
            Text('${player.life}',
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const Spacer(),
            _ManaPips(current: player.mana, max: player.maxMana),
            const SizedBox(width: 10),
            const Icon(Icons.back_hand_outlined, size: 13, color: kTextMuted),
            const SizedBox(width: 2),
            Text('${player.hand.length}',
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
            const SizedBox(width: 8),
            const Icon(Icons.style, size: 13, color: kTextMuted),
            const SizedBox(width: 2),
            Text('${player.library.length}',
                style: const TextStyle(fontSize: 12, color: kTextMuted)),
          ],
        ),
      ),
    );
  }
}

/// マナを丸で表示する。数字より残量が一目で分かる。
class _ManaPips extends StatelessWidget {
  const _ManaPips({required this.current, required this.max});

  final int current;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Padding(
            padding: const EdgeInsets.only(right: 2),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < current
                    ? kEnergyColor
                    : kEnergyColor.withValues(alpha: 0.22),
              ),
            ),
          ),
      ],
    );
  }
}
