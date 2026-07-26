/// UI のスモークテスト。起動から 1 手指すまでの経路を守る。
library;

import 'package:azgame/main.dart';
import 'package:azgame/src/engine/models.dart';
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
    expect(find.text('ワード図鑑'), findsOneWidget);
  });

  testWidgets('対戦画面に 5×5 の盤と持ち駒が並ぶ', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('対戦開始'));
    await tester.pumpAndSettle();

    expect(find.byType(BattleScreen), findsOneWidget);
    expect(find.byType(BoardCellView), findsNWidgets(Board.cellCount));
    // 持ち駒は A〜Z の 26 種
    expect(find.byType(HandPieceView), findsNWidgets(26));
    expect(find.text('あなたの手番'), findsOneWidget);
  });

  testWidgets('持ち駒を選んで盤に置くと、相手の手番に移る', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('対戦開始'));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(HandPieceView).first);
    await tester.pump();
    await tester.tap(find.byType(BoardCellView).at(12)); // 中央
    await tester.pump();

    expect(find.text('相手の手番'), findsOneWidget);
    // 置いた駒のぶん、持ち駒の種類が 1 つ減る
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.byType(HandPieceView), findsNWidgets(25));
  });

  testWidgets('ワード図鑑に単語が並ぶ', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CatalogScreen()));
    await tester.pumpAndSettle();

    expect(find.textContaining('ワード図鑑'), findsWidgets);
    expect(find.byType(HandPieceView), findsWidgets);
  });
}
