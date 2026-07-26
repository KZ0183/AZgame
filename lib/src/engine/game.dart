/// ターン進行と戦闘の解決。エンジンの入口となるクラス。
library;

import '../data/catalog.g.dart';
import 'board.dart';
import 'detection.dart';
import 'effects.dart';
import 'game_state.dart';
import 'models.dart';

/// 文字を出せなかった理由。
enum PlayError {
  /// その文字が手札にない。
  notInHand,

  /// このターンの母音はもう出している。
  vowelLimitReached,

  /// エナジーが足りない。
  notEnoughEnergy,

  /// 指定したレーンがすでに埋まっている。
  laneOccupied,

  /// すでに決着がついている。
  gameOver,
}

/// レーン 1 本ぶんの戦闘結果。UI の演出に使う。
class LaneCombat {
  const LaneCombat({
    required this.lane,
    required this.attacker,
    required this.power,
    required this.blocker,
    required this.damageToPlayer,
    required this.attackerDestroyed,
    required this.blockerDestroyed,
  });

  final int lane;
  final String attacker;
  final int power;

  /// 対峙していた相手の文字。いなければ `null`。
  final String? blocker;

  /// 相手 LP に通ったダメージ。
  final int damageToPlayer;

  final bool attackerDestroyed;
  final bool blockerDestroyed;

  @override
  String toString() => 'LaneCombat($lane: $attacker($power) '
      'vs ${blocker ?? "本体"} → $damageToPlayer)';
}

/// 1 ターンぶんの戦闘結果。
class CombatResult {
  const CombatResult({required this.lanes, required this.totalDamage});

  final List<LaneCombat> lanes;

  /// 相手 LP に通った合計ダメージ。
  final int totalDamage;

  @override
  String toString() =>
      'CombatResult(${lanes.length} レーン, 合計 $totalDamage ダメージ)';
}

/// 対戦を進行させるエンジン。
class Game {
  Game({
    required this.state,
    required this.firstChooser,
    required this.secondChooser,
    GameLog? log,
  }) : log = log ?? GameLog();

  final GameState state;
  final Chooser firstChooser;
  final Chooser secondChooser;
  final GameLog log;

  Chooser chooserFor(PlayerState player) =>
      identical(player, state.first) ? firstChooser : secondChooser;

  /// 手番プレイヤーの盤面評価。
  BoardView get activeBoard => buildBoard(state.active, state.inactive);

  /// 相手の盤面評価。
  BoardView get inactiveBoard => buildBoard(state.inactive, state.active);

  BoardView boardOf(PlayerState player) =>
      buildBoard(player, state.opponentOf(player));

  /// 対戦を開始する。デッキをシャッフルし、初期手札を配り、先攻の 1 手番目を始める。
  void start() {
    _shuffle(state.first.deck);
    _shuffle(state.second.deck);
    state.first.draw(kStartingHandSize);
    state.second.draw(kStartingHandSize);
    log.add('対戦開始。先攻は ${state.first.name}');
    beginTurn();
  }

