/// AZgame のコアデータモデル。Flutter に依存しない純粋な Dart。
library;

/// カードの種類。v0.5 は土地とクリーチャーの 2 つだけ。
enum CardType { land, creature }

/// カード 1 種のマスターデータ。A〜Z の 26 枚。
class LetterCard {
  const LetterCard({
    required this.letter,
    required this.rank,
    required this.type,
    required this.cost,
    required this.power,
    required this.toughness,
    required this.deckLimit,
  });

  final String letter;

  /// アルファベット順位 1〜26。表示の並び順に使う。
  final int rank;

  final CardType type;

  /// 唱えるのに必要なマナ。土地は 0。
  final int cost;

  final int power;
  final int toughness;

  /// デッキに入れられる最大枚数。
  final int deckLimit;

  bool get isLand => type == CardType.land;
  bool get isCreature => type == CardType.creature;

  @override
  String toString() => letter;
}

/// 対戦者。
enum Owner {
  first,
  second;

  Owner get opponent => this == first ? second : first;
}

/// 戦場に出ているパーマネント。
class Permanent {
  Permanent(this.letter);

  final String letter;

  /// タップ済みか。土地はマナを出すと、クリーチャーは攻撃するとタップする。
  bool tapped = false;

  /// 召喚酔い。出したターンは攻撃できない。
  bool summoningSick = true;

  /// このターンに受けた累積ダメージ。ターン終了時に 0 に戻る。
  int damage = 0;

  @override
  String toString() => tapped ? letter.toLowerCase() : letter;
}
