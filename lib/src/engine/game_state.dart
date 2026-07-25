/// 対戦の状態を表すモデル群。
library;

import 'dart:math';

import '../data/catalog.g.dart';
import 'models.dart';

/// 初期ライフポイント。
const int kStartingLp = 50;

/// 1 ターンに配置できるカードの基本枚数。
///
/// エナジーと空きマスが許す限り、この枚数まで配置できる。
/// `R`（ラッシュ）や `GO` は一時的にこれを増やし、
/// `ICE` / `FROST` / `LOCK` は一時的に減らす。
const int kBasePlacementsPerTurn = 2;

/// エナジーの上限。
const int kMaxEnergyCap = 10;

/// 初期手札枚数。
const int kStartingHandSize = 5;

/// 手札の上限。エンドフェイズに超過分を捨てる。
const int kHandLimit = 8;

/// デッキの枚数。
const int kDeckSize = 30;

/// 対戦者ひとりぶんの状態。
class PlayerState {
  PlayerState({
    required this.name,
    required List<String> deck,
    this.lp = kStartingLp,
  }) : deck = List<String>.of(deck);

  final String name;

  int lp;
  int shield = 0;
  int energy = 0;
  int maxEnergy = 0;

  /// 山札。索引 0 が一番上。
  final List<String> deck;

  final List<String> hand = [];
  final SpellLine line = SpellLine();
  final List<String> graveyard = [];

  /// このターンすでに配置した枚数。
  int placementsUsed = 0;

  /// このターン限定の追加配置枚数（`R` / `GO`）。
  int bonusPlacements = 0;

  /// 今後のターンに課される配置制限のキュー。索引 0 が次の自分のターン。
  ///
  /// `ICE` は `[1]`、`FROST` は `[1, 1]`、`LOCK` は `[0]` を課す。
  /// 複数の制限が重なる場合は、ターンごとに厳しいほう（小さいほう）が残る。
  final List<int> placementLimitQueue = [];

  /// 次に発動するワードが無効化されるか（`NO` / `JINX`）。
  bool negateNextWord = false;

  /// 次に発動するワードのダメージ加算（`UP` / `MAP`）。
  int nextWordBonus = 0;

  /// 次に受けるダメージを半減するか（`VEIL`）。
  bool halveIncomingDamage = false;

  /// 直近に発動したワード。`M`（ミラー）が参照する。
  ComboWord? lastWord;

  /// デッキ切れで敗北が確定したか。
  bool deckedOut = false;

  bool get isDefeated => lp <= 0 || deckedOut;

  /// このターン配置できる残り枚数。
  int get remainingPlacements {
    final limit = _currentPlacementLimit + bonusPlacements;
    final remaining = limit - placementsUsed;
    return remaining < 0 ? 0 : remaining;
  }

  int _currentTurnLimit = kBasePlacementsPerTurn;
  int get _currentPlacementLimit => _currentTurnLimit;

  /// ターン開始時に配置制限を確定させる。
  void beginTurnPlacementLimit() {
    if (placementLimitQueue.isNotEmpty) {
      _currentTurnLimit = placementLimitQueue.removeAt(0);
    } else {
      _currentTurnLimit = kBasePlacementsPerTurn;
    }
    placementsUsed = 0;
    bonusPlacements = 0;
  }

  /// [turns] ターンのあいだ、配置枚数を [limit] 以下に制限する。
  void restrictPlacements({required int turns, required int limit}) {
    for (var i = 0; i < turns; i++) {
      if (i < placementLimitQueue.length) {
        placementLimitQueue[i] = min(placementLimitQueue[i], limit);
      } else {
        placementLimitQueue.add(limit);
      }
    }
  }

  /// 山札の一番上から [count] 枚引く。引ける枚数が足りなければデッキ切れ。
  List<String> draw(int count) {
    final drawn = <String>[];
    for (var i = 0; i < count; i++) {
      if (deck.isEmpty) {
        deckedOut = true;
        break;
      }
      final card = deck.removeAt(0);
      hand.add(card);
      drawn.add(card);
    }
    return drawn;
  }

  /// 山札の上から [count] 枚を墓地へ送る（`BUG`）。
  List<String> mill(int count) {
    final milled = <String>[];
    for (var i = 0; i < count && deck.isNotEmpty; i++) {
      final card = deck.removeAt(0);
      graveyard.add(card);
      milled.add(card);
    }
    return milled;
  }

  void heal(int amount) {
    lp += amount;
  }

  void gainShield(int amount) {
    shield += amount;
  }

  void gainEnergy(int amount) {
    energy = min(energy + amount, maxEnergy);
  }

