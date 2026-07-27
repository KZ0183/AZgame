/// 初期 MTG を単純化したルールエンジン。
library;

import 'dart:math';

import '../data/catalog.g.dart';
import 'models.dart';

const int kStartingLife = 20;
const int kStartingHand = 7;
const int kHandLimit = 7;
const int kDeckSize = 30;

/// カードを唱えられなかった理由。
enum PlayError { notInHand, landAlreadyPlayed, notEnoughMana, gameOver }

/// 対戦者ひとりぶんの状態。
class PlayerState {
  PlayerState({required this.name, required List<String> deck})
      : library = List<String>.of(deck);

  final String name;

  int life = kStartingLife;

  /// 山札。索引 0 が一番上。
  final List<String> library;
  final List<String> hand = [];
  final List<String> graveyard = [];

  /// 戦場の土地とクリーチャー。
  final List<Permanent> lands = [];
  final List<Permanent> creatures = [];

  /// このターンすでに土地を置いたか。
  bool landPlayedThisTurn = false;

  bool deckedOut = false;

  bool get isDefeated => life <= 0 || deckedOut;

  /// 今すぐ使えるマナ。アンタップ状態の土地の数。
  int get availableMana => lands.where((land) => !land.tapped).length;

  List<String> draw(int count) {
    final drawn = <String>[];
    for (var i = 0; i < count; i++) {
      if (library.isEmpty) {
        deckedOut = true;
        break;
      }
      final card = library.removeAt(0);
      hand.add(card);
      drawn.add(card);
    }
    return drawn;
  }

  /// [amount] ぶんの土地をタップしてマナを支払う。
  void payMana(int amount) {
    var remaining = amount;
    for (final land in lands) {
      if (remaining == 0) break;
      if (land.tapped) continue;
      land.tapped = true;
      remaining--;
    }
    if (remaining > 0) throw StateError('マナが足りません');
  }

  /// 攻撃できるクリーチャー。
  List<Permanent> get readyAttackers =>
      creatures.where((c) => !c.summoningSick && !c.tapped).toList();

  /// ブロックできるクリーチャー。タップ状態のものはブロックできない。
  List<Permanent> get readyBlockers =>
      creatures.where((c) => !c.tapped).toList();

  /// タフネス以上のダメージを受けたクリーチャーを墓地へ送る。
  List<String> removeDead() {
    final dead = <String>[];
    creatures.removeWhere((creature) {
      final card = cardCatalog[creature.letter]!;
      if (creature.damage < card.toughness) return false;
      graveyard.add(creature.letter);
      dead.add(creature.letter);
      return true;
    });
    return dead;
  }

  @override
  String toString() => '$name(ライフ $life, 土地 ${lands.length}, '
      'クリーチャー ${creatures.map((c) => c.letter).join()})';
}

/// ブロックの割り当てを決める関数。
///
/// 攻撃してきたクリーチャーごとに、ブロックに使うクリーチャーを返す。
/// 割り当てないものは `null`。1 体のブロッカーは 1 体しかブロックできない。
typedef BlockChooser = Map<Permanent, Permanent?> Function(
  List<Permanent> attackers,
  List<Permanent> blockers,
);

/// 1 体ぶんの戦闘結果。
class CombatLine {
  const CombatLine({
    required this.attacker,
    required this.blocker,
    required this.damageToPlayer,
  });

  final String attacker;
  final String? blocker;
  final int damageToPlayer;
}

/// 1 回の戦闘の結果。
class CombatResult {
  const CombatResult({required this.lines, required this.totalDamage});

  final List<CombatLine> lines;
  final int totalDamage;
}

class GameLog {
  final List<String> entries = [];
  void add(String message) => entries.add(message);
}

/// 対戦を進行させるエンジン。
class Game {
  Game({
    required this.first,
    required this.second,
    required this.firstBlocker,
    required this.secondBlocker,
    Random? rng,
    GameLog? log,
  })  : rng = rng ?? Random(),
        log = log ?? GameLog();

  final PlayerState first;
  final PlayerState second;

  /// それぞれのプレイヤーがブロックを決める方法。
  final BlockChooser firstBlocker;
  final BlockChooser secondBlocker;

  final Random rng;
  final GameLog log;

  int turnNumber = 0;
  bool isFirstPlayerTurn = true;

  PlayerState get active => isFirstPlayerTurn ? first : second;
  PlayerState get inactive => isFirstPlayerTurn ? second : first;

