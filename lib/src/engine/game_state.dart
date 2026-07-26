/// 対戦の状態を表すモデル群。
library;

import 'dart:math';

import '../data/catalog.g.dart';
import 'models.dart';

/// 初期ライフポイント。
const int kStartingLp = 60;

/// 初期手札枚数。
const int kStartingHandSize = 5;

/// 手札の上限。ターン終了時に超過分を捨てる。
const int kHandLimit = 8;

/// デッキの枚数。
const int kDeckSize = 30;

/// 1 ターンに無償で出せる母音の枚数。MTG の土地と同じ制約。
const int kVowelsPerTurn = 1;

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

  /// 現在使えるエナジー。ターン開始時に「戦場の母音が生む量」まで回復する。
  int energy = 0;

  /// 山札。索引 0 が一番上。
  final List<String> deck;

  final List<String> hand = [];
  final Battlefield field = Battlefield();
  final List<String> graveyard = [];

  /// このターンすでに母音を出したか。
  int vowelsPlayedThisTurn = 0;

  /// デッキ切れで敗北が確定したか。
  bool deckedOut = false;

  bool get isDefeated => lp <= 0 || deckedOut;

  /// 戦場の母音が毎ターン生み出すエナジーの合計。
  int get energyIncome => field.occupants
      .fold<int>(0, (sum, p) => sum + cardCatalog[p.letter]!.energyProduced);

  /// このターン、まだ母音を無償で出せるか。
  bool get canPlayVowel => vowelsPlayedThisTurn < kVowelsPerTurn;

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

  void heal(int amount) => lp += amount;

  void gainShield(int amount) => shield += amount;

  void gainEnergy(int amount) => energy += amount;

  /// 戦場の指定レーンの文字を墓地へ送る。
  Permanent? destroyAt(int index) {
    final removed = field.removeAt(index);
    if (removed != null) graveyard.add(removed.letter);
    return removed;
  }

  /// 手札の指定索引を捨てる。
  String? discardAt(int index) {
    if (index < 0 || index >= hand.length) return null;
    final card = hand.removeAt(index);
    graveyard.add(card);
    return card;
  }

  /// タフネスを超えるダメージを負っている文字を墓地へ送る。
  ///
  /// [toughnessOf] は陣形や隣接効果を織り込んだ実効タフネスを返す関数。
  List<String> removeDestroyed(int Function(int lane) toughnessOf) {
    final destroyed = <String>[];
    for (final lane in field.occupiedIndices) {
      final permanent = field[lane]!;
      if (permanent.damage >= toughnessOf(lane)) {
        field.removeAt(lane);
        graveyard.add(permanent.letter);
        destroyed.add(permanent.letter);
      }
    }
    return destroyed;
  }

  @override
  String toString() => '$name(LP $lp${shield > 0 ? ' +$shield' : ''}, '
      'E $energy, 場 $field)';
}

/// 対戦全体の状態。
class GameState {
  GameState({
    required this.first,
    required this.second,
    Random? rng,
  }) : rng = rng ?? Random();

  final PlayerState first;
  final PlayerState second;

  /// 乱数源。種を固定すれば対戦を完全に再現できる。
  final Random rng;

  /// 1 から始まる手番番号。両者の手番を通して増加する。
  int turnNumber = 0;

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

  PlayerState opponentOf(PlayerState player) =>
      identical(player, first) ? second : first;
}

/// 対戦中に起きた出来事の記録。UI の演出とデバッグの両方に使う。
class GameLog {
  final List<String> entries = [];

  void add(String message) => entries.add(message);

  @override
  String toString() => entries.join('\n');
}

/// 効果の解決中にプレイヤー（または AI）へ選択を求めるためのインターフェース。
abstract class Chooser {
  /// [letters] から 1 枚選び、その索引を返す。選ばない場合は `null`。
  int? chooseCard(String reason, List<String> letters);

  /// 戦場の埋まっているレーンから 1 つ選び、索引を返す。
  int? chooseLane(String reason, Battlefield field);

  /// [permanents] を任意の順に並べ替えて返す。
  List<Permanent> chooseOrder(String reason, List<Permanent> permanents);
}

/// 決定的に振る舞う既定の [Chooser]。
///
/// 「コストが高いものほど価値がある」という単純な指標で選ぶ。
/// テストの再現性を担保しつつ、AI の補助としても十分に機能する。
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
  int? chooseLane(String reason, Battlefield field) {
    final occupied = field.occupiedIndices;
    if (occupied.isEmpty) return null;
    var best = occupied.first;
    for (final lane in occupied) {
      final here = cardCatalog[field[lane]!.letter]!.cost;
      final bestCost = cardCatalog[field[best]!.letter]!.cost;
      if (here > bestCost) best = lane;
    }
    return best;
  }

  @override
  List<Permanent> chooseOrder(String reason, List<Permanent> permanents) {
    // 順位の昇順に並べると連番陣形が最も伸びる。
    return List<Permanent>.of(permanents)
      ..sort((a, b) =>
          cardCatalog[a.letter]!.rank.compareTo(cardCatalog[b.letter]!.rank));
  }
}
