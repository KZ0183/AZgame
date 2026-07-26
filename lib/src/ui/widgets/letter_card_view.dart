/// 文字カードと戦場のレーンを描画するウィジェット。
library;

import 'package:flutter/material.dart';

import '../../data/catalog.g.dart';
import '../theme.dart';

/// 1 枚の文字カード。
///
/// 文字そのものを主役に据え、コストと数値を角に小さく添える。
/// 26 種を絵で描き分けるのは現実的でないため、識別はクラス色と字形に任せる。
class LetterCardView extends StatelessWidget {
  const LetterCardView({
    super.key,
    required this.letter,
    this.width = 56,
    this.selected = false,
    this.dimmed = false,
    this.showStats = true,
    this.power,
    this.toughness,
    this.damage = 0,
    this.exhausted = false,
    this.onTap,
  });

  final String letter;
  final double width;

  /// 手札で選択中、または陣形に組み込まれている状態。
  final bool selected;

  /// エナジー不足などで今は使えない状態か。
  final bool dimmed;

  final bool showStats;

  /// 実効パワー。省略するとカードの基礎値を使う。
  final int? power;

  /// 実効タフネス。省略するとカードの基礎値を使う。
  final int? toughness;

  /// 現在受けているダメージ。0 より大きいと数値が赤く警告色になる。
  final int damage;

  /// 召喚酔いや拘束で攻撃できない状態か。
  final bool exhausted;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final card = cardCatalog[letter]!;
    final accent = classColor(card.klass);
    final height = width * 1.4;
    final effectivePower = power ?? card.power;
    final effectiveToughness = toughness ?? card.toughness;
    final remaining = effectiveToughness - damage;

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
        foregroundDecoration: dimmed || exhausted
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(width * 0.14),
                color: kBackground.withValues(alpha: exhausted ? 0.45 : 0.6),
              )
            : null,
        child: Stack(
          children: [
            Center(
              child: Text(
                letter,
                style: TextStyle(
                  fontSize: width * 0.6,
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
                left: 4,
                child: _Pip(
                  // 母音はコスト 0 でマナを生むので、支払いではなく生産量を出す。
                  value: card.isVowel ? '+${card.energyProduced}' : '${card.cost}',
                  color: kEnergyColor,
                  size: width,
                ),
              ),
              Positioned(
                bottom: 2,
                right: 4,
                child: Text(
                  '$effectivePower/${remaining < 0 ? 0 : remaining}',
                  style: TextStyle(
                    fontSize: width * 0.2,
                    fontWeight: FontWeight.w700,
                    color: damage > 0
                        ? kLifeColor
                        : Colors.white.withValues(alpha: 0.9),
                  ),
                ),
              ),
            ],
            if (exhausted)
              Positioned(
                top: 3,
                right: 4,
                child: Icon(
                  Icons.bedtime_outlined,
                  size: width * 0.22,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
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
      padding: EdgeInsets.symmetric(horizontal: size * 0.06, vertical: 1),
      constraints: BoxConstraints(minWidth: size * 0.26),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.14),
      ),
      child: Text(
        value,
        style: TextStyle(
          fontSize: size * 0.18,
          fontWeight: FontWeight.w800,
          color: Colors.black87,
        ),
      ),
    );
  }
}

/// 戦場のレーン 1 本。空なら枠だけを描く。
class LaneView extends StatelessWidget {
  const LaneView({
    super.key,
    required this.letter,
    required this.width,
    this.power,
    this.toughness,
    this.damage = 0,
    this.exhausted = false,
    this.inFormation = false,
    this.highlighted = false,
    this.onTap,
  });

  final String? letter;
  final double width;
  final int? power;
  final int? toughness;
  final int damage;
  final bool exhausted;

  /// 陣形に組み込まれているレーンか。
  final bool inFormation;

  /// 配置先の候補として光らせるか。
  final bool highlighted;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final current = letter;
    if (current != null) {
      return LetterCardView(
        letter: current,
        width: width,
        selected: inFormation,
        power: power,
        toughness: toughness,
        damage: damage,
        exhausted: exhausted,
        onTap: onTap,
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
          ),
        ),
        child: highlighted
            ? Icon(Icons.add, color: kWordColor, size: width * 0.4)
            : null,
      ),
    );
  }
}
