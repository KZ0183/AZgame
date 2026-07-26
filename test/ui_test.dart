/// UI のスモークテスト。
///
/// 見た目の細部までは検証しないが、「起動して対戦を最後まで進められる」という
/// 最低限の経路が壊れていないことを保証する。
library;

import 'package:azgame/main.dart';
import 'package:azgame/src/engine/deck.dart';
import 'package:azgame/src/ui/battle_screen.dart';
import 'package:azgame/src/ui/catalog_screen.dart';
import 'package:azgame/src/ui/widgets/letter_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('タイトル画面が表示され、デッキを選べる', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();

    expect(find.text('AZ GAME'), findsOneWidget);
    for (final deck in starterDecks) {
      expect(find.text(deck.name), findsOneWidget);
    }
    expect(find.text('対戦開始'), findsOneWidget);
  });

  testWidgets('対戦開始で対戦画面に遷移し、手札とスペルラインが並ぶ', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();

    await tester.tap(find.text('対戦開始'));
    await tester.pumpAndSettle();

    expect(find.byType(BattleScreen), findsOneWidget);
    expect(find.text('あなた'), findsOneWidget);
    expect(find.text('相手'), findsOneWidget);
    // 両者 5 レーンずつが描かれている
    expect(find.byType(LaneView), findsNWidgets(10));
    expect(find.byType(LetterCardView), findsWidgets);
  });

  testWidgets('手札を選んでレーンに出し、ターンを終了できる', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('対戦開始'));
    await tester.pumpAndSettle();

    // 手札の先頭（コスト 1 の安いカードが来るとは限らないため、
    // 押せるカードを探す）を選んで、自分のライン左端に置く。
    final handCards = find.descendant(
      of: find.byType(ListView),
      matching: find.byType(LetterCardView),
    );
    expect(handCards, findsWidgets);
    await tester.tap(handCards.first);
    await tester.pump();

    await tester.tap(find.byType(LaneView).at(5));
    await tester.pump();

    // ターン終了ボタンを押すと、AI の手番に入る。
    await tester.tap(find.textContaining('ターン終了'));
    await tester.pump();
    expect(find.text('相手のターン'), findsOneWidget);

    // AI の思考待ちタイマーを消化してからテストを終える。
    await tester.pumpAndSettle(const Duration(seconds: 10));
  });

  testWidgets('図鑑にカード 26 種とワードが載っている', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: CatalogScreen()),
    );
    await tester.pumpAndSettle();

    expect(find.text('カード（26）'), findsOneWidget);
    expect(find.text('ワード（48）'), findsOneWidget);
    // 先頭に並ぶ A のカードとその能力名が見えている
    expect(find.text('エース'), findsOneWidget);
  });
}
