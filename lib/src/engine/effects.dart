/// 文字カードの能力の実装。
///
/// 常在能力（`A` `D` `E` `K` `L` `M` `P` `R` `S` `T`）はステータス計算に
/// 織り込まれているため board.dart 側にあり、ここには現れない。
/// ここにあるのは毎ターン発動する能力と、登場時に 1 回だけ発動する能力。
library;

import 'detection.dart';
import 'game_state.dart';
import 'models.dart';

/// 相手 LP にダメージを与える。シールドが先に削られる。
///
/// 実際に LP を削った量を返す。
int dealDamage(PlayerState target, int amount, {GameLog? log}) {
  if (amount <= 0) return 0;
  var remaining = amount;

  if (target.shield > 0) {
    final absorbed = remaining < target.shield ? remaining : target.shield;
    target.shield -= absorbed;
    remaining -= absorbed;
  }
  if (remaining <= 0) return 0;

  target.lp -= remaining;
  log?.add('${target.name} に $remaining ダメージ（残り LP ${target.lp}）');
  return remaining;
}

/// 能力の解決中に参照できる文脈。
class AbilityContext {
  AbilityContext({
    required this.game,
    required this.actor,
    required this.opponent,
    required this.chooser,
    required this.log,
    required this.lane,
  });

  final GameState game;

  /// 能力を持つ文字の持ち主。
  final PlayerState actor;

  /// その対戦相手。
  final PlayerState opponent;

  final Chooser chooser;
  final GameLog log;

  /// 能力を持つ文字がいるレーン。
  final int lane;
}

/// 自分のターン開始時に毎回発動する能力。キーは文字。
final Map<String, void Function(AbilityContext)> upkeepAbilities = {
  'B': (ctx) => ctx.actor.gainShield(2),
  'C': (ctx) {
    if (ctx.actor.hand.length <= 3) ctx.actor.draw(1);
  },
  'F': (ctx) => dealDamage(ctx.opponent, 2, log: ctx.log),
  'G': (ctx) => ctx.actor.gainEnergy(1),
  'H': (ctx) => ctx.actor.heal(2),
  'I': (ctx) {
    if (ctx.actor.field.count >= 3) ctx.actor.draw(1);
  },
  'N': _nullStrike,
  'V': (ctx) => ctx.actor.gainEnergy(2),
  'Y': (ctx) {
    ctx.actor.lp -= 1;
    ctx.actor.draw(1);
  },
  'Z': (ctx) => dealDamage(ctx.opponent, 3, log: ctx.log),
};

/// 戦場に出た瞬間に 1 回だけ発動する能力。キーは文字。
final Map<String, void Function(AbilityContext)> onPlayAbilities = {
  'J': _destroyOne,
  'O': _reorderOwnField,
  'Q': _quest,
  'U': _returnFromGraveyard,
  'W': _shiftOpposingField,
  'X': _crossDamage,
};

// --- 個別実装 -------------------------------------------------------------

/// `N`（ヌル）— 相手が陣形を持っているなら 2 ダメージ。
///
/// 安価な文字が「陣形に頼る相手」への牽制として機能するよう設計している。
void _nullStrike(AbilityContext ctx) {
  if (findFormations(ctx.opponent.field).isEmpty) return;
  dealDamage(ctx.opponent, 2, log: ctx.log);
}

/// `J`（ジョルト）— 相手の文字 1 体を破壊する。
void _destroyOne(AbilityContext ctx) {
  final lane = ctx.chooser.chooseLane('破壊する相手の文字', ctx.opponent.field);
  if (lane == null) return;
  final destroyed = ctx.opponent.destroyAt(lane);
  if (destroyed != null) {
    ctx.log.add('${ctx.opponent.name} の $destroyed を破壊');
  }
}

/// `O`（オービット）— 自分の戦場の文字を好きな順に並べ替える。
void _reorderOwnField(AbilityContext ctx) {
  final field = ctx.actor.field;
  final occupants = field.occupants;
  if (occupants.length < 2) return;
  final ordered = ctx.chooser.chooseOrder('戦場の並べ替え', occupants);
  if (ordered.length != occupants.length) return;
  field.reorder(ordered);
}

/// `Q`（クエスト）— 手札をすべて捨て、4 枚ドローする。
void _quest(AbilityContext ctx) {
  final actor = ctx.actor;
  actor.graveyard.addAll(actor.hand);
  actor.hand.clear();
  actor.draw(4);
}

/// `U`（ユナイト）— 墓地から文字 1 枚を手札に戻す。
void _returnFromGraveyard(AbilityContext ctx) {
  final actor = ctx.actor;
  if (actor.graveyard.isEmpty) return;
  final index =
      ctx.chooser.chooseCard('墓地から手札に戻す 1 枚', actor.graveyard) ?? 0;
  actor.hand.add(actor.graveyard.removeAt(index));
}

/// `W`（ウェーブ）— 相手の戦場を 1 レーン右へずらす。
///
/// 押し出された文字は破壊される。文字を倒さずに陣形だけを崩せる、
/// 本作で唯一の手段になっている。
void _shiftOpposingField(AbilityContext ctx) {
  final field = ctx.opponent.field;
  final shifted = List<Permanent?>.filled(Battlefield.laneCount, null);

  for (var i = Battlefield.laneCount - 1; i >= 0; i--) {
    final permanent = field[i];
    if (permanent == null) continue;
    if (i + 1 >= Battlefield.laneCount) {
      ctx.opponent.graveyard.add(permanent.letter);
      ctx.log.add('${ctx.opponent.name} の ${permanent.letter} が押し出された');
    } else {
      shifted[i + 1] = permanent;
    }
  }

  for (var i = 0; i < Battlefield.laneCount; i++) {
    field.removeAt(i);
    final permanent = shifted[i];
    if (permanent != null) field.place(i, permanent);
  }
}

/// `X`（クロス）— 相手の全ての文字に 4 ダメージ。
void _crossDamage(AbilityContext ctx) {
  for (final permanent in ctx.opponent.field.occupants) {
    permanent.damage += 4;
  }
  ctx.log.add('${ctx.opponent.name} の全文字に 4 ダメージ');
}
