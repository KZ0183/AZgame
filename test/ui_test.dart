/// UI のスモークテスト。
library;

import 'package:azgame/main.dart';
import 'package:azgame/src/engine/game.dart';
import 'package:azgame/src/ui/battle_screen.dart';
import 'package:azgame/src/ui/catalog_screen.dart';
import 'package:azgame/src/ui/widgets/letter_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('タイトル画面が表示される', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    expect(find.text('AZ GAME'), findsOneWidget);
    expect(find.text('対戦開始'), findsOneWidget);
  });

  testWidgets('対戦画面に手札と操作ボタンが出る', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('対戦開始'));
    await tester.pumpAndSettle();

    expect(find.byType(BattleScreen), findsOneWidget);
    // 初期手札 4 枚
    expect(find.byType(CardView), findsNWidgets(kStartingHand));
    expect(find.text('ターン終了'), findsOneWidget);
  });

  testWidgets('ターンを終えると相手の手番に移る', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('対戦開始'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('ターン終了'));
    await tester.pump();
    expect(find.text('相手のターン'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('カード一覧に 26 枚が並ぶ', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CatalogScreen()));
    await tester.pumpAndSettle();
    expect(find.byType(CardView), findsNWidgets(26));
  });
}
