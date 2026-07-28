/// 敵キャラクターの定義。
///
/// 敵はカードを持たない。**決まった順番で行動表をなぞるだけ**で、
/// プレイヤーには次の 1 手が常に見えている。運ではなく読みで解く相手にするため。
///
/// この構造がこのゲームのボリューム戦略そのものでもある。
/// カードは 1 枚足すたびに他の 45 枚との噛み合わせを検証しないといけないが、
/// 敵は「ライフと行動表」だけなので、数行で 1 体増やせる。
library;

enum EnemyActionKind {
  /// 雑魚を呼ぶ。
  summon,

  /// 本体で殴る。挑発では防げない。これがどのデッキにも共通の締切になる。
  strike,

  /// こちらのミニオン全部にダメージ。挑発の壁と横並びを咎める手段。
  sweep,

  /// 以降の [strike] の威力を上げる。
  empower,

  /// 自分のライフを回復する。
  heal,
}

class EnemyAction {
  const EnemyAction({
    required this.kind,
    this.value = 0,
    this.summons = const [],
  });

  final EnemyActionKind kind;
  final int value;
  final List<String> summons;

  /// 予告として画面に出す文言。[bonus] は蓄積した [EnemyActionKind.empower] ぶん。
  String label(int bonus) => switch (kind) {
        EnemyActionKind.summon => '${summons.join('・')} を呼ぶ',
        EnemyActionKind.strike => '${value + bonus} ダメージ',
        EnemyActionKind.sweep => 'こちら全体に $value ダメージ',
        EnemyActionKind.empower => '力を溜める（攻撃 +$value）',
        EnemyActionKind.heal => 'ライフ $value 回復',
      };
}

class EnemyDef {
  const EnemyDef({
    required this.id,
    required this.name,
    required this.glyph,
    required this.life,
    required this.flavor,
    required this.lesson,
    required this.pattern,
  });

  final String id;
  final String name;

  /// 一文字ぶんの絵。絵を描く余力がないので絵文字で代用している。
  final String glyph;

  final int life;
  final String flavor;

  /// この敵が何を試しているか。デッキを組み替える指針になる。
  final String lesson;

  /// 行動表。末尾まで来たら先頭に戻って繰り返す。
  final List<EnemyAction> pattern;
}