  /// 手番プレイヤーのターンを開始する。
  ///
  /// マナ回復 → 召喚酔い解除 → 相手陣形による拘束 → 毎ターン能力 →
  /// 陣形の継続効果 → ドロー の順に処理する。
  void beginTurn() {
    if (state.isOver) return;
    state.turnNumber++;
    final active = state.active;
    final opponent = state.inactive;

    active.vowelsPlayedThisTurn = 0;

    // 前のターンから戦場にいる文字は召喚酔いが解ける。
    for (final permanent in active.field.occupants) {
      permanent.summoningSick = false;
      permanent.frozen = false;
    }

    // マナ。エナジーは持ち越さず、戦場の母音が生む量に戻る。
    active.energy = active.energyIncome;

    // 相手のワード陣形による拘束（FROST など）を受ける。
    _applyFreeze(active, opponent);

    // 毎ターン能力。左のレーンから順に解決する。
    for (final lane in active.field.occupiedIndices) {
      final permanent = active.field[lane];
      if (permanent == null) continue;
      final ability = upkeepAbilities[permanent.letter];
      if (ability == null) continue;
      ability(AbilityContext(
        game: state,
        actor: active,
        opponent: opponent,
        chooser: chooserFor(active),
        log: log,
        lane: lane,
      ));
    }

    // ワード陣形の継続効果のうち、ターン開始時に働くもの。
    final effect = boardOf(active).effect;
    if (effect.upkeepDamage > 0) {
      dealDamage(opponent, effect.upkeepDamage, log: log);
    }
    if (effect.upkeepHeal > 0) active.heal(effect.upkeepHeal);
    if (effect.upkeepShield > 0) active.gainShield(effect.upkeepShield);
    if (effect.upkeepEnergy > 0) active.gainEnergy(effect.upkeepEnergy);
    if (effect.upkeepDraw > 0) active.draw(effect.upkeepDraw);

    // 先攻の 1 手番目はドローしない。MTG と同じ先攻有利の是正。
    if (state.turnNumber > 1) active.draw(1);
    _cleanUpDestroyed();

    log.add('--- 手番 ${state.turnNumber}: ${active.name} '
        '(E ${active.energy}) ---');
  }

  /// 相手のワード陣形が持つ拘束を、手番プレイヤーの文字に割り当てる。
  ///
  /// パワーの高い文字から順に止める。放っておけば一番痛い文字を止めるのが
  /// 拘束側の意図に沿うため。
  void _applyFreeze(PlayerState active, PlayerState opponent) {
    final freeze = boardOf(opponent).effect.freeze;
    if (freeze <= 0) return;

    final board = boardOf(active);
    final lanes = active.field.occupiedIndices
      ..sort((a, b) => board.powerOf(b).compareTo(board.powerOf(a)));
    for (final lane in lanes.take(freeze)) {
      active.field[lane]!.frozen = true;
    }
    if (lanes.isNotEmpty) {
      log.add('${active.name} の文字 ${lanes.take(freeze).length} 体が拘束された');
    }
  }

  /// [letter] を [lane] に出せるか判定する。出せるなら `null` を返す。
  PlayError? validatePlay(String letter, int lane) {
    if (state.isOver) return PlayError.gameOver;
    final active = state.active;
    if (!active.hand.contains(letter)) return PlayError.notInHand;
    if (!active.field.isEmptyAt(lane)) return PlayError.laneOccupied;

    final card = cardCatalog[letter]!;
    if (card.isVowel) {
      if (!active.canPlayVowel) return PlayError.vowelLimitReached;
      return null;
    }
    if (active.energy < card.cost) return PlayError.notEnoughEnergy;
    return null;
  }

  /// 手番プレイヤーが [letter] を [lane] に出す。
  ///
  /// 母音はエナジーを消費せず、出た瞬間から生産を始める（MTG の土地と同じ）。
  /// 子音はエナジーを支払う。どちらも登場時能力が即座に発動する。
  void playCard(String letter, int lane) {
    final error = validatePlay(letter, lane);
    if (error != null) {
      throw StateError('$letter をレーン $lane に出せません: $error');
    }

    final active = state.active;
    final card = cardCatalog[letter]!;

    active.hand.remove(letter);
    if (card.isVowel) {
      active.vowelsPlayedThisTurn++;
      // 出したターンからマナを生む。
      active.gainEnergy(card.energyProduced);
    } else {
      active.energy -= card.cost;
    }

    active.field.place(lane, Permanent(letter));
    log.add('${active.name} が $letter をレーン $lane に出した');

    final ability = onPlayAbilities[letter];
    if (ability != null) {
      ability(AbilityContext(
        game: state,
        actor: active,
        opponent: state.inactive,
        chooser: chooserFor(active),
        log: log,
        lane: lane,
      ));
    }
    _cleanUpDestroyed();
  }

  /// ターンを終了する。戦闘を解決し、手番を相手に渡す。
  CombatResult endTurn() {
    final result = resolveCombat();
    _clearDamage();
    _enforceHandLimit(state.active);

    if (!state.isOver) {
      state.isFirstPlayerTurn = !state.isFirstPlayerTurn;
      beginTurn();
    }
    return result;
  }

