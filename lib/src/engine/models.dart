/// AZgame のコアデータモデル。
///
/// このファイルは Flutter に依存しない純粋な Dart で書かれている。
/// ルールエンジン全体が UI から独立してテストできることを保証するため、
/// `lib/src/engine/` 以下では `package:flutter/*` を import してはならない。
library;

/// 文字の分類。コスト帯と役割を表す。詳細は docs/game-design.md 3.2 を参照。
enum LetterClass {
  /// 母音 A E I O U。安価・低パワー。ワード形成の潤滑油。
  vowel,

  /// 基幹 D G L N R S T。安価でワードに入りやすい汎用サポート。
  core,

  /// 重 B C F H K M P V W Y。中コスト。クセのある能力を持つ。
  heavy,

  /// 希少 J Q X Z。高コスト・高パワーの切り札。
  rare,
}

/// 固有能力の発動タイミング。
enum AbilityTrigger {
  /// スペルラインに配置した瞬間に発動する。
  onPlace,

  /// スペルライン上にある間、常に有効。
  passive,

  /// このカードを含むワードが成立したときに発動する。
  onWord,
}

/// 文字カード 1 種のマスターデータ。A〜Z の 26 個だけ存在する不変オブジェクト。
///
/// カードは状態を持たないため、盤面上では文字（`String`）として参照し、
/// ステータスが必要になった時点でカタログから引く。
class LetterCard {
  const LetterCard({
    required this.letter,
    required this.rank,
    required this.cost,
    required this.power,
    required this.klass,
    required this.deckLimit,
    required this.abilityName,
    required this.trigger,
    required this.abilityText,
  });

  /// 'A' 〜 'Z'。
  final String letter;

  /// アルファベット順位 1〜26。シークエンス判定に使う。
  final int rank;

  /// 配置に必要なエナジー。
  final int cost;

  /// ワード威力への加算値、およびシークエンスダメージの素になる値。
  final int power;

  final LetterClass klass;

  /// デッキに投入できる最大枚数。
  final int deckLimit;

  final String abilityName;
  final AbilityTrigger trigger;
  final String abilityText;

  @override
  String toString() => 'LetterCard($letter)';
}

/// コンボワード 1 語のマスターデータ。
class ComboWord {
  const ComboWord({
    required this.word,
    required this.damage,
    required this.effectText,
  });

  /// 大文字のみで構成される 2〜5 文字の語。
  final String word;

  /// ワード固有ダメージ。実効ダメージは、これに構成カードのパワー合計を加えたもの。
  final int damage;

  final String effectText;

  int get length => word.length;

  @override
  String toString() => 'ComboWord($word)';
}

/// スペルライン。5 マスの固定長で、各マスは空 (`null`) か文字を保持する。
///
/// マスの索引は 0 が最も左。ワードは左から右へ読む。
class SpellLine {
  SpellLine() : _slots = List<String?>.filled(slotCount, null);

  SpellLine.from(List<String?> slots)
    : assert(slots.length == slotCount),
      _slots = List<String?>.of(slots);

  /// スペルラインのマス数。
  static const int slotCount = 5;

  final List<String?> _slots;

  /// 読み取り専用のマス一覧。
  List<String?> get slots => List<String?>.unmodifiable(_slots);

  String? operator [](int index) => _slots[index];

  bool isEmptyAt(int index) => _slots[index] == null;

  bool get isEmpty => _slots.every((s) => s == null);

  bool get isFull => _slots.every((s) => s != null);

  /// 埋まっているマスの索引一覧。
  List<int> get occupiedIndices => [
    for (var i = 0; i < slotCount; i++)
      if (_slots[i] != null) i,
  ];

  /// 空いているマスの索引一覧。
  List<int> get emptyIndices => [
    for (var i = 0; i < slotCount; i++)
      if (_slots[i] == null) i,
  ];

  /// 指定マスに文字を置く。すでに埋まっている場合は [StateError]。
  void place(int index, String letter) {
    if (_slots[index] != null) {
      throw StateError('マス $index はすでに $_slots[index] で埋まっています');
    }
    _slots[index] = letter;
  }

  /// 指定マスの文字を取り除いて返す。空だった場合は `null`。
  String? removeAt(int index) {
    final removed = _slots[index];
    _slots[index] = null;
    return removed;
  }

  /// 全マスを空にし、取り除かれた文字を配置順に返す。
  List<String> clear() {
    final removed = <String>[];
    for (var i = 0; i < slotCount; i++) {
      final letter = _slots[i];
      if (letter != null) {
        removed.add(letter);
        _slots[i] = null;
      }
    }
    return removed;
  }

  /// 埋まっている文字を左詰めのまま、与えられた順に並べ替える。
  ///
  /// `O`（オービット）や `AIR` のように「好きな順に並べ替える」効果で使う。
  /// [order] は現在埋まっている文字の順列でなければならない。
  void reorder(List<String> order) {
    final occupied = occupiedIndices;
    if (order.length != occupied.length) {
      throw ArgumentError('並べ替えの要素数が一致しません: '
          '${order.length} != ${occupied.length}');
    }
    for (var i = 0; i < occupied.length; i++) {
      _slots[occupied[i]] = order[i];
    }
  }

  SpellLine copy() => SpellLine.from(_slots);

  @override
  String toString() => _slots.map((s) => s ?? '_').join();
}
