/// コアデータモデル。Flutter に依存しない純粋な Dart。
library;

/// カードが持つ常在能力。
enum Keyword {
  /// 挑発。相手はこのミニオンを先に攻撃しなければならない。
  taunt,

  /// 突撃。出したターンから攻撃できる。
  charge,

  /// 絆魂。与えたダメージぶんライフが回復する。
  lifesteal,

  /// 貫通。ミニオンを倒して余ったダメージが本体に入る。
  pierce,
}

/// 場に出したときの 1 回きりの効果。
enum OnPlay {
  none,

  /// 敵ミニオン 1 体にダメージ。
  snipe,

  /// カードを引く。
  draw,

  /// ライフを回復する。
  heal,
}

/// カード 1 種のマスターデータ。あ〜ん の 46 枚。
///
/// **行が種族、段がコスト。** 「か行は突撃」「た行は挑発」のように
/// 行が役割を決め、コストは段（あ段 = 1 … お段 = 5）でそのまま読める。
/// 文字を見た瞬間に「何マナで何ができるか」が分かるようにするための設計。
class KanaCard {
  const KanaCard({
    required this.kana,
    required this.order,
    required this.row,
    required this.cost,
    required this.power,
    required this.toughness,
    required this.keywords,
    required this.onPlay,
    required this.onPlayValue,
    required this.deckLimit,
  });

  final String kana;

  /// 五十音順 1〜46。表示の並び順に使う。
  final int order;

  /// 所属する行。`'あ行'`〜`'わ行'`、および「ん」だけの `'ん'`。
  final String row;

  final int cost;
  final int power;
  final int toughness;

  final Set<Keyword> keywords;

  final OnPlay onPlay;

  /// [onPlay] の効果量。ダメージ量・回復量・ドロー枚数。
  final int onPlayValue;

  /// デッキに入れられる最大枚数。
  final int deckLimit;

  bool has(Keyword keyword) => keywords.contains(keyword);

  /// 「1/2 挑発」のような 1 行表記。
  String get statLine {
    final buffer = StringBuffer('$power/$toughness');
    for (final keyword in keywords) {
      buffer.write(' ${keywordName(keyword)}');
    }
    return buffer.toString();
  }

  /// 効果の説明文。効果がなければ空文字。
  String get effectText => switch (onPlay) {
        OnPlay.none => '',
        OnPlay.snipe => '出たとき 敵 1 体に $onPlayValue ダメージ',
        OnPlay.draw => '出たとき $onPlayValue 枚引く',
        OnPlay.heal => '出たとき ライフ $onPlayValue 回復',
      };

  @override
  String toString() => kana;
}

/// 場に出ているミニオン 1 体。プレイヤー側・敵側の区別なく使う。
///
/// 受けたダメージは回復しない（ターンをまたいで残る）。
class Minion {
  Minion(this.card, {bool? summoningSick})
      : summoningSick = summoningSick ?? !card.has(Keyword.charge);

  final KanaCard card;

  String get kana => card.kana;

  /// このターンすでに攻撃したか。攻撃は 1 体につき 1 回。
  bool attacked = false;

  /// 召喚酔い。出したターンは攻撃できない。突撃を持つカードは最初から解けている。
  bool summoningSick;

  int damage = 0;

  int get remaining => card.toughness - damage;
  bool get isDead => damage >= card.toughness;
  bool get hasTaunt => card.has(Keyword.taunt);
  bool get canAttack => !attacked && !summoningSick;

  @override
  String toString() => '$kana(${card.power}/$remaining)';
}

String keywordName(Keyword keyword) => switch (keyword) {
      Keyword.taunt => '挑発',
      Keyword.charge => '突撃',
      Keyword.lifesteal => '絆魂',
      Keyword.pierce => '貫通',
    };

String keywordDescription(Keyword keyword) => switch (keyword) {
      Keyword.taunt => '相手はこれを先に攻撃しなければならない',
      Keyword.charge => '出したターンから攻撃できる',
      Keyword.lifesteal => '与えたダメージぶんライフが回復する',
      Keyword.pierce => '倒して余ったダメージが本体に入る',
    };
