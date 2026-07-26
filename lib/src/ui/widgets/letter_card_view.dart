/// 文字の駒と盤のマスを描画するウィジェット。
library;

import 'package:flutter/material.dart';

import '../../data/catalog.g.dart';
import '../../engine/models.dart';
import '../theme.dart';

/// 持ち駒として並ぶ 1 文字。
class HandPieceView extends StatelessWidget {
  const HandPieceView({
    super.key,
    required this.letter,
    this.count = 1,
    this.size = 46,
    this.selected = false,
    this.onTap,
  });

  final String letter;

  /// 同じ文字を何枚持っているか。2 枚以上なら数字を添える。
  final int count;

  final double size;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final accent = classColor(cardCatalog[letter]!.klass);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 110),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.2),
          color: selected
              ? accent.withValues(alpha: 0.85)
              : accent.withValues(alpha: 0.16),
          border: Border.all(
            color: selected ? Colors.white : accent.withValues(alpha: 0.7),
            width: selected ? 2.2 : 1.2,
          ),
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              letter,
              style: TextStyle(
                fontSize: size * 0.52,
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : accent,
                height: 1,
              ),
            ),
            if (count > 1)
              Positioned(
                right: 2,
                bottom: 1,
                child: Text(
                  '×$count',
                  style: TextStyle(
                    fontSize: size * 0.22,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : kTextMuted,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// 盤上の 1 マス。
class BoardCellView extends StatelessWidget {
  const BoardCellView({
    super.key,
    required this.piece,
    required this.size,
    this.highlighted = false,
    this.inFormation = false,
    this.threatened = false,
    this.onTap,
  });

  final Piece? piece;
  final double size;

  /// 置ける候補として光らせるか。
  final bool highlighted;

  /// 直前の手で成立した並びに含まれるか。
  final bool inFormation;

  /// 直前の手で奪われる対象になっているか。
  final bool threatened;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final current = piece;
    final isMine = current?.owner == Owner.first;
    final base = current == null
        ? Colors.white.withValues(alpha: 0.04)
        : (isMine ? kFirstColor : kSecondColor);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * 0.16),
          color: current == null
              ? (highlighted ? kWordColor.withValues(alpha: 0.16) : base)
              : base.withValues(alpha: 0.9),
          border: Border.all(
            color: threatened
                ? kLifeColor
                : inFormation
                    ? Colors.white
                    : highlighted
                        ? kWordColor
                        : kOutline,
            width: (threatened || inFormation) ? 2.4 : (highlighted ? 2 : 1),
          ),
        ),
        child: current == null
            ? null
            : Text(
                current.letter,
                style: TextStyle(
                  fontSize: size * 0.5,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                  height: 1,
                ),
              ),
      ),
    );
  }
}
