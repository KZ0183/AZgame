/// ターン進行と判定処理。エンジンの入口となるクラス。
library;

import '../data/catalog.g.dart';
import 'detection.dart';
import 'effects.dart';
import 'game_state.dart';

/// カードを配置できなかった理由。
enum PlacementError {
  /// このターンの配置枚数を使い切っている。
  noPlacementsLeft,

  /// エナジーが足りない。
  notEnoughEnergy,

  /// 指定したマスがすでに埋まっている。
  slotOccupied,

  /// その文字が手札にない。
  notInHand,

  /// すでに決着がついている。
  gameOver,
}

/// 判定フェイズの結果。UI の演出とテストの検証に使う。
class JudgementResult {
  JudgementResult({
    required this.sequences,
    required this.sequenceDamage,
    required this.word,
    required this.wordDamage,
    required this.wordNegated,
  });

  /// 検出されたシークエンス。
  final List<SequenceHit> sequences;

  /// シークエンスによって実際に LP を削った合計値。
  final int sequenceDamage;

  /// 成立したワード。成立しなければ `null`。
  final WordHit? word;

  /// ワードによって実際に LP を削った値。
  final int wordDamage;

  /// ワードが `NO` / `JINX` で無効化されたか。
  final bool wordNegated;

  bool get hasWord => word != null;

  @override
  String toString() => 'JudgementResult(seq: ${sequences.length} '
      '($sequenceDamage dmg), word: ${word?.word.word ?? "なし"} '
      '($wordDamage dmg)${wordNegated ? " 無効化" : ""})';
}

