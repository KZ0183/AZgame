/// デッキの定義と検証。
///
/// カードは 46 種から増えない。増えるのは敵だけ。
/// だから「同じ 46 種をどう組むか」がこのゲームの遊びの中心になる。
library;

import '../data/catalog.g.dart';
import 'battle.dart';

class DeckList {
  const DeckList({required this.name, required this.concept, required this.counts});

  final String name;

  /// このデッキが何をしたいのか。1 行で言えないデッキは組めていない。
  final String concept;

  final Map<String, int> counts;

  int get size => counts.values.fold(0, (sum, n) => sum + n);

  /// 平均コスト。デッキの重さの指標になる。
  double get averageCost => counts.entries
          .fold<int>(0, (sum, e) => sum + cardCatalog[e.key]!.cost * e.value) /
      size;

  List<String> toCardList() => [
        for (final entry in counts.entries)
          for (var i = 0; i < entry.value; i++) entry.key,
      ];

  List<String> validate() {
    final problems = <String>[];
    if (size != kDeckSize) problems.add('デッキは $kDeckSize 枚（現在 $size 枚）');
    for (final entry in counts.entries) {
      final card = cardCatalog[entry.key];
      if (card == null) {
        problems.add('未知の文字: ${entry.key}');
        continue;
      }
      if (entry.value > card.deckLimit) {
        problems.add('${entry.key} は ${card.deckLimit} 枚まで（現在 ${entry.value} 枚）');
      }
    }
    return problems;
  }

  bool get isValid => validate().isEmpty;
}

/// 素直なカーブの基準デッキ。
const DeckList starterDeck = DeckList(
  name: '初伝',
  concept: '挑発で受けて、盤面を取ってから本体を削る',
  counts: {
    'あ': 3, 'か': 3, 'た': 3, 'ら': 2, // 1 マナ
    'き': 2, 'ち': 3, 'に': 2, //           2 マナ
    'す': 2, 'く': 2, 'つ': 2, //           3 マナ
    'ね': 2, 'へ': 1, //                    4 マナ
    'こ': 1, 'も': 1, //                    5 マナ
    'ん': 1, //                             6 マナ
  },
);

/// 突撃と貫通に寄せた速攻。雑魚を無視して押し切る。
const DeckList rushDeck = DeckList(
  name: '疾風',
  concept: '雑魚を無視して本体だけを殴り、相手の行動表が回る前に倒す',
  counts: {
    'か': 4, 'や': 4, 'は': 4, //           1 マナ
    'き': 4, 'ひ': 4, //                    2 マナ
    'く': 3, 'ゆ': 3, //                    3 マナ
    'け': 2, //                             4 マナ
    'ほ': 1, 'こ': 1, //                    5 マナ
  },
);

/// 挑発と絆魂で受け切る守り。長期戦で勝つ。
const DeckList guardDeck = DeckList(
  name: '守勢',
  concept: '挑発で受け、絆魂で戻し、相手が息切れしてから殴る',
  counts: {
    'た': 4, 'ま': 3, 'な': 2, //           1 マナ
    'ち': 4, 'み': 3, 'に': 2, //           2 マナ
    'つ': 3, 'ぬ': 2, //                    3 マナ
    'て': 2, 'ね': 2, //                    4 マナ
    'も': 2, //                             5 マナ
    'ん': 1, //                             6 マナ
  },
);

const List<DeckList> presetDecks = [starterDeck, rushDeck, guardDeck];
