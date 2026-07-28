/// カードとパーマネントを描画するウィジェット。
library;

import 'package:flutter/material.dart';

import '../../data/catalog.g.dart';
import '../../engine/models.dart';
import '../theme.dart';

/// 手札の 1 枚。土地は緑、クリーチャーはコスト帯で色分けする。
class CardView extends StatelessWidget {
  const CardView({
    super.key,
    required this.letter,
    this.width = 52,
    this.selected = false,
    this.dimmed = false,
    this.onTap,
  });

  final String letter;
  final double width;
  final bool selected;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = cardCatalog[letter]!;
    final accent = cardColor(card);

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
              Color.lerp(accent, Colors.black, 0.3)!,
              Color.lerp(accent, Colors.black, 0.6)!,
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
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: width * 0.58,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
            ),
            Positioned(
              top: 3,
              left: 5,
              child: _Badge(text: '${card.cost}', color: kEnergyColor),
            ),
            Positioned(
              bottom: 3,
              right: 5,
              child: Text(
                '${card.power}/${card.toughness}',
                style: TextStyle(
                  fontSize: width * 0.2,
                  fontWeight: FontWeight.w700,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text, required this.color});

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

/// 戦場に出ているクリーチャー。
class CreatureView extends StatelessWidget {
  const CreatureView({
    super.key,
    required this.permanent,
    this.width = 46,
    this.selected = false,
    this.targetable = false,
    this.canAct = false,
    this.onTap,
  });

  final Permanent permanent;
  final double width;

  /// 攻撃者として選択中か。
  final bool selected;

  /// 攻撃対象として選べる状態か。
  final bool targetable;

  /// 今このクリーチャーで攻撃できるか。できるものだけ縁を光らせる。
  final bool canAct;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = cardCatalog[permanent.letter]!;
    final remaining = card.toughness - permanent.damage;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: width * 1.25,
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
        foregroundDecoration: permanent.summoningSick || permanent.attacked
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.16),
                color: kBackground.withValues(alpha: 0.45),
              )
            : null,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(permanent.letter,
                style: TextStyle(
                    fontSize: width * 0.5,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                    height: 1)),
            Text('${card.power}/${remaining < 0 ? 0 : remaining}',
                style: TextStyle(
                  fontSize: width * 0.22,
                  fontWeight: FontWeight.w700,
                  color: permanent.damage > 0 ? kLifeColor : Colors.white70,
                )),
          ],
        ),
      ),
    );
  }
}
