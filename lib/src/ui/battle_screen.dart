/// 戦闘画面。
///
/// 操作は 2 つだけ。「手札をタップして出す」「自分のミニオンをタップ →
/// 攻撃相手をタップ」。土地もブロックも攻撃宣言もない。
library;

import 'package:flutter/material.dart';

import '../engine/battle.dart';
import '../engine/models.dart';
import 'theme.dart';
import 'widgets/kana_card_view.dart';

class BattleScreen extends StatefulWidget {
  const BattleScreen({
    super.key,
    required this.battle,
    required this.onFinished,
  });

  final Battle battle;

  /// 決着したときに呼ばれる。勝ったかどうかを渡す。
  final void Function(bool won) onFinished;

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  Minion? _attacker;
  bool _resolving = false;
  String? _message;

  Battle get _battle => widget.battle;
  bool get _myTurn => !_resolving && !_battle.isOver;

  void _playCard(String kana) {
    if (!_myTurn || _battle.validatePlay(kana) != null) return;
    setState(() {
      _battle.play(kana);
      _message = null;
    });
  }

  void _selectAttacker(Minion minion) {
    if (!_myTurn) return;
    if (minion.attacked || minion.summoningSick) return;
    setState(() => _attacker = _attacker == minion ? null : minion);
  }

  /// 攻撃対象を指定して解決する。[target] が `null` なら敵本体を殴る。
  void _resolveAttack(Minion? target) {
    final attacker = _attacker;
    if (attacker == null || !_myTurn) return;
    final error = _battle.validateAttack(attacker, target: target);
    if (error == AttackError.tauntInTheWay) {
      setState(() => _message = '挑発がいる。先にそちらを倒すこと');
      return;
    }
    if (error != null) return;

    setState(() {
      _battle.attack(attacker, target);
      _attacker = null;
      _message = null;
    });
    if (_battle.playerWon) widget.onFinished(true);
  }

  Future<void> _endTurn() async {
    if (!_myTurn) return;
    setState(() {
      _attacker = null;
      _resolving = true;
    });
    await Future<void>.delayed(const Duration(milliseconds: 550));
    if (!mounted) return;

    final before = _battle.playerLife;
    setState(() {
      _battle.endTurn();
      final taken = before - _battle.playerLife;
      _message = taken > 0 ? '敵のターンで $taken ダメージ' : '敵は何もしてこなかった';
      _resolving = false;
    });
    if (_battle.playerLost) widget.onFinished(false);
  }

  @override
  Widget build(BuildContext context) {
    final aiming = _attacker != null;
    final blocked = _battle.enemyTaunts.isNotEmpty;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _EnemyHeader(
              battle: _battle,
              targetable: aiming && !blocked,
              onTap: aiming && !blocked ? () => _resolveAttack(null) : null,
            ),
            _MinionRow(
              minions: _battle.enemyMinions,
              emptyLabel: '敵の場は空',
              builder: (minion) => MinionView(
                minion: minion,
                targetable: aiming && (!blocked || minion.hasTaunt),
                onTap: aiming ? () => _resolveAttack(minion) : null,
              ),
            ),
            const Spacer(),
            _buildMessage(),
            const Spacer(),
            _MinionRow(
              minions: _battle.playerMinions,
              emptyLabel: '自分の場は空',
              builder: (minion) => MinionView(
                minion: minion,
                selected: _attacker == minion,
                canAct: _myTurn && minion.canAttack,
                onTap: _myTurn ? () => _selectAttacker(minion) : null,
              ),
            ),
            _PlayerBar(battle: _battle),
            _buildHand(),
            _buildActionBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildMessage() {
    final text = _resolving
        ? '敵のターン…'
        : _attacker != null
            ? '攻撃する相手をタップ（敵の名前をタップで本体）'
            : _message ?? 'カードを出して、ミニオンをタップして攻撃';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: _attacker != null ? kLifeColor : kTextMuted,
          fontSize: 12.5,
        ),
      ),
    );
  }

  Widget _buildHand() {
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: _battle.hand.length,
        separatorBuilder: (_, _) => const SizedBox(width: 5),
        itemBuilder: (context, index) {
          final kana = _battle.hand[index];
          final playable = _myTurn && _battle.validatePlay(kana) == null;
          return Center(
            child: CardView(
              kana: kana,
              dimmed: !playable,
              onTap: playable ? () => _playCard(kana) : null,
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
            onPressed: _showLog,
            icon: const Icon(Icons.receipt_long, color: kTextMuted),
          ),
          Expanded(
            child: FilledButton(
              onPressed: _myTurn ? _endTurn : null,
              style: FilledButton.styleFrom(
                backgroundColor: kAccentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(_myTurn ? 'ターン終了' : '敵のターン'),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }

  void _showLog() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurface,
      builder: (context) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final entry in _battle.log.entries.reversed.take(60))
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Text(entry,
                  style: const TextStyle(color: kTextMuted, fontSize: 13)),
            ),
        ],
      ),
    );
  }
}

/// 敵の頭。名前・ライフ・**次の行動予告**。予告が見えることがこのゲームの肝。
class _EnemyHeader extends StatelessWidget {
  const _EnemyHeader({
    required this.battle,
    required this.targetable,
    this.onTap,
  });

  final Battle battle;
  final bool targetable;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enemy = battle.enemy;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: targetable
              ? kLifeColor.withValues(alpha: 0.16)
              : kSurface.withValues(alpha: 0.6),
          borderRadius: BorderRadius.circular(12),
          border: targetable ? Border.all(color: kLifeColor, width: 2) : null,
        ),
        child: Row(
          children: [
            Text(enemy.glyph, style: const TextStyle(fontSize: 26)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(enemy.name, style: const TextStyle(fontSize: 13)),
                      const SizedBox(width: 8),
                      const Icon(Icons.favorite, size: 15, color: kEnemyColor),
                      const SizedBox(width: 3),
                      Text('${battle.enemyLife}',
                          style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: kEnemyColor)),
                      Text(' / ${enemy.life}',
                          style: const TextStyle(
                              fontSize: 11, color: kTextMuted)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.visibility_outlined,
                          size: 13, color: kEnergyColor),
                      const SizedBox(width: 4),
                      Text('次: ${battle.nextActionLabel}',
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: kEnergyColor)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerBar extends StatelessWidget {
  const _PlayerBar({required this.battle});

  final Battle battle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          const Icon(Icons.favorite, size: 16, color: kLifeColor),
          const SizedBox(width: 3),
          Text('${battle.playerLife}',
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: kLifeColor)),
          const SizedBox(width: 12),
          Expanded(child: _ManaPips(current: battle.mana, max: battle.maxMana)),
          const Icon(Icons.style, size: 13, color: kTextMuted),
          const SizedBox(width: 2),
          Text('${battle.library.length}',
              style: const TextStyle(fontSize: 12, color: kTextMuted)),
        ],
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
            padding: const EdgeInsets.only(right: 3),
            child: Container(
              width: 9,
              height: 9,
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

class _MinionRow extends StatelessWidget {
  const _MinionRow({
    required this.minions,
    required this.emptyLabel,
    required this.builder,
  });

  final List<Minion> minions;
  final String emptyLabel;
  final Widget Function(Minion) builder;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 78,
      child: minions.isEmpty
          ? Center(
              child: Text(emptyLabel,
                  style: const TextStyle(color: kTextMuted, fontSize: 11)))
          : ListView(
              scrollDirection: Axis.horizontal,
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final minion in minions)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    child: builder(minion),
                  ),
              ],
            ),
    );
  }
}
