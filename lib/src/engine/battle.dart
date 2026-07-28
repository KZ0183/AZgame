/// 戦闘エンジン。**プレイヤーだけがカードを使い、相手は敵キャラクター。**
///
/// v0.6 までの対称な対戦をやめた版。理由はゲーム性ではなく供給量で、
/// 対称な対戦はカードを増やし続けないとメタが固まって死ぬのに対し、
/// 非対称なら増やすのは敵だけで済む（[EnemyDef] の説明を参照）。
///
/// v0.6 の手触り — マナは自動、ブロックなし、攻撃側が対象を選ぶ — はそのまま。
library;

import 'dart:math';

import '../data/catalog.g.dart';
import 'enemy.dart';
import 'models.dart';

const int kPlayerLife = 30;
const int kStartingHand = 4;
const int kHandLimit = 8;
const int kDeckSize = 30;

/// マナ上限。ターンごとに 1 ずつ増え、ここで頭打ちになる。
const int kMaxMana = 10;

/// 場に出せるミニオンの上限。横に伸びすぎると画面に収まらない。
const int kPlayerFieldLimit = 6;
const int kEnemyFieldLimit = 6;

enum PlayError { notInHand, notEnoughMana, fieldFull, battleOver }

enum AttackError {
  notYourMinion,
  alreadyAttacked,
  summoningSick,

  /// 挑発を持つ敵がいるあいだは、そちらを先に攻撃しなければならない。
  tauntInTheWay,
  battleOver,
}

class BattleLog {
  final List<String> entries = [];
  void add(String message) => entries.add(message);
}

/// 1 体の敵との戦闘。
class Battle {
  Battle({
    required this.enemy,
    required List<String> deck,
    this.playerLife = kPlayerLife,
    Random? rng,
    BattleLog? log,
  })  : library = List<String>.of(deck),
        maxPlayerLife = kPlayerLife,
        enemyLife = enemy.life,
        rng = rng ?? Random(),
        log = log ?? BattleLog();

  final EnemyDef enemy;
  final Random rng;
  final BattleLog log;

  int playerLife;
  final int maxPlayerLife;
  int enemyLife;

  /// 敵が [EnemyActionKind.empower] で溜めたぶん。以降の一撃に上乗せされる。
  int enemyBonusPower = 0;

  int mana = 0;
  int maxMana = 0;

  final List<String> library;
  final List<String> hand = [];
  final List<String> graveyard = [];
  final List<Minion> playerMinions = [];
  final List<Minion> enemyMinions = [];

  /// プレイヤーの手番の数。
  int turn = 0;

  /// 山札が尽きたあとのドローで受ける疲労ダメージ。引くたびに 1 増える。
  int fatigue = 0;

  int _patternIndex = 0;

  /// 敵が次の自分の手番に行うこと。**常に見えている。**
  /// 運ではなく読みで解く相手にするための中核。
  EnemyAction get nextAction =>
      enemy.pattern[_patternIndex % enemy.pattern.length];

  String get nextActionLabel => nextAction.label(enemyBonusPower);

  bool get playerWon => enemyLife <= 0;
  bool get playerLost => playerLife <= 0;
  bool get isOver => playerWon || playerLost;

  /// 攻撃できるミニオン。
  List<Minion> get readyAttackers =>
      playerMinions.where((m) => m.canAttack).toList();

  /// 敵側の挑発持ち。いる間は本体もほかの雑魚も殴れない。
  List<Minion> get enemyTaunts => enemyMinions.where((m) => m.hasTaunt).toList();

  List<Minion> get playerTaunts =>
      playerMinions.where((m) => m.hasTaunt).toList();

  void start() {
    _shuffle(library);
    _draw(kStartingHand);
    log.add('${enemy.name}（ライフ ${enemy.life}）が現れた');
    beginTurn();
  }

  /// プレイヤーの手番を開始する。マナ回復 → ドローの順。
  void beginTurn() {
    if (isOver) return;
    turn++;

    mana = maxMana = min(maxMana + 1, kMaxMana);
    for (final minion in playerMinions) {
      minion.attacked = false;
      minion.summoningSick = false;
    }
    _draw(1);

    log.add('--- $turn ターン目（マナ $mana） ---');
  }

