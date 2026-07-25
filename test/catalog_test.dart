/// カタログデータの整合性検査。
///
/// `data/*.json` の定義と `effects.dart` の実装がずれた状態を検出する。
/// 片方だけ追加・削除するとここで落ちる。
library;

import 'package:azgame/src/data/catalog.g.dart';
import 'package:azgame/src/engine/effects.dart';
import 'package:azgame/src/engine/models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('カードカタログ', () {
    test('A〜Z の 26 種がそろっている', () {
      expect(cardCatalog.length, 26);
      for (var i = 0; i < 26; i++) {
        final letter = String.fromCharCode(65 + i);
        expect(cardCatalog.containsKey(letter), isTrue, reason: '$letter がない');
      }
    });

    test('順位はアルファベット順と一致する', () {
      for (final entry in cardCatalog.entries) {
        expect(entry.value.rank, entry.key.codeUnitAt(0) - 64,
            reason: '${entry.key} の rank が不正');
      }
    });

    test('母音は vowel クラスに分類されている', () {
      for (final letter in ['A', 'E', 'I', 'O', 'U']) {
        expect(cardCatalog[letter]!.klass, LetterClass.vowel);
      }
    });

    test('J Q X Z は rare で、コストが最も高い層にいる', () {
      for (final letter in ['J', 'Q', 'X', 'Z']) {
        final card = cardCatalog[letter]!;
        expect(card.klass, LetterClass.rare);
        expect(card.cost, greaterThanOrEqualTo(7));
        expect(card.deckLimit, 1);
      }
    });

    test('パワーは母音が cost+1、子音が cost*2 という導出規則に従う', () {
      const vowels = {'A', 'E', 'I', 'O', 'U'};
      for (final entry in cardCatalog.entries) {
        final card = entry.value;
        final expected =
            vowels.contains(entry.key) ? card.cost + 1 : card.cost * 2;
        expect(card.power, expected, reason: '${entry.key} のパワーが導出規則から外れている');
      }
    });

    test('デッキ投入上限の合計はデッキ枚数を十分に上回る（取捨選択が発生する）', () {
      final total =
          cardCatalog.values.fold<int>(0, (sum, c) => sum + c.deckLimit);
      expect(total, greaterThan(30));
    });

    test('onPlace 能力を持つカードはすべて実装されている', () {
      for (final entry in cardCatalog.entries) {
        if (entry.value.trigger != AbilityTrigger.onPlace) continue;
        expect(cardAbilities.containsKey(entry.key), isTrue,
            reason: '${entry.key} の onPlace 能力が未実装');
      }
    });

    test('実装済みの能力はすべてカタログに対応するカードがある', () {
      for (final letter in cardAbilities.keys) {
        expect(cardCatalog.containsKey(letter), isTrue,
            reason: '$letter はカタログに存在しない');
      }
    });
  });

  group('ワードカタログ', () {
    test('すべて大文字 2〜5 文字である', () {
      for (final word in wordCatalog.keys) {
        expect(word, matches(RegExp(r'^[A-Z]{2,5}$')), reason: '$word が不正');
      }
    });

    test('構成文字はすべてカタログ上のカードで、必要枚数がデッキ上限内に収まる', () {
      for (final word in wordCatalog.keys) {
        final needed = <String, int>{};
        for (final letter in word.split('')) {
          needed[letter] = (needed[letter] ?? 0) + 1;
        }
        for (final entry in needed.entries) {
          final card = cardCatalog[entry.key];
          expect(card, isNotNull, reason: '$word の ${entry.key} が未定義');
          expect(entry.value, lessThanOrEqualTo(card!.deckLimit),
              reason: '$word は ${entry.key} を ${entry.value} 枚必要とするが '
                  '上限は ${card.deckLimit} 枚');
        }
      }
    });

    test('すべてのワードに効果が実装されている', () {
      for (final word in wordCatalog.keys) {
        expect(wordEffects.containsKey(word), isTrue, reason: '$word の効果が未実装');
      }
    });

    test('実装済みの効果はすべてカタログに対応するワードがある', () {
      for (final word in wordEffects.keys) {
        expect(wordCatalog.containsKey(word), isTrue,
            reason: '$word はカタログに存在しない');
      }
    });

    test('最大長はスペルラインのマス数を超えない', () {
      expect(maxWordLength, lessThanOrEqualTo(SpellLine.slotCount));
    });
  });
}
