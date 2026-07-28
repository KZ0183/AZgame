/// カードと盤上のミニオンを描画するウィジェット。
library;

import 'package:flutter/material.dart';

import '../../data/catalog.g.dart';
import '../../engine/models.dart';
import '../theme.dart';

/// 手札の 1 枚。左上にコスト、下辺に能力と P/T。
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.kana,
    this.width = 54,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  final String kana;
  final double width;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = cardCatalog[kana]!;
    final accent = cardColor(card);
    final badge = abilityBadge(card);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: width,
        height: width * 1.4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(accent, Colors.black, 0.28)!,
              Color.lerp(accent, Colors.black, 0.62)!,
            ],
          ),
          border: Border.all(
            color: selected ? Colors.white : accent.withValues(alpha: 0.6),
            width: selected ? 2.4 : 1.2,
          ),
        ),
        foregroundDecoration: dimmed
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.14),
                color: kBackground.withValues(alpha: 0.6),
              )
            : null,
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: EdgeInsets.only(bottom: width * 0.18),
                child: Text(
                  card.kana,
                  style: TextStyle(
                    fontSize: width * 0.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1,
                  ),
                ),
              ),
            ),
            Positioned(
              top: 3,
              left: 4,
              child: _Pill(text: '${card.cost}', color: kEnergyColor),
            ),
            Positioned(
              bottom: 3,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (badge != null)
                    Text(badge,
                        style: TextStyle(
                          fontSize: width * 0.16,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.95),
                        )),
                  Text(
                    '${card.power}/${card.toughness}',
                    style: TextStyle(
                      fontSize: width * 0.19,
                      fontWeight: FontWeight.w700,
                      color: Colors.white.withValues(alpha: 0.85),
                    ),
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

/// カードに乗せる能力の短い呼び名。何も持たなければ `null`。
String? abilityBadge(KanaCard card) {
  if (card.keywords.isNotEmpty) return keywordName(card.keywords.first);
  return switch (card.onPlay) {
    OnPlay.none => null,
    OnPlay.snipe => '狙撃${card.onPlayValue}',
    OnPlay.draw => 'ドロー',
    OnPlay.heal => '回復${card.onPlayValue}',
  };
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text,
          style: const TextStyle(
              fontSize: 11, fontWeight: FontWeight.w800, color: Colors.black87)),
    );
  }
}

/// 盤上のミニオン。
class MinionView extends StatelessWidget {
  const MinionView({
    super.key,
    required this.minion,
    this.width = 50,
    this.selected = false,
    this.targetable = false,
    this.canAct = false,
    this.onTap,
  });

  final Minion minion;
  final double width;

  /// 攻撃者として選択中か。
  final bool selected;

  /// 攻撃対象として選べる状態か。
  final bool targetable;

  /// 今このミニオンで攻撃できるか。できるものだけ縁を光らせる。
  final bool canAct;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = minion.card;
    final remaining = minion.remaining;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: width * 1.3,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.16),
          color: cardColor(card).withValues(alpha: 0.85),
          border: Border.all(
            color: selected
                ? Colors.white
                : targetable
                    ? kLifeColor
                    : canAct
                        ? kEnergyColor
                        : kOutline,
            width: (selected || targetable) ? 2.6 : (canAct ? 2 : 1),
          ),
        ),
        foregroundDecoration: minion.summoningSick || minion.attacked
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.16),
                color: kBackground.withValues(alpha: 0.45),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (minion.hasTaunt)
              Text('挑発',
                  style: TextStyle(
                      fontSize: width * 0.16,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
            Text(card.kana,
                style: TextStyle(
                    fontSize: width * 0.44,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1.1)),
            Text('${card.power}/${remaining < 0 ? 0 : remaining}',
                style: TextStyle(
                  fontSize: width * 0.2,
                  fontWeight: FontWeight.w700,
                  color: minion.damage > 0 ? kLifeColor : Colors.white70,
                )),
          ],
        ),
      ),
    );
  }
}