  void gainMaxEnergy(int amount) {
    maxEnergy = min(maxEnergy + amount, kMaxEnergyCap);
    energy = min(energy + amount, maxEnergy);
  }

  /// スペルライン上の指定マスのカードを墓地へ送る。
  String? destroyAt(int index) {
    final removed = line.removeAt(index);
    if (removed != null) graveyard.add(removed);
    return removed;
  }

  /// スペルライン上の全カードを墓地へ送る。
  List<String> destroyLine() {
    final removed = line.clear();
    graveyard.addAll(removed);
    return removed;
  }

  /// 手札の指定索引を捨てる。
  String? discardAt(int index) {
    if (index < 0 || index >= hand.length) return null;
    final card = hand.removeAt(index);
    graveyard.add(card);
    return card;
  }

  @override
  String toString() =>
      '$name(LP $lp${shield > 0 ? ' +$shield' : ''}, '
      'E $energy/$maxEnergy, line $line)';
}

/// 対戦全体の状態。
class GameState {
  GameState({
    required this.first,
    required this.second,
    Random? rng,
  }) : rng = rng ?? Random();

  /// 先攻プレイヤー。
  final PlayerState first;

  /// 後攻プレイヤー。
  final PlayerState second;

  /// 乱数源。テストでは種を固定して決定的に動かせる。
  final Random rng;

  /// 1 から始まるターン番号。両者のターンを通して増加する。
  int turnNumber = 0;

  /// 現在の手番プレイヤーが先攻側か。
  bool isFirstPlayerTurn = true;

  PlayerState get active => isFirstPlayerTurn ? first : second;
  PlayerState get inactive => isFirstPlayerTurn ? second : first;

  bool get isOver => first.isDefeated || second.isDefeated;

  /// 勝者。決着がついていなければ `null`。相打ちの場合も `null`。
  PlayerState? get winner {
    if (!isOver) return null;
    final firstDown = first.isDefeated;
    final secondDown = second.isDefeated;
    if (firstDown && secondDown) return null;
    return firstDown ? second : first;
  }
}

/// 対戦中に起きた出来事の記録。UI の演出とデバッグの両方に使う。
class GameLog {
  final List<String> entries = [];

  void add(String message) => entries.add(message);

  @override
  String toString() => entries.join('\n');
}

/// 効果の解決中にプレイヤー（または AI）へ選択を求めるためのインターフェース。
///
/// エンジンを UI から独立させるための境界。テストでは決定的な実装を、
/// 対人プレイでは UI 実装を、AI 戦では思考ルーチンを差し込む。
abstract class Chooser {
  /// [letters] から 1 枚選び、その索引を返す。選ばない場合は `null`。
  int? chooseCard(String reason, List<String> letters);

  /// スペルライン上の埋まっているマスから 1 つ選び、索引を返す。
  int? chooseLineSlot(String reason, SpellLine line);

  /// [letters] を任意の順に並べ替えて返す。
  List<String> chooseOrder(String reason, List<String> letters);

  /// 空きマスから配置先を 1 つ選び、索引を返す。
  int? choosePlacementSlot(String reason, SpellLine line, String letter);
}

/// 決定的に振る舞う既定の [Chooser]。
///
/// 「コストが高いカードほど価値がある」という単純な指標で選ぶ。
/// テストの再現性を担保しつつ、AI の初期実装としても十分に機能する。
class HeuristicChooser implements Chooser {
  const HeuristicChooser();

  @override
  int? chooseCard(String reason, List<String> letters) {
    if (letters.isEmpty) return null;
    var best = 0;
    for (var i = 1; i < letters.length; i++) {
      if (cardCatalog[letters[i]]!.cost > cardCatalog[letters[best]]!.cost) {
        best = i;
      }
    }
    return best;
  }

  @override
  int? chooseLineSlot(String reason, SpellLine line) {
    final occupied = line.occupiedIndices;
    if (occupied.isEmpty) return null;
    var best = occupied.first;
    for (final index in occupied) {
      if (cardCatalog[line[index]!]!.cost > cardCatalog[line[best]!]!.cost) {
        best = index;
      }
    }
    return best;
  }

  @override
  List<String> chooseOrder(String reason, List<String> letters) {
    // 順位の昇順に並べるとシークエンスが最も伸びる。
    final sorted = List<String>.of(letters)
      ..sort((a, b) => cardCatalog[a]!.rank.compareTo(cardCatalog[b]!.rank));
    return sorted;
  }

  @override
  int? choosePlacementSlot(String reason, SpellLine line, String letter) {
    final empty = line.emptyIndices;
    return empty.isEmpty ? null : empty.first;
  }
}
