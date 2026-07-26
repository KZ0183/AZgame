/// 戦場の実効ステータスを算出する。
///
/// パワーとタフネスは、カードの基礎値に「隣接する文字の常在能力」「陣形の効果」
/// 「自分自身の常在能力」を重ねた結果として決まる。盤面が変われば毎回計算し直す
/// 必要があるため、状態を持たせず、その時点の [PlayerState] から組み立てる。
library;

import '../data/catalog.g.dart';
import 'detection.dart';
import 'game_state.dart';
import 'models.dart';

/// `T`（タワー）がそのレーンで軽減する戦闘ダメージ。
const int kTowerReduction = 2;

/// `K`（ナイト）が陣形に属していないときに得るパワー。
const int kKnightSoloBonus = 3;

/// ある時点の戦場を評価した結果。
///
/// 一度作ったら盤面を変えないこと。文字の増減や破壊があれば作り直す。
class BoardView {
  BoardView._({
    required this.player,
    required this.formations,
    required this.effect,
  });

  final PlayerState player;

  /// 自分の戦場に成立している陣形。
  final Formations formations;

  /// ワード陣形の合計効果。`M`（ミラー）による相手陣形のコピーを含む。
  final WordEffect effect;

  Battlefield get field => player.field;

  /// 戦場に指定の文字がいるか。
  bool _has(String letter) =>
      field.occupants.any((permanent) => permanent.letter == letter);

  /// 隣のレーンにいる指定文字の数。
  int _adjacent(int lane, String letter) {
    var count = 0;
    for (final offset in const [-1, 1]) {
      final neighbour = lane + offset;
      if (neighbour < 0 || neighbour >= Battlefield.laneCount) continue;
      if (field[neighbour]?.letter == letter) count++;
    }
    return count;
  }

  /// 指定レーンの文字の実効パワー。文字がいなければ 0。
  int powerOf(int lane) {
    final permanent = field[lane];
    if (permanent == null) return 0;
    final card = cardCatalog[permanent.letter]!;

    var power = card.power;
    // A（エース）— 隣のレーンにいる自分の文字のパワー+1
    power += _adjacent(lane, 'A');
    // 連番陣形の加算
    power += formations.sequenceBonusFor(lane);
    // ワード陣形の加算
    power += effect.powerBonus;
    // S（ストーム）— 自分の陣形 1 つにつき全文字のパワー+1
    if (_has('S')) power += formations.count;
    // K（ナイト）— 陣形に含まれていない間、パワー+3
    if (permanent.letter == 'K' && !formations.includes(lane)) {
      power += kKnightSoloBonus;
    }

    return power < 0 ? 0 : power;
  }

  /// 指定レーンの文字の実効タフネス。文字がいなければ 0。
  int toughnessOf(int lane) {
    final permanent = field[lane];
    if (permanent == null) return 0;
    final card = cardCatalog[permanent.letter]!;

    var toughness = card.toughness;
    // D（ディフェンド）— 隣のレーンにいる自分の文字のタフネス+1
    toughness += _adjacent(lane, 'D');
    // ワード陣形の加算
    toughness += effect.toughnessBonus;
    // E（エコー）— 自分の他の母音 1 体につきタフネス+1
    if (permanent.letter == 'E') {
      toughness += field.occupants
          .where((other) =>
              !identical(other, permanent) && cardCatalog[other.letter]!.isVowel)
          .length;
    }

    return toughness < 1 ? 1 : toughness;
  }

  /// 指定レーンの文字が攻撃できるか。
  bool canAttack(int lane) {
    final permanent = field[lane];
    if (permanent == null) return false;
    if (permanent.frozen) return false;
    // R（ラッシュ）— 自分の文字は召喚酔いの影響を受けない
    if (permanent.summoningSick && !_has('R')) return false;
    return true;
  }

  /// 指定レーンの文字の戦闘ダメージが、対峙する文字を無視して本体に入るか。
  bool piercesAt(int lane) {
    final permanent = field[lane];
    if (permanent == null) return false;
    // P（ピアース）は自分自身が貫通し、ワード陣形の pierce は全文字に及ぶ。
    return permanent.letter == 'P' || effect.pierce;
  }

  /// 指定レーンで受ける戦闘ダメージの軽減量。
  int damageReductionAt(int lane) {
    // T（タワー）— このレーンで自分が受ける戦闘ダメージを 2 減らす
    return field[lane]?.letter == 'T' ? kTowerReduction : 0;
  }

  /// 破壊判定に使う実効タフネスを返す関数。
  int Function(int lane) get toughnessResolver => toughnessOf;
}

/// [player] の盤面を評価する。
///
/// `M`（ミラー）は相手のワード陣形の効果をコピーするため、相手の盤面も必要になる。
/// 双方が `M` を出している場合に無限に参照し合わないよう、コピーは 1 段階だけ行う。
BoardView buildBoard(PlayerState player, PlayerState opponent) {
  final formations = findFormations(player.field);
  var effect = formations.combinedWordEffect;

  final hasMirror =
      player.field.occupants.any((permanent) => permanent.letter == 'M');
  if (hasMirror) {
    effect = effect.merge(findWordFormations(opponent.field).fold(
      WordEffect.none,
      (merged, formation) => merged.merge(formation.word.effect),
    ));
  }

  return BoardView._(player: player, formations: formations, effect: effect);
}
