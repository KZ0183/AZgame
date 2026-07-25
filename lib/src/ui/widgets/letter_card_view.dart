/// 文字カードとスペルラインのマスを描画するウィジェット。
library;

import 'package:flutter/material.dart';

import '../../data/catalog.g.dart';
import '../theme.dart';

/// 1 枚の文字カード。
///
/// 文字そのものを主役に据え、コストとパワーを角に小さく添える。
/// 26 種を絵で描き分けるのは現実的でないため、識別はクラス色と字形に任せる。
class LetterCardView extends StatelessWidget {
  const LetterCardView({
    super.key,
    required this.letter,
    this.width = 56,
    this.selected = false,
    this.dimmed = false,
    this.showStats = true,
    this.onTap,
  });

  final String letter;
  final double width;

  /// 手札で選択中か。
  final bool selected;

  /// エナジー不足などで今は使えない状態か。
  final bool dimmed;

  final bool showStats;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = cardCatalog[letter]!;
    final accent = classColor(card.klass);
    final height = width * 1.4;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(accent, Colors.black, 0.35)!,
              Color.lerp(accent, Colors.black, 0.62)!,
            ],
          ),
          border: Border.all(
            color: selected ? Colors.white : accent.withValues(alpha: 0.65),
            width: selected ? 2.5 : 1.2,
          ),
          boxShadow: selected
              ? [BoxShadow(color: accent.withValues(alpha: 0.6), blurRadius: 12)]
              : null,
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
                  fontSize: width * 0.62,
                  fontWeight: FontWeight.w700,
                  height: 1,
                  color: Colors.white,
                  letterSpacing: -1,
                ),
              ),
            ),
            if (showStats) ...[
              Positioned(
                top: 3,
                left: 5,
                child: _Pip(value: '${card.cost}', color: kEnergyColor, size: width),
              ),
              Positioned(
                bottom: 3,
                right: 5,
                child: Text(
                  '${card.power}',
                  style: TextStyle(
                    fontSize: width * 0.19,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.value, required this.color, required this.size});

  final String value;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size * 0.28,
      height: size * 0.28,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      child: Text(
        value,
        style: TextStyle(
          fontSize: size * 0.19,
          fontWeight: FontWeight.w700,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// スペルラインのマス 1 つ。空なら枠だけを描く。
class SpellSlotView extends StatelessWidget {
  const SpellSlotView({
    super.key,
    required this.letter,
    required this.width,
    this.highlighted = false,
    this.wordHighlighted = false,
    this.onTap,
  });

  final String? letter;
  final double width;

  /// 配置先の候補として光らせるか。
  final bool highlighted;

  /// ワードを構成しているマスとして光らせるか。
  final bool wordHighlighted;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final current = letter;
    if (current != null) {
      return Stack(
        alignment: Alignment.center,
        children: [
          LetterCardView(
            letter: current,
            width: width,
            selected: wordHighlighted,
            onTap: onTap,
          ),
          if (highlighted)
            IgnorePointer(
              child: Container(
                width: width,
                height: width * 1.4,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(width * 0.14),
                  border: Border.all(color: kWordColor, width: 2),
                  color: kWordColor.withValues(alpha: 0.18),
                ),
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        width: width,
        height: width * 1.4,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(width * 0.14),
          color: highlighted
              ? kWordColor.withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.03),
          border: Border.all(
            color: highlighted ? kWordColor : kOutline,
            width: highlighted ? 2 : 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: highlighted
            ? Icon(Icons.add, color: kWordColor, size: width * 0.4)
            : null,
      ),
    );
  }
}