  BlockChooser get _activeBlocker =>
      isFirstPlayerTurn ? secondBlocker : firstBlocker;

  bool get isOver => first.isDefeated || second.isDefeated;

  PlayerState? get winner {
    if (!isOver) return null;
    if (first.isDefeated && second.isDefeated) return null;
    return first.isDefeated ? second : first;
  }

  void start() {
    _shuffle(first.library);
    _shuffle(second.library);
    first.draw(kStartingHand);
    second.draw(kStartingHand);
    log.add('対戦開始');
    beginTurn();
  }

  /// ターンを開始する。アンタップ → ドローの順。
  void beginTurn() {
    if (isOver) return;
    turnNumber++;
    final player = active;

    for (final permanent in [...player.lands, ...player.creatures]) {
      permanent.tapped = false;
      permanent.summoningSick = false;
    }
    player.landPlayedThisTurn = false;

    // 先攻の 1 ターン目はドローしない。
    if (turnNumber > 1) player.draw(1);

    log.add('--- ターン $turnNumber: ${player.name} ---');
  }

  PlayError? validatePlay(String letter) {
    if (isOver) return PlayError.gameOver;
    final player = active;
    if (!player.hand.contains(letter)) return PlayError.notInHand;
    final card = cardCatalog[letter]!;
    if (card.isLand) {
      return player.landPlayedThisTurn ? PlayError.landAlreadyPlayed : null;
    }
    return player.availableMana < card.cost ? PlayError.notEnoughMana : null;
  }

  /// 手札から [letter] を戦場に出す。
  void play(String letter) {
    final error = validatePlay(letter);
    if (error != null) throw StateError('$letter を出せません: $error');

    final player = active;
    final card = cardCatalog[letter]!;
    player.hand.remove(letter);

    if (card.isLand) {
      player.landPlayedThisTurn = true;
      // 土地は召喚酔いの影響を受けない。
      player.lands.add(Permanent(letter)..summoningSick = false);
      log.add('${player.name} が土地 $letter を置いた');
    } else {
      player.payMana(card.cost);
      player.creatures.add(Permanent(letter));
      log.add('${player.name} が $letter (${card.power}/${card.toughness}) を唱えた');
    }
  }

  /// 戦闘。[attackers] で攻撃を宣言し、防御側がブロックを割り当てる。
  CombatResult attack(List<Permanent> attackers) {
    final attacker = active;
    final defender = inactive;

    final declared =
        attackers.where(attacker.readyAttackers.contains).toList();
    for (final creature in declared) {
      creature.tapped = true;
    }

    final blocks = declared.isEmpty
        ? <Permanent, Permanent?>{}
        : _activeBlocker(declared, defender.readyBlockers);

    final lines = <CombatLine>[];
    var totalDamage = 0;
    final usedBlockers = <Permanent>{};

    for (final creature in declared) {
      final card = cardCatalog[creature.letter]!;
      final blocker = blocks[creature];

      if (blocker == null ||
          !defender.readyBlockers.contains(blocker) ||
          !usedBlockers.add(blocker)) {
        defender.life -= card.power;
        totalDamage += card.power;
        lines.add(CombatLine(
          attacker: creature.letter,
          blocker: null,
          damageToPlayer: card.power,
        ));
        continue;
      }

      final blockerCard = cardCatalog[blocker.letter]!;
      blocker.damage += card.power;
      creature.damage += blockerCard.power;
      lines.add(CombatLine(
        attacker: creature.letter,
        blocker: blocker.letter,
        damageToPlayer: 0,
      ));
    }

    for (final dead in attacker.removeDead()) {
      log.add('${attacker.name} の $dead が破壊された');
    }
    for (final dead in defender.removeDead()) {
      log.add('${defender.name} の $dead が破壊された');
    }
    if (totalDamage > 0) {
      log.add('${defender.name} に $totalDamage ダメージ（残り ${defender.life}）');
    }

    return CombatResult(lines: lines, totalDamage: totalDamage);
  }

  /// ターンを終了し、手番を渡す。
  void endTurn() {
    for (final player in [first, second]) {
      for (final creature in player.creatures) {
        creature.damage = 0;
      }
    }
    while (active.hand.length > kHandLimit) {
      active.graveyard.add(active.hand.removeLast());
    }

    if (isOver) return;
    isFirstPlayerTurn = !isFirstPlayerTurn;
    beginTurn();
  }

  void _shuffle(List<String> cards) {
    for (var i = cards.length - 1; i > 0; i--) {
      final j = rng.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
  }
}
