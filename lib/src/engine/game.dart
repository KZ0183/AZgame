/// ルールエンジン。
///
/// スマホで遊べることを最優先に、MTG から次の 3 つを外している。
/// 土地（マナは自動）、ブロック（攻撃側が対象を選ぶ）、攻撃の一括宣言
/// （1 体ずつ即座に解決する）。
library;

import 'dart:math';

import '../data/catalog.g.dart';
import 'models.dart';

const int kStartingLife = 20;
const int kStartingHand = 4;
const int kHandLimit = 8;
const int kDeckSize = 30;

/// マナ上限。ターンごとに 1 ずつ増え、ここで頭打ちになる。
const int kMaxMana = 10;

/// 場に出せるクリーチャーの上限。盤面が横に伸びすぎると画面に収まらない。
const int kFieldLimit = 6;

enum PlayError { notInHand, notEnoughMana, fieldFull, gameOver }

enum AttackError { notYourCreature, alreadyAttacked, summoningSick, gameOver }

class PlayerState {
  PlayerState({required this.name, required List<String> deck})
      : library = List<String>.of(deck);

  final String name;

  int life = kStartingLife;

  /// このターン使えるマナ。ターン開始時に上限まで回復する。
  int mana = 0;

  /// マナ上限。自分のターンが来るたびに 1 増える。
  int maxMana = 0;

  final List<String> library;
  final List<String> hand = [];
  final List<String> graveyard = [];
  final List<Permanent> creatures = [];

  /// 後攻に配られる先攻補正。最初の自分のターンに 1 度だけマナが 1 増える。
  /// ブロックがないぶん先攻の押し込みが強く、これがないと大きく傾く。
  bool hasCoin = false;

  bool deckedOut = false;

  bool get isDefeated => life <= 0 || deckedOut;

  /// 攻撃できるクリーチャー。
  List<Permanent> get readyAttackers => creatures
      .where((c) => !c.attacked && !c.summoningSick)
      .toList();

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

  /// 死亡したクリーチャーを墓地へ送る。
  List<String> removeDead() {
    final dead = <String>[];
    creatures.removeWhere((creature) {
      if (creature.damage < cardCatalog[creature.letter]!.toughness) {
        return false;
      }
      graveyard.add(creature.letter);
      dead.add(creature.letter);
      return true;
    });
    return dead;
  }

  @override
  String toString() =>
      '$name(ライフ $life, マナ $mana/$maxMana, 場 ${creatures.join()})';
}

/// 攻撃 1 回の結果。
class AttackResult {
  const AttackResult({
    required this.attacker,
    required this.target,
    required this.damageToPlayer,
    required this.attackerDied,
    required this.targetDied,
  });

  final String attacker;

  /// 攻撃した相手のクリーチャー。本体を殴った場合は `null`。
  final String? target;

  final int damageToPlayer;
  final bool attackerDied;
  final bool targetDied;
}

class GameLog {
  final List<String> entries = [];
  void add(String message) => entries.add(message);
}

class Game {
  Game({
    required this.first,
    required this.second,
    Random? rng,
    GameLog? log,
  })  : rng = rng ?? Random(),
        log = log ?? GameLog();

  final PlayerState first;
  final PlayerState second;
  final Random rng;
  final GameLog log;

  int turnNumber = 0;
  bool isFirstPlayerTurn = true;

  PlayerState get active => isFirstPlayerTurn ? first : second;
  PlayerState get inactive => isFirstPlayerTurn ? second : first;

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
    // 後攻は 1 枚多く引き、さらにコイン（初回のみマナ +1）を得る。
    second.draw(kStartingHand + 1);
    second.hasCoin = true;
    log.add('対戦開始');
    beginTurn();
  }

  /// ターンを開始する。マナ回復 → ドローの順。
  void beginTurn() {
    if (isOver) return;
    turnNumber++;
    final player = active;

    // マナは自動で増える。土地を置く操作はない。
    player.maxMana = min(player.maxMana + 1, kMaxMana);
    player.mana = player.maxMana;
    if (player.hasCoin) {
      player.hasCoin = false;
      player.mana += 1;
      log.add('${player.name} はコインを使った（マナ +1）');
    }

    for (final creature in player.creatures) {
      creature.attacked = false;
      creature.summoningSick = false;
    }

    // 先攻の 1 ターン目はドローしない。
    if (turnNumber > 1) player.draw(1);

    log.add('--- ターン $turnNumber: ${player.name} (マナ ${player.mana}) ---');
  }

  PlayError? validatePlay(String letter) {
    if (isOver) return PlayError.gameOver;
    final player = active;
    if (!player.hand.contains(letter)) return PlayError.notInHand;
    if (player.creatures.length >= kFieldLimit) return PlayError.fieldFull;
    if (player.mana < cardCatalog[letter]!.cost) return PlayError.notEnoughMana;
    return null;
  }

  /// 手札からクリーチャーを出す。
  void play(String letter) {
    final error = validatePlay(letter);
    if (error != null) throw StateError('$letter を出せません: $error');

    final player = active;
    final card = cardCatalog[letter]!;
    player.hand.remove(letter);
    player.mana -= card.cost;
    player.creatures.add(Permanent(letter));
    log.add('${player.name} が $letter (${card.power}/${card.toughness}) を出した');
  }

  AttackError? validateAttack(Permanent attacker) {
    if (isOver) return AttackError.gameOver;
    if (!active.creatures.contains(attacker)) {
      return AttackError.notYourCreature;
    }
    if (attacker.attacked) return AttackError.alreadyAttacked;
    if (attacker.summoningSick) return AttackError.summoningSick;
    return null;
  }

  /// [attacker] で攻撃する。[target] が `null` なら相手本体を殴る。
  ///
  /// ブロックはない。攻撃した側が対象を選び、その場で解決する。
  AttackResult attack(Permanent attacker, Permanent? target) {
    final error = validateAttack(attacker);
    if (error != null) throw StateError('攻撃できません: $error');

    final me = active;
    final foe = inactive;
    final card = cardCatalog[attacker.letter]!;
    attacker.attacked = true;

    if (target == null) {
      foe.life -= card.power;
      log.add('${me.name} の ${attacker.letter} が本体に ${card.power} ダメージ'
          '（残り ${foe.life}）');
      return AttackResult(
        attacker: attacker.letter,
        target: null,
        damageToPlayer: card.power,
        attackerDied: false,
        targetDied: false,
      );
    }

    final targetCard = cardCatalog[target.letter]!;
    target.damage += card.power;
    attacker.damage += targetCard.power;

    final targetDied = target.damage >= targetCard.toughness;
    final attackerDied = attacker.damage >= card.toughness;

    log.add('${me.name} の ${attacker.letter} が ${target.letter} を攻撃');
    for (final dead in me.removeDead()) {
      log.add('${me.name} の $dead が倒れた');
    }
    for (final dead in foe.removeDead()) {
      log.add('${foe.name} の $dead が倒れた');
    }

    return AttackResult(
      attacker: attacker.letter,
      target: target.letter,
      damageToPlayer: 0,
      attackerDied: attackerDied,
      targetDied: targetDied,
    );
  }

  /// ターンを終了し、手番を渡す。
  void endTurn() {
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
