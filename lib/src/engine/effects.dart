/// 文字カードの固有能力と、コンボワードの効果の実装。
///
/// 効果の「文言」は `data/*.json` を情報源として生成されるが、
/// 「挙動」はここに手で実装する。両者の対応漏れは `test/catalog_test.dart`
/// が検出するため、片方だけ追加した状態では CI が落ちる。
library;

import '../data/catalog.g.dart';
import 'game_state.dart';
import 'models.dart';

/// `T`（タワー）がスペルライン上にあるときのダメージ軽減量。
const int kTowerReduction = 2;

/// ダメージを与える。シールド・軽減・半減をすべて考慮する。
///
/// 処理順は「軽減（`T`）→ 半減（`VEIL`）→ シールド → LP」。
/// [pierce] が真の場合はシールドを無視して LP に直接与える。
/// 実際に LP を削った量を返す。
int dealDamage(
  PlayerState target,
  int amount, {
  bool pierce = false,
  GameLog? log,
}) {
  if (amount <= 0) return 0;
  var remaining = amount;

  if (target.line.slots.contains('T')) {
    remaining -= kTowerReduction;
  }
  if (target.halveIncomingDamage) {
    remaining = remaining ~/ 2;
  }
  if (remaining <= 0) return 0;

  if (!pierce && target.shield > 0) {
    final absorbed = remaining < target.shield ? remaining : target.shield;
    target.shield -= absorbed;
    remaining -= absorbed;
  }

  target.lp -= remaining;
  log?.add('${target.name} に $remaining ダメージ（残り LP ${target.lp}）');
  return remaining;
}

/// 効果解決時に参照できる文脈。
class EffectContext {
  EffectContext({
    required this.game,
    required this.actor,
    required this.opponent,
    required this.chooser,
    required this.log,
  });

  final GameState game;

  /// 効果を発動した側。
  final PlayerState actor;

  /// その対戦相手。
  final PlayerState opponent;

  final Chooser chooser;
  final GameLog log;
}

/// ワード効果の解決中の文脈。効果はダメージと貫通の有無を書き換えられる。
class WordEffectContext extends EffectContext {
  WordEffectContext({
    required super.game,
    required super.actor,
    required super.opponent,
    required super.chooser,
    required super.log,
    required this.word,
    required this.wordIndices,
    required this.damage,
    this.pierce = false,
  });

  final ComboWord word;

  /// このワードが占有しているスペルライン上のマス索引。
  final List<int> wordIndices;

  /// 確定前のダメージ。効果はこれを加減できる。
  int damage;

  /// シールドを無視するか。
  bool pierce;
}

/// 配置時に発動する固有能力。キーは文字。
///
/// `passive` / `onWord` の能力（`K` `L` `T` `A` `E` `P` `S`）は
/// 判定処理の中に織り込まれているため、ここには現れない。
final Map<String, void Function(EffectContext)> cardAbilities = {
  'B': (ctx) => ctx.actor.gainShield(3),
  'C': (ctx) => ctx.actor.draw(1),
  'D': (ctx) => ctx.actor.gainShield(2),
  'F': (ctx) => dealDamage(ctx.opponent, 2, log: ctx.log),
  'G': (ctx) => ctx.actor.gainMaxEnergy(1),
  'H': (ctx) => ctx.actor.heal(3),
  'I': _insight,
  'J': _destroyOneOpposingCard,
  'M': _mirror,
  'N': (ctx) => ctx.opponent.shield = 0,
  'O': _reorderOwnLine,
  'Q': _quest,
  'R': (ctx) => ctx.actor.bonusPlacements += 1,
  'U': _returnFromGraveyard,
  'V': (ctx) => ctx.actor.gainEnergy(2),
  'W': _shiftOpposingLine,
  'X': (ctx) => ctx.opponent.destroyLine(),
  'Y': _yield,
  'Z': (ctx) => dealDamage(ctx.opponent, 10, log: ctx.log),
};

