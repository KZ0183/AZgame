/// AZgame のコアデータモデル。
///
/// Flutter に依存しない純粋な Dart で書く。ルールエンジン全体が UI から
/// 独立してテストできることを保証するため、`lib/src/engine/` 以下では
/// `package:flutter/*` を import してはならない。
library;

/// 文字の分類。
enum LetterClass {
  /// 母音 A E I O U。コスト 0 で 1 ターン 1 枚だけ出せ、毎ターンエナジーを生む。
  /// MTG の土地に相当する。
  vowel,

  /// 基幹 D G L N R S T。安価で小回りの利く子音。
  core,

  /// 重 B C F H K M P V W Y。中コスト。はっきりした能力を持つ。
  heavy,

  /// 希少 J Q X Z。高コスト・高パワーの切り札。
  rare,
}

/// 能力の発動タイミング。
enum AbilityTrigger {
  /// 戦場にある間、常に有効。
  static,

  /// 自分のターン開始時に毎回発動する。
  upkeep,

  /// 戦場に出た瞬間に 1 回だけ発動する。
  onPlay,
}

/// 文字カード 1 種のマスターデータ。A〜Z の 26 個だけ存在する不変オブジェクト。
class LetterCard {
  const LetterCard({
    required this.letter,
    required this.rank,
    required this.cost,
    required this.power,
    required this.toughness,
    required this.klass,
    required this.deckLimit,
    required this.energyProduced,
    required this.abilityName,
    required this.trigger,
    required this.abilityText,
  });

  /// 'A' 〜 'Z'。
  final String letter;

  /// アルファベット順位 1〜26。連番陣形の判定に使う。
  final int rank;

  /// 戦場に出すのに必要なエナジー。母音は 0。
  final int cost;

  /// 戦闘で与えるダメージの基礎値。
  final int power;

  /// この値以上のダメージを受けると破壊される。
  final int toughness;

  final LetterClass klass;

  /// デッキに投入できる最大枚数。
  final int deckLimit;

  /// 戦場にある間、毎ターン生み出すエナジー。子音は 0。
  final int energyProduced;

  final String abilityName;
  final AbilityTrigger trigger;
  final String abilityText;

  bool get isVowel => klass == LetterClass.vowel;

  @override
  String toString() => 'LetterCard($letter)';
}

/// ワード陣形が成立している間、継続的にかかる効果。
///
/// 効果は型付きの数値の集合として表す。任意の Dart コードを書けるようにすると
/// データ側でバランス調整ができなくなるため、あえて表現力を絞っている。
class WordEffect {
  const WordEffect({
    this.powerBonus = 0,
    this.toughnessBonus = 0,
    this.upkeepDamage = 0,
    this.upkeepHeal = 0,
    this.upkeepDraw = 0,
    this.upkeepEnergy = 0,
    this.upkeepShield = 0,
    this.freeze = 0,
    this.pierce = false,
  });

  /// 自分の全文字のパワーへの加算。
  final int powerBonus;

  /// 自分の全文字のタフネスへの加算。
  final int toughnessBonus;

  /// 自分のターン開始時に相手へ与えるダメージ。
  final int upkeepDamage;

  /// 自分のターン開始時に回復する LP。
  final int upkeepHeal;

  /// 自分のターン開始時に引く枚数。
  final int upkeepDraw;

  /// 自分のターン開始時に得るエナジー。
  final int upkeepEnergy;

  /// 自分のターン開始時に得るシールド。
  final int upkeepShield;

  /// 相手の文字のうち、攻撃できなくする体数。
  final int freeze;

  /// 自分の全文字の戦闘ダメージが、対峙する文字を無視して相手 LP に入るか。
  final bool pierce;

  /// 2 つの効果を合算する。複数の陣形が同時に成立したときに使う。
  WordEffect merge(WordEffect other) => WordEffect(
        powerBonus: powerBonus + other.powerBonus,
        toughnessBonus: toughnessBonus + other.toughnessBonus,
        upkeepDamage: upkeepDamage + other.upkeepDamage,
        upkeepHeal: upkeepHeal + other.upkeepHeal,
        upkeepDraw: upkeepDraw + other.upkeepDraw,
        upkeepEnergy: upkeepEnergy + other.upkeepEnergy,
        upkeepShield: upkeepShield + other.upkeepShield,
        freeze: freeze + other.freeze,
        pierce: pierce || other.pierce,
      );