  /// 戦闘フェイズ。攻撃可能な自分の文字が一斉にレーンを攻撃する。
  ///
  /// 攻撃するかどうかの選択もブロッカーの宣言もない。誰と戦うかはレーンで
  /// 自動的に決まる（docs/game-design.md 6 章）。
  CombatResult resolveCombat() {
    final attacker = state.active;
    final defender = state.inactive;
    final attackerBoard = buildBoard(attacker, defender);
    final defenderBoard = buildBoard(defender, attacker);

    final lanes = <LaneCombat>[];
    var totalDamage = 0;

    for (var lane = 0; lane < Battlefield.laneCount; lane++) {
      final myPermanent = attacker.field[lane];
      if (myPermanent == null) continue;
      if (!attackerBoard.canAttack(lane)) continue;

      final power = attackerBoard.powerOf(lane);
      final blocker = defender.field[lane];

      if (blocker == null || attackerBoard.piercesAt(lane)) {
        final dealt = dealDamage(defender, power, log: log);
        totalDamage += dealt;
        lanes.add(LaneCombat(
          lane: lane,
          attacker: myPermanent.letter,
          power: power,
          blocker: blocker?.letter,
          damageToPlayer: dealt,
          attackerDestroyed: false,
          blockerDestroyed: false,
        ));
        continue;
      }

      // 対峙している場合は互いにダメージを与え合う。
      final toBlocker = power - defenderBoard.damageReductionAt(lane);
      final toAttacker =
          defenderBoard.powerOf(lane) - attackerBoard.damageReductionAt(lane);
      if (toBlocker > 0) blocker.damage += toBlocker;
      if (toAttacker > 0) myPermanent.damage += toAttacker;

      lanes.add(LaneCombat(
        lane: lane,
        attacker: myPermanent.letter,
        power: power,
        blocker: blocker.letter,
        damageToPlayer: 0,
        attackerDestroyed:
            myPermanent.damage >= attackerBoard.toughnessOf(lane),
        blockerDestroyed: blocker.damage >= defenderBoard.toughnessOf(lane),
      ));
    }

    _cleanUpDestroyed(
      attackerBoard: attackerBoard,
      defenderBoard: defenderBoard,
    );

    return CombatResult(lanes: lanes, totalDamage: totalDamage);
  }

  /// タフネスを超えるダメージを負った文字を、両者の戦場から取り除く。
  void _cleanUpDestroyed({
    BoardView? attackerBoard,
    BoardView? defenderBoard,
  }) {
    final activeBoardView = attackerBoard ?? boardOf(state.active);
    final inactiveBoardView = defenderBoard ?? boardOf(state.inactive);

    for (final destroyed
        in state.active.removeDestroyed(activeBoardView.toughnessResolver)) {
      log.add('${state.active.name} の $destroyed が破壊された');
    }
    for (final destroyed
        in state.inactive.removeDestroyed(inactiveBoardView.toughnessResolver)) {
      log.add('${state.inactive.name} の $destroyed が破壊された');
    }
  }

  /// 蓄積したダメージを回復する。MTG と同じくターンをまたいで残らない。
  void _clearDamage() {
    for (final player in [state.first, state.second]) {
      for (final permanent in player.field.occupants) {
        permanent.damage = 0;
      }
    }
  }

  void _enforceHandLimit(PlayerState player) {
    while (player.hand.length > kHandLimit) {
      final index =
          chooserFor(player).chooseCard('手札上限を超過。捨てるカード', player.hand) ??
              player.hand.length - 1;
      player.discardAt(index);
    }
  }

  void _shuffle(List<String> cards) {
    for (var i = cards.length - 1; i > 0; i--) {
      final j = state.rng.nextInt(i + 1);
      final temp = cards[i];
      cards[i] = cards[j];
      cards[j] = temp;
    }
  }
}

/// 陣形の検出を外部から使いやすくするための再輸出。
Formations formationsOf(Battlefield field) => findFormations(field);