/// コンボワードの効果。キーはワード。
final Map<String, void Function(WordEffectContext)> wordEffects = {
  // 2 文字 — 繋ぎと事故回復
  'GO': (ctx) => ctx.actor.bonusPlacements += 1,
  'ON': (ctx) => ctx.actor.gainEnergy(2),
  'UP': (ctx) => ctx.actor.nextWordBonus += 8,
  'HI': _noExtraEffect,
  'NO': (ctx) => ctx.opponent.negateNextWord = true,
  'ID': (ctx) => ctx.actor.draw(1),
  'OX': _noExtraEffect,
  'AT': (ctx) => _destroyOneOpposingCard(ctx),
  'WE': (ctx) => ctx.actor.draw(2),
  'SO': (ctx) => ctx.actor.gainShield(5),

  // 3 文字 — 主力
  'ACE': _noExtraEffect,
  'ICE': (ctx) => ctx.opponent.restrictPlacements(turns: 1, limit: 1),
  'SUN': (ctx) => ctx.actor.heal(5),
  'WIN': (ctx) {
    if (ctx.opponent.lp <= 15) ctx.damage += 20;
  },
  'FOX': _foxDiscard,
  'JAB': (ctx) => ctx.pierce = true,
  'FIX': (ctx) => ctx.actor.heal(10),
  'ZAP': _noExtraEffect,
  'WAR': _warRemainingPower,
  'KEY': _searchDeck,
  'OAK': (ctx) => ctx.actor.gainShield(12),
  'SKY': (ctx) {
    ctx.actor.draw(2);
    ctx.actor.gainEnergy(2);
  },
  'BUG': (ctx) => ctx.opponent.mill(2),
  'AIR': (ctx) => _reorderOwnLine(ctx),
  'GEM': (ctx) => ctx.actor.gainMaxEnergy(1),
  'MAP': (ctx) => ctx.actor.nextWordBonus += 6,
  'ROT': (ctx) => ctx.opponent.shield = 0,
  'VOW': (ctx) {
    ctx.actor.heal(5);
    ctx.actor.gainShield(5);
  },

  // 4 文字 — 大技
  'FIRE': _noExtraEffect,
  'HEAL': (ctx) => ctx.actor.heal(20),
  'STAR': (ctx) => ctx.actor.draw(2),
  'BOMB': (ctx) => dealDamage(ctx.actor, 4, pierce: true, log: ctx.log),
  'LOCK': (ctx) => ctx.opponent.restrictPlacements(turns: 1, limit: 0),
  'WAVE': (ctx) => ctx.opponent.destroyLine(),
  'GOLD': (ctx) {
    ctx.actor.gainMaxEnergy(2);
    ctx.actor.draw(3);
  },
  'WIND': _windRandomDiscard,
  'RUIN': (ctx) => ctx.opponent.shield = 0,
  'CALM': (ctx) {
    ctx.actor.heal(12);
    ctx.actor.gainShield(12);
  },
  'JINX': (ctx) => ctx.opponent.negateNextWord = true,
  'VEIL': (ctx) => ctx.actor.halveIncomingDamage = true,

  // 5 文字 — 切り札
  'BLAZE': _noExtraEffect,
  'STORM': (ctx) => ctx.opponent.destroyLine(),
  'BRAVE': (ctx) => ctx.actor.heal(10),
  'LIGHT': (ctx) {
    ctx.actor.heal(25);
    ctx.actor.gainShield(15);
  },
  'POWER': _powerRecover,
  'QUEST': (ctx) => ctx.actor.draw(4),
  'FROST': (ctx) => ctx.opponent.restrictPlacements(turns: 2, limit: 1),
  'CROWN': (ctx) {
    ctx.opponent.maxEnergy = (ctx.opponent.maxEnergy - 2).clamp(1, kMaxEnergyCap);
    ctx.opponent.energy = ctx.opponent.energy.clamp(0, ctx.opponent.maxEnergy);
  },
};

// --- 個別実装 -------------------------------------------------------------

/// 固有ダメージのみで追加効果を持たないワード。
void _noExtraEffect(WordEffectContext ctx) {}

/// `I`（インサイト）— デッキの上 3 枚を見て 1 枚を手札に、残りを底へ。
void _insight(EffectContext ctx) {
  final actor = ctx.actor;
  final peeked = <String>[];
  for (var i = 0; i < 3 && actor.deck.isNotEmpty; i++) {
    peeked.add(actor.deck.removeAt(0));
  }
  if (peeked.isEmpty) return;

  final picked = ctx.chooser.chooseCard('インサイト: 手札に加える 1 枚', peeked) ?? 0;
  actor.hand.add(peeked.removeAt(picked));
  actor.deck.addAll(peeked);
}

/// `J`（ジョルト）/ `AT` — 相手のスペルライン上のカード 1 枚を破壊する。
void _destroyOneOpposingCard(EffectContext ctx) {
  final index =
      ctx.chooser.chooseLineSlot('破壊する相手のカード', ctx.opponent.line);
  if (index == null) return;
  final destroyed = ctx.opponent.destroyAt(index);
  if (destroyed != null) {
    ctx.log.add('${ctx.opponent.name} の $destroyed を破壊');
  }
}

/// `M`（ミラー）— 相手が直前に発動したワードの効果をコピーする。
///
/// コピー元のカードは盤面に存在しないため、パワー合計は加算されず、
/// ワード固有ダメージと効果のみが再現される。
void _mirror(EffectContext ctx) {
  final target = ctx.opponent.lastWord;
  if (target == null) return;

  final mirrored = WordEffectContext(
    game: ctx.game,
    actor: ctx.actor,
    opponent: ctx.opponent,
    chooser: ctx.chooser,
    log: ctx.log,
    word: target,
    wordIndices: const [],
    damage: target.damage,
  );
  wordEffects[target.word]?.call(mirrored);
  if (mirrored.damage > 0) {
    dealDamage(ctx.opponent, mirrored.damage,
        pierce: mirrored.pierce, log: ctx.log);
  }
  ctx.log.add('${ctx.actor.name} がミラーで ${target.word} をコピー');
}

