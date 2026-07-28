/// AZgame のコアデータモデル。Flutter に依存しない純粋な Dart。
library;

/// カード 1 種のマスターデータ。A〜Z の 26 枚。
class LetterCard {
  const LetterCard({
    required this.letter,
    required this.rank,
    required this.cost,
    required this.power,
    required this.toughness,
    required this.deckLimit,
  });

  final String letter;

  /// アルファベット順位 1〜26。表示の並び順に使う。
  final int rank;

  /// 唱えるのに必要なマナ。
  final int cost;

  final int power;
  final int toughness;

  /// デッキに入れられる最大枚数。
  final int deckLimit;

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

  /// このターンすでに攻撃したか。攻撃は 1 体につき 1 回。
  bool attacked = false;

  /// 召喚酔い。出したターンは攻撃できない。
  bool summoningSick = true;

  /// このターンに受けた累積ダメージ。ターン終了時に 0 に戻る。
  int damage = 0;

  @override
  String toString() => attacked ? letter.toLowerCase() : letter;
}