/// 対戦を進行させるエンジン。
///
/// UI・AI のどちらからも同じ API で駆動できるよう、状態遷移をすべて
/// メソッドとして公開している。ランダム性は [GameState.rng] に集約して
/// あるため、種を固定すれば対戦を完全に再現できる。
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

  /// 対戦を開始する。デッキをシャッフルし、初期手札を配り、先攻の 1 ターン目を始める。
  ///
  /// 後攻は先攻より 1 枚多く引く（先攻の 1 ターン目ドローぶんの補正）。
  void start() {
    _shuffle(state.first.deck);
    _shuffle(state.second.deck);
    state.first.draw(kStartingHandSize);
    state.second.draw(kStartingHandSize + 1);
    log.add('対戦開始。先攻は ${state.first.name}');
    beginTurn();
  }

  /// 手番プレイヤーのターンを開始する。ドローとエナジー回復を行う。
  void beginTurn() {
    if (state.isOver) return;
    state.turnNumber++;
    final active = state.active;

    // 自分のターンが巡ってきた時点で VEIL の効果は切れる。
    active.halveIncomingDamage = false;

    active.beginTurnPlacementLimit();
    active.draw(1);
    active.maxEnergy = (active.maxEnergy + 1).clamp(0, kMaxEnergyCap);
    active.energy = active.maxEnergy;

    log.add('--- ターン ${state.turnNumber}: ${active.name} '
        '(E ${active.energy}/${active.maxEnergy}) ---');
  }

  /// [letter] を [slotIndex] に配置できるか判定する。置けるなら `null` を返す。
  PlacementError? validatePlacement(String letter, int slotIndex) {
    if (state.isOver) return PlacementError.gameOver;
    final active = state.active;
    if (!active.hand.contains(letter)) return PlacementError.notInHand;
    if (active.remainingPlacements <= 0) return PlacementError.noPlacementsLeft;
    if (!active.line.isEmptyAt(slotIndex)) return PlacementError.slotOccupied;
    if (active.energy < cardCatalog[letter]!.cost) {
      return PlacementError.notEnoughEnergy;
    }
    return null;
  }

  /// 手番プレイヤーが [letter] を [slotIndex] に配置する。
  ///
  /// 配置に成功すると `onPlace` の固有能力が即座に発動する。
  /// 配置できない場合は [StateError] を投げるため、事前に
  /// [validatePlacement] で確認すること。
  void placeCard(String letter, int slotIndex) {
    final error = validatePlacement(letter, slotIndex);
    if (error != null) {
      throw StateError('$letter をマス $slotIndex に配置できません: $error');
    }

    final active = state.active;
    active.hand.remove(letter);
    active.energy -= cardCatalog[letter]!.cost;
    active.line.place(slotIndex, letter);
    active.placementsUsed++;
    log.add('${active.name} が $letter をマス $slotIndex に配置');

    final ability = cardAbilities[letter];
    if (ability != null) {
      ability(EffectContext(
        game: state,
        actor: active,
        opponent: state.inactive,
        chooser: chooserFor(active),
        log: log,
      ));
    }
  }

  /// ターンを終了する。判定フェイズを解決し、手番を相手に渡す。
  JudgementResult endTurn() {
    final result = resolveJudgement();
    _enforceHandLimit(state.active);

    if (!state.isOver) {
      state.isFirstPlayerTurn = !state.isFirstPlayerTurn;
      beginTurn();
    }
    return result;
  }

  /// 判定フェイズ。シークエンス判定 → ワード判定の順に解決する。
  ///
  /// この順序により、ワードでカードが消える前にシークエンスの削りが入る。
  /// 詳細な意図は docs/game-design.md 6.3 を参照。
  JudgementResult resolveJudgement() {
    final actor = state.active;
    final opponent = state.inactive;

    final sequences = findSequences(actor.line);
    var sequenceDamage = 0;
    for (final hit in sequences) {
      sequenceDamage += dealDamage(opponent, hit.damage, log: log);
      log.add('${actor.name} のシークエンス ${hit.letters.join()}'
          '${hit.isRun ? "（ラン）" : ""} で ${hit.damage} ダメージ');
    }

    final wordHit = findBestWord(actor.line);
    if (wordHit == null) {
      return JudgementResult(
        sequences: sequences,
        sequenceDamage: sequenceDamage,
        word: null,
        wordDamage: 0,
        wordNegated: false,
      );
    }

    if (actor.negateNextWord) {
      actor.negateNextWord = false;
      log.add('${actor.name} の ${wordHit.word.word} は無効化された');
      _consumeWordCards(actor, wordHit);
      return JudgementResult(
        sequences: sequences,
        sequenceDamage: sequenceDamage,
        word: wordHit,
        wordDamage: 0,
        wordNegated: true,
      );
    }

    final dealt = _resolveWord(actor, opponent, wordHit);
    actor.lastWord = wordHit.word;
    _consumeWordCards(actor, wordHit);

    return JudgementResult(
      sequences: sequences,
      sequenceDamage: sequenceDamage,
      word: wordHit,
      wordDamage: dealt,
      wordNegated: false,
    );
  }

  /// ワード 1 語を解決し、実際に LP を削った量を返す。
  ///
  /// 計算順は「固有ダメージ + パワー合計 → 定数加算（`A` `Z` 持ち越しボーナス）
  /// → ワード効果 → `S` の倍率 → 実ダメージ適用」。
  int _resolveWord(PlayerState actor, PlayerState opponent, WordHit hit) {
    final letters = hit.word.word.split('');

    var damage = hit.word.damage;
    for (final letter in letters) {
      damage += effectivePower(letter, inWord: true);
    }

    // A（エース）— ワードの先頭にあるとき +3
    if (letters.first == 'A') damage += 3;
    // Z（ゼニス）— ワードに含まれるとき +15
    if (letters.contains('Z')) damage += 15;
    // UP / MAP による持ち越しボーナス
    damage += actor.nextWordBonus;
    actor.nextWordBonus = 0;

    final ctx = WordEffectContext(
      game: state,
      actor: actor,
      opponent: opponent,
      chooser: chooserFor(actor),
      log: log,
      word: hit.word,
      wordIndices: hit.indices,
      damage: damage,
      // P（ピアース）— このカードを含むワードはシールドを無視する
      pierce: letters.contains('P'),
    );
    wordEffects[hit.word.word]?.call(ctx);

    // S（ストーム）— このカードを含むワードのダメージ +50%
    var finalDamage = ctx.damage;
    if (letters.contains('S')) {
      finalDamage = (finalDamage * 1.5).floor();
    }

    log.add('${actor.name} が ${hit.word.word} を発動'
        '${finalDamage > 0 ? "（$finalDamage ダメージ）" : ""}');
    return dealDamage(opponent, finalDamage, pierce: ctx.pierce, log: log);
  }

  /// ワードを構成したカードを墓地へ送る。
  ///
  /// `E`（エコー）だけはスペルライン上に残る。
  void _consumeWordCards(PlayerState actor, WordHit hit) {
    for (final index in hit.indices) {
      final letter = actor.line[index];
      if (letter == null) continue;
      if (letter == 'E') continue;
      actor.line.removeAt(index);
      actor.graveyard.add(letter);
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