  // --- カードを出す ------------------------------------------------------

  PlayError? validatePlay(String kana) {
    if (isOver) return PlayError.battleOver;
    if (!hand.contains(kana)) return PlayError.notInHand;
    if (playerMinions.length >= kPlayerFieldLimit) return PlayError.fieldFull;
    if (mana < cardCatalog[kana]!.cost) return PlayError.notEnoughMana;
    return null;
  }

  void play(String kana) {
    final error = validatePlay(kana);
    if (error != null) throw StateError('$kana を出せません: $error');

    final card = cardCatalog[kana]!;
    hand.remove(kana);
    mana -= card.cost;
    playerMinions.add(Minion(card));
    log.add('$kana (${card.statLine}) を出した');
    _resolveOnPlay(card);
  }

  void _resolveOnPlay(KanaCard card) {
    switch (card.onPlay) {
      case OnPlay.none:
        break;
      case OnPlay.snipe:
        final target = _snipeTarget(card.onPlayValue);
        if (target == null) {
          log.add('${card.kana} の一撃は空を切った');
          break;
        }
        target.damage += card.onPlayValue;
        log.add('${card.kana} が ${target.kana} に ${card.onPlayValue} ダメージ');
        _clearDead();
      case OnPlay.draw:
        _draw(card.onPlayValue);
      case OnPlay.heal:
        final healed = min(card.onPlayValue, maxPlayerLife - playerLife);
        playerLife += healed;
        log.add('ライフを $healed 回復した（$playerLife）');
    }
  }

  /// 狙撃の対象。倒せる相手がいればその中で最も重いもの、いなければ最も削れているもの。
  ///
  /// 選択 UI がないので自動で決める。プレイヤー・AI とも同じ規則を使う。
  Minion? _snipeTarget(int damage) {
    if (enemyMinions.isEmpty) return null;
    final killable = enemyMinions.where((m) => m.remaining <= damage).toList();
    if (killable.isNotEmpty) {
      killable.sort((a, b) => b.card.cost.compareTo(a.card.cost));
      return killable.first;
    }
    final sorted = List<Minion>.of(enemyMinions)
      ..sort((a, b) => a.remaining.compareTo(b.remaining));
    return sorted.first;
  }

  // --- 攻撃 --------------------------------------------------------------

  AttackError? validateAttack(Minion attacker, {Minion? target}) {
    if (isOver) return AttackError.battleOver;
    if (!playerMinions.contains(attacker)) return AttackError.notYourMinion;
    if (attacker.attacked) return AttackError.alreadyAttacked;
    if (attacker.summoningSick) return AttackError.summoningSick;
    if (enemyTaunts.isNotEmpty && (target == null || !target.hasTaunt)) {
      return AttackError.tauntInTheWay;
    }
    return null;
  }

  /// [attacker] で攻撃する。[target] が `null` なら敵本体を殴る。
  void attack(Minion attacker, Minion? target) {
    final error = validateAttack(attacker, target: target);
    if (error != null) throw StateError('攻撃できません: $error');

    attacker.attacked = true;
    final card = attacker.card;

    if (target == null) {
      _damageEnemy(card.power);
      log.add('${attacker.kana} が本体に ${card.power} ダメージ（残り $enemyLife）');
      if (card.has(Keyword.lifesteal)) _heal(card.power);
      return;
    }

    final dealt = min(card.power, target.remaining);
    target.damage += card.power;
    attacker.damage += target.card.power;
    log.add('${attacker.kana} が ${target.kana} を攻撃');

    var total = dealt;
    if (card.has(Keyword.pierce) && target.isDead) {
      final excess = card.power - dealt;
      if (excess > 0) {
        _damageEnemy(excess);
        total += excess;
        log.add('貫通で本体に $excess ダメージ（残り $enemyLife）');
      }
    }
    if (card.has(Keyword.lifesteal)) _heal(total);
    _clearDead();
  }

  void _damageEnemy(int amount) {
    enemyLife -= amount;
    if (enemyLife <= 0) log.add('${enemy.name} を倒した');
  }

  void _heal(int amount) {
    final healed = min(amount, maxPlayerLife - playerLife);
    if (healed <= 0) return;
    playerLife += healed;
    log.add('絆魂でライフを $healed 回復（$playerLife）');
  }