/// `O`（オービット）/ `AIR` — 自分のスペルライン上のカードを並べ替える。
void _reorderOwnLine(EffectContext ctx) {
  final line = ctx.actor.line;
  final letters = [for (final i in line.occupiedIndices) line[i]!];
  if (letters.length < 2) return;
  final ordered = ctx.chooser.chooseOrder('スペルラインの並べ替え', letters);
  if (ordered.length != letters.length) return;
  line.reorder(ordered);
}

/// `Q`（クエスト）— 手札をすべて捨てて 5 枚ドローする。
void _quest(EffectContext ctx) {
  final actor = ctx.actor;
  actor.graveyard.addAll(actor.hand);
  actor.hand.clear();
  actor.draw(5);
}

/// `U`（ユナイト）— 墓地から文字カード 1 枚を手札に戻す。
void _returnFromGraveyard(EffectContext ctx) {
  final actor = ctx.actor;
  if (actor.graveyard.isEmpty) return;
  final index =
      ctx.chooser.chooseCard('墓地から手札に戻す 1 枚', actor.graveyard) ?? 0;
  actor.hand.add(actor.graveyard.removeAt(index));
}

/// `W`（ウェーブ）— 相手のスペルラインを 1 マスずつ右へずらす。
///
/// 右端からはみ出したカードは破壊される。ワードの並びを崩すのが狙い。
void _shiftOpposingLine(EffectContext ctx) {
  final line = ctx.opponent.line;
  final shifted = List<String?>.filled(SpellLine.slotCount, null);
  for (var i = SpellLine.slotCount - 1; i >= 0; i--) {
    final letter = line[i];
    if (letter == null) continue;
    if (i + 1 >= SpellLine.slotCount) {
      ctx.opponent.graveyard.add(letter);
      ctx.log.add('${ctx.opponent.name} の $letter が押し出された');
    } else {
      shifted[i + 1] = letter;
    }
  }
  for (var i = 0; i < SpellLine.slotCount; i++) {
    line.removeAt(i);
    if (shifted[i] != null) line.place(i, shifted[i]!);
  }
}

/// `Y`（イールド）— LP を 3 失い、3 枚ドローする。
void _yield(EffectContext ctx) {
  ctx.actor.lp -= 3;
  ctx.actor.draw(3);
}

/// `FOX` — 相手の手札を見て 1 枚を選んで捨てさせる。
void _foxDiscard(WordEffectContext ctx) {
  final hand = ctx.opponent.hand;
  if (hand.isEmpty) return;
  final index = ctx.chooser.chooseCard('相手に捨てさせるカード', hand) ?? 0;
  final discarded = ctx.opponent.discardAt(index);
  if (discarded != null) {
    ctx.log.add('${ctx.opponent.name} は $discarded を捨てた');
  }
}

/// `WAR` — 自分のスペルラインに「残る」カードのパワー合計を追加ダメージにする。
///
/// このワードを構成するカードは判定後に墓地へ送られるため、対象から除く。
void _warRemainingPower(WordEffectContext ctx) {
  final line = ctx.actor.line;
  var bonus = 0;
  for (final index in line.occupiedIndices) {
    if (ctx.wordIndices.contains(index)) continue;
    bonus += cardCatalog[line[index]!]!.power;
  }
  ctx.damage += bonus;
}

/// `KEY` — デッキから好きなカード 1 枚を手札に加える。
void _searchDeck(WordEffectContext ctx) {
  final deck = ctx.actor.deck;
  if (deck.isEmpty) return;
  final index = ctx.chooser.chooseCard('デッキから手札に加える 1 枚', deck) ?? 0;
  ctx.actor.hand.add(deck.removeAt(index));
}

/// `WIND` — 相手の手札からランダムに 2 枚捨てさせる。
void _windRandomDiscard(WordEffectContext ctx) {
  for (var i = 0; i < 2; i++) {
    final hand = ctx.opponent.hand;
    if (hand.isEmpty) return;
    ctx.opponent.discardAt(ctx.game.rng.nextInt(hand.length));
  }
}

/// `POWER` — 墓地から 3 枚を手札に戻し、エナジーを全回復する。
void _powerRecover(WordEffectContext ctx) {
  final actor = ctx.actor;
  for (var i = 0; i < 3 && actor.graveyard.isNotEmpty; i++) {
    final index =
        ctx.chooser.chooseCard('墓地から手札に戻す 1 枚', actor.graveyard) ?? 0;
    actor.hand.add(actor.graveyard.removeAt(index));
  }
  actor.energy = actor.maxEnergy;
}
