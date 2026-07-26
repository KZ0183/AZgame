/// カタログデータの整合性検査。
///
/// `data/*.json` の定義と `effects.dart` の実装がずれた状態を検出する。
library;

import 'package:azgame/src/data/catalog.g.dart';
import 'package:azgame/src/engine/effects.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('カードカタログ', () {
    test('A〜Z の 26 種がそろい、順位がアルファベット順と一致する', () {
      expect(cardCatalog.length, 26);
      for (final entry in cardCatalog.entries) {
        expect(entry.value.rank, entry.key.codeUnitAt(0) - 64,
            reason: '${entry.key} の rank が不正');
      }
    });

    test('母音はコスト 0 でマナを生み、子音はマナを生まない', () {
      for (final card in cardCatalog.values) {
        if (card.isVowel) {
          expect(card.cost, 0, reason: '${card.letter} のコストは 0 のはず');
          expect(card.energyProduced, greaterThan(0),
              reason: '${card.letter} はマナを生むはず');
        } else {
          expect(card.energyProduced, 0,
              reason: '${card.letter} はマナを生まないはず');
          expect(card.cost, greaterThan(0));
        }
      }
    });

    test('母音は A E I O U のちょうど 5 種', () {
      final vowels = cardCatalog.values.where((c) => c.isVowel).map((c) => c.letter);
      expect(vowels.toSet(), {'A', 'E', 'I', 'O', 'U'});
    });

    test('子音のパワーとタフネスはコストに等しい', () {
      for (final card in cardCatalog.values) {
        if (card.isVowel) continue;
        expect(card.power, card.cost, reason: '${card.letter} のパワー');
        expect(card.toughness, card.cost, reason: '${card.letter} のタフネス');
      }
    });

    test('J Q X Z は rare で 1 枚しか入らない', () {
      for (final letter in ['J', 'Q', 'X', 'Z']) {
        final card = cardCatalog[letter]!;
        expect(card.klass, LetterClass.rare);
        expect(card.deckLimit, 1);
        expect(card.cost, greaterThanOrEqualTo(7));
      }
    });

    test('毎ターン能力と登場時能力はすべて実装されている', () {
      for (final card in cardCatalog.values) {
        switch (card.trigger) {
          case AbilityTrigger.upkeep:
            expect(upkeepAbilities.containsKey(card.letter), isTrue,
                reason: '${card.letter} の毎ターン能力が未実装');
          case AbilityTrigger.onPlay:
            expect(onPlayAbilities.containsKey(card.letter), isTrue,
                reason: '${card.letter} の登場時能力が未実装');
          case AbilityTrigger.static:
            expect(upkeepAbilities.containsKey(card.letter), isFalse,
                reason: '${card.letter} は常在能力なので登録不要');
            expect(onPlayAbilities.containsKey(card.letter), isFalse);
        }
      }
    });

    test('実装済みの能力はすべてカタログに対応する文字がある', () {
      for (final letter in [...upkeepAbilities.keys, ...onPlayAbilities.keys]) {
        expect(cardCatalog.containsKey(letter), isTrue, reason: '$letter が未定義');
      }
    });
  });

  group('ワードカタログ', () {
    test('すべて大文字 2〜5 文字で、レーン数に収まる', () {
      for (final word in wordCatalog.keys) {
        expect(word, matches(RegExp(r'^[A-Z]{2,5}$')));
      }
      expect(maxWordLength, lessThanOrEqualTo(Battlefield.laneCount));
    });

    test('構成文字はすべて実在し、必要枚数がデッキ上限内に収まる', () {
      for (final word in wordCatalog.keys) {
        final needed = <String, int>{};
        for (final letter in word.split('')) {
          needed[letter] = (needed[letter] ?? 0) + 1;
        }
        for (final entry in needed.entries) {
          final card = cardCatalog[entry.key];
          expect(card, isNotNull, reason: '$word の ${entry.key}');
          expect(entry.value, lessThanOrEqualTo(card!.deckLimit),
              reason: '$word は ${entry.key} を ${entry.value} 枚必要とする');
        }
      }
    });

    test('すべてのワードが何らかの継続効果を持つ', () {
      for (final word in wordCatalog.values) {
        final e = word.effect;
        final hasEffect = e.powerBonus > 0 ||
            e.toughnessBonus > 0 ||
            e.upkeepDamage > 0 ||
            e.upkeepHeal > 0 ||
            e.upkeepDraw > 0 ||
            e.upkeepEnergy > 0 ||
            e.upkeepShield > 0 ||
            e.freeze > 0 ||
            e.pierce;
        expect(hasEffect, isTrue, reason: '${word.word} の効果が空');
        expect(word.text, isNotEmpty, reason: '${word.word} の説明文が空');
      }
    });

    test('効果は文字数が増えるほど強くなる傾向にある', () {
      int weight(ComboWord w) =>
          w.effect.powerBonus * 4 +
          w.effect.toughnessBonus * 3 +
          w.effect.upkeepDamage * 4 +
          w.effect.upkeepHeal * 2 +
          w.effect.upkeepShield * 2 +
          w.effect.upkeepEnergy * 3 +
          w.effect.upkeepDraw * 5 +
          w.effect.freeze * 5;

      double average(int length) {
        final matching =
            wordCatalog.values.where((w) => w.length == length).toList();
        return matching.map(weight).reduce((a, b) => a + b) / matching.length;
      }

      expect(average(2), lessThan(average(3)));
      expect(average(3), lessThan(average(4)));
      expect(average(4), lessThan(average(5)));
    });
  });
}