  // --- ターンを渡す ------------------------------------------------------

  /// プレイヤーの手番を終え、敵の手番を解決してから次の手番を始める。
  void endTurn() {
    while (hand.length > kHandLimit) {
      graveyard.add(hand.removeLast());
    }
    if (isOver) return;
    _enemyTurn();
    beginTurn();
  }

  void _enemyTurn() {
    final action = nextAction;
    _patternIndex++;

    switch (action.kind) {
      case EnemyActionKind.summon:
        for (final kana in action.summons) {
          if (enemyMinions.length >= kEnemyFieldLimit) break;
          enemyMinions.add(Minion(cardCatalog[kana]!, summoningSick: true));
        }
        log.add('${enemy.name} が ${action.summons.join('・')} を呼んだ');
      case EnemyActionKind.strike:
        _enemyStrike(action.value + enemyBonusPower);
      case EnemyActionKind.sweep:
        for (final minion in playerMinions) {
          minion.damage += action.value;
        }
        log.add('${enemy.name} の薙ぎ払い。こちら全体に ${action.value} ダメージ');
        _clearDead();
      case EnemyActionKind.empower:
        enemyBonusPower += action.value;
        log.add('${enemy.name} が力を溜めた（一撃 +${action.value}）');
      case EnemyActionKind.heal:
        enemyLife = min(enemy.life, enemyLife + action.value);
        log.add('${enemy.name} がライフを ${action.value} 回復した（$enemyLife）');
    }

    for (final minion in List<Minion>.of(enemyMinions)) {
      if (isOver) break;
      if (!minion.canAttack || minion.isDead) continue;
      _enemyMinionAttack(minion);
    }

    for (final minion in enemyMinions) {
      minion.attacked = false;
      minion.summoningSick = false;
    }
  }

  /// 本体の一撃。**挑発では防げない。**
  ///
  /// ここを壁で受けられるようにすると、挑発と絆魂を並べただけで敵の攻め手が
  /// 全部消え、時間さえかければ必ず勝つ盤面になってしまう（実測で確認した）。
  /// 本体の一撃だけは必ず通ることで、どのデッキにも「間に合うか」の締切ができる。
  void _enemyStrike(int amount) {
    playerLife -= amount;
    log.add('${enemy.name} の一撃で $amount ダメージ（残り $playerLife）');
  }

  void _enemyMinionAttack(Minion attacker) {
    attacker.attacked = true;
    final card = attacker.card;
    final target = _pickPlayerTarget();

    if (target == null) {
      playerLife -= card.power;
      log.add('敵の ${attacker.kana} の攻撃で ${card.power} ダメージ（残り $playerLife）');
      return;
    }

    final dealt = min(card.power, target.remaining);
    target.damage += card.power;
    attacker.damage += target.card.power;
    log.add('敵の ${attacker.kana} が ${target.kana} を攻撃');

    if (card.has(Keyword.pierce) && target.isDead) {
      final excess = card.power - dealt;
      if (excess > 0) playerLife -= excess;
    }
    _clearDead();
  }

  /// 雑魚が殴る相手。挑発がいればその中で最も硬いもの、いなければ `null`（本体）。
  Minion? _pickPlayerTarget() {
    final taunts = playerTaunts.where((m) => !m.isDead).toList();
    if (taunts.isEmpty) return null;
    taunts.sort((a, b) => b.remaining.compareTo(a.remaining));
    return taunts.first;
  }

  // --- 雑務 --------------------------------------------------------------

  void _clearDead() {
    playerMinions.removeWhere((minion) {
      if (!minion.isDead) return false;
      graveyard.add(minion.kana);
      log.add('${minion.kana} が倒れた');
      return true;
    });
    enemyMinions.removeWhere((minion) {
      if (!minion.isDead) return false;
      log.add('敵の ${minion.kana} が倒れた');
      return true;
    });
  }

  void _draw(int count) {
    for (var i = 0; i < count; i++) {
      if (library.isEmpty) {
        fatigue++;
        playerLife -= fatigue;
        log.add('山札が尽きた。疲労で $fatigue ダメージ（残り $playerLife）');
        continue;
      }
      hand.add(library.removeAt(0));
    }
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
