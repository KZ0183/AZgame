// GENERATED FILE — 直接編集しないこと。
//
// 生成元: data/cards.json (v0.4.0), data/words.json (v0.4.0)
// 再生成: dart run tool/generate_catalog.dart
library;

import '../engine/models.dart';

/// 全 26 文字のマスターデータ。キーは大文字 1 文字。
const Map<String, LetterCard> cardCatalog = {
  'A': LetterCard(
    letter: 'A',
    rank: 1,
    klass: LetterClass.vowel,
  ),
  'B': LetterCard(
    letter: 'B',
    rank: 2,
    klass: LetterClass.heavy,
  ),
  'C': LetterCard(
    letter: 'C',
    rank: 3,
    klass: LetterClass.heavy,
  ),
  'D': LetterCard(
    letter: 'D',
    rank: 4,
    klass: LetterClass.core,
  ),
  'E': LetterCard(
    letter: 'E',
    rank: 5,
    klass: LetterClass.vowel,
  ),
  'F': LetterCard(
    letter: 'F',
    rank: 6,
    klass: LetterClass.heavy,
  ),
  'G': LetterCard(
    letter: 'G',
    rank: 7,
    klass: LetterClass.core,
  ),
  'H': LetterCard(
    letter: 'H',
    rank: 8,
    klass: LetterClass.heavy,
  ),
  'I': LetterCard(
    letter: 'I',
    rank: 9,
    klass: LetterClass.vowel,
  ),
  'J': LetterCard(
    letter: 'J',
    rank: 10,
    klass: LetterClass.rare,
  ),
  'K': LetterCard(
    letter: 'K',
    rank: 11,
    klass: LetterClass.heavy,
  ),
  'L': LetterCard(
    letter: 'L',
    rank: 12,
    klass: LetterClass.core,
  ),
  'M': LetterCard(
    letter: 'M',
    rank: 13,
    klass: LetterClass.heavy,
  ),
  'N': LetterCard(
    letter: 'N',
    rank: 14,
    klass: LetterClass.core,
  ),
  'O': LetterCard(
    letter: 'O',
    rank: 15,
    klass: LetterClass.vowel,
  ),
  'P': LetterCard(
    letter: 'P',
    rank: 16,
    klass: LetterClass.heavy,
  ),
  'Q': LetterCard(
    letter: 'Q',
    rank: 17,
    klass: LetterClass.rare,
  ),
  'R': LetterCard(
    letter: 'R',
    rank: 18,
    klass: LetterClass.core,
  ),
  'S': LetterCard(
    letter: 'S',
    rank: 19,
    klass: LetterClass.core,
  ),
  'T': LetterCard(
    letter: 'T',
    rank: 20,
    klass: LetterClass.core,
  ),
  'U': LetterCard(
    letter: 'U',
    rank: 21,
    klass: LetterClass.vowel,
  ),
  'V': LetterCard(
    letter: 'V',
    rank: 22,
    klass: LetterClass.heavy,
  ),
  'W': LetterCard(
    letter: 'W',
    rank: 23,
    klass: LetterClass.heavy,
  ),
  'X': LetterCard(
    letter: 'X',
    rank: 24,
    klass: LetterClass.rare,
  ),
  'Y': LetterCard(
    letter: 'Y',
    rank: 25,
    klass: LetterClass.heavy,
  ),
  'Z': LetterCard(
    letter: 'Z',
    rank: 26,
    klass: LetterClass.rare,
  ),
};

/// 盤上で成立する単語の一覧。
const Set<String> wordSet = {
  'AT',
  'GO',
  'HI',
  'ID',
  'NO',
  'ON',
  'OX',
  'SO',
  'UP',
  'WE',
  'ACE',
  'AIR',
  'BUG',
  'FIX',
  'FOX',
  'GEM',
  'ICE',
  'JAB',
  'KEY',
  'MAP',
  'OAK',
  'ROT',
  'SKY',
  'SUN',
  'VOW',
  'WAR',
  'WIN',
  'ZAP',
  'BOMB',
  'CALM',
  'FIRE',
  'GOLD',
  'HEAL',
  'JINX',
  'LOCK',
  'RUIN',
  'STAR',
  'VEIL',
  'WAVE',
  'WIND',
  'BLAZE',
  'BRAVE',
  'CROWN',
  'FROST',
  'LIGHT',
  'POWER',
  'QUEST',
  'STORM',
};

/// 登録されている単語の最大長。探索の打ち切りに使う。
const int maxWordLength = 5;