  static const WordEffect none = WordEffect();
}

/// コンボワード 1 語のマスターデータ。
class ComboWord {
  const ComboWord({
    required this.word,
    required this.effect,
    required this.text,
  });

  /// 大文字のみで構成される 2〜5 文字の語。
  final String word;

  /// 陣形が成立している間、継続的にかかる効果。
  final WordEffect effect;

  /// 表示用の効果文言。`data/words.json` の効果定義から自動生成される。
  final String text;

  int get length => word.length;

  @override
  String toString() => 'ComboWord($word)';
}

/// 戦場に出ている文字 1 体。カードと違い、こちらは状態を持つ。
class Permanent {
  Permanent(this.letter);

  final String letter;

  /// このターンに受けた累積ダメージ。ターン終了時に 0 に戻る。
  int damage = 0;

  /// 召喚酔い。出したターンは攻撃できない。
  bool summoningSick = true;

  /// 陣形や効果によって攻撃を止められているか。
  bool frozen = false;

  Permanent copy() => Permanent(letter)
    ..damage = damage
    ..summoningSick = summoningSick
    ..frozen = frozen;

  @override
  String toString() => letter;
}

/// 戦場。5 レーンの固定長で、各レーンは空 (`null`) か文字 1 体を保持する。
///
/// レーンの索引は 0 が最も左。単語は左から右へ読む。
/// 自分のレーン `i` は相手のレーン `i` と対峙する。
class Battlefield {
  Battlefield() : _lanes = List<Permanent?>.filled(laneCount, null);

  Battlefield.from(List<Permanent?> lanes)
      : assert(lanes.length == laneCount),
        _lanes = List<Permanent?>.of(lanes);

  /// レーン数。
  static const int laneCount = 5;

  final List<Permanent?> _lanes;

  List<Permanent?> get lanes => List<Permanent?>.unmodifiable(_lanes);

  Permanent? operator [](int index) => _lanes[index];

  /// レーンにいる文字を左から順に並べた読み取り用の列。
  List<Permanent> get occupants => [
        for (final permanent in _lanes) ?permanent,
      ];

  bool isEmptyAt(int index) => _lanes[index] == null;

  bool get isEmpty => _lanes.every((lane) => lane == null);

  bool get isFull => _lanes.every((lane) => lane != null);

  int get count => _lanes.where((lane) => lane != null).length;

  List<int> get occupiedIndices => [
        for (var i = 0; i < laneCount; i++)
          if (_lanes[i] != null) i,
      ];

  List<int> get emptyIndices => [
        for (var i = 0; i < laneCount; i++)
          if (_lanes[i] == null) i,
      ];

  /// 指定レーンに文字を出す。すでに埋まっている場合は [StateError]。
  void place(int index, Permanent permanent) {
    if (_lanes[index] != null) {
      throw StateError('レーン $index はすでに埋まっています');
    }
    _lanes[index] = permanent;
  }

  /// 指定レーンの文字を取り除いて返す。空だった場合は `null`。
  Permanent? removeAt(int index) {
    final removed = _lanes[index];
    _lanes[index] = null;
    return removed;
  }

  /// 全レーンを空にし、取り除かれた文字を左から順に返す。
  List<Permanent> clear() {
    final removed = <Permanent>[];
    for (var i = 0; i < laneCount; i++) {
      final permanent = _lanes[i];
      if (permanent != null) {
        removed.add(permanent);
        _lanes[i] = null;
      }
    }
    return removed;
  }

  /// 埋まっているレーンはそのままに、そこにいる文字を与えられた順に並べ替える。
  void reorder(List<Permanent> order) {
    final occupied = occupiedIndices;
    if (order.length != occupied.length) {
      throw ArgumentError('並べ替えの要素数が一致しません: '
          '${order.length} != ${occupied.length}');
    }
    for (var i = 0; i < occupied.length; i++) {
      _lanes[occupied[i]] = order[i];
    }
  }

  Battlefield copy() =>
      Battlefield.from([for (final lane in _lanes) lane?.copy()]);

  @override
  String toString() =>
      _lanes.map((lane) => lane?.letter ?? '_').join();
}
