/// UI のスモークテスト。
library;

import 'package:azgame/main.dart';
import 'package:azgame/src/engine/battle.dart';
import 'package:azgame/src/ui/battle_screen.dart';
import 'package:azgame/src/ui/catalog_screen.dart';
import 'package:azgame/src/ui/widgets/kana_card_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// タイトル → 道中 → 最初の相手との戦闘まで進める。
Future<void> enterBattle(WidgetTester tester) async {
  await tester.pumpWidget(const AzGameApp());
  await tester.pumpAndSettle();
  await tester.tap(find.text('道中を始める'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('初伝'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('タイトル画面が表示される', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    expect(find.text('かな戦記'), findsOneWidget);
    expect(find.text('道中を始める'), findsOneWidget);
  });

  testWidgets('道中に入ると相手の行動表とデッキ候補が出る', (tester) async {
    await tester.pumpWidget(const AzGameApp());
    await tester.pumpAndSettle();
    await tester.tap(find.text('道中を始める'));
    await tester.pumpAndSettle();

    expect(find.text('木こり人形'), findsOneWidget);
    expect(find.text('行動表（この順に繰り返す）'), findsOneWidget);
    expect(find.text('デッキを選ぶ'), findsOneWidget);
    expect(find.text('初伝'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('守勢'), 200);
    expect(find.text('守勢'), findsOneWidget);
  });

  testWidgets('戦闘画面に手札と行動予告が出る', (tester) async {
    await enterBattle(tester);

    expect(find.byType(BattleScreen), findsOneWidget);
    // 初期手札 4 枚 + 1 ターン目のドロー 1 枚。
    expect(find.byType(CardView), findsNWidgets(kStartingHand + 1));
    expect(find.textContaining('次:'), findsOneWidget);
    expect(find.text('ターン終了'), findsOneWidget);
  });

  testWidgets('ターンを終えると敵の手番が解決される', (tester) async {
    await enterBattle(tester);

    await tester.tap(find.text('ターン終了'));
    await tester.pump();
    expect(find.text('敵のターン'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 2));
    expect(find.text('ターン終了'), findsOneWidget, reason: '手番が戻ってくる');
  });

  testWidgets('カード一覧が行ごとに並ぶ', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: CatalogScreen()));
    await tester.pumpAndSettle();
    expect(find.text('あ行'), findsOneWidget);
    expect(find.byType(CardView), findsWidgets);
    // 下の行まで並んでいること（「ん」はカードの文字とも重なるので わ行 で見る）。
    await tester.scrollUntilVisible(find.text('わ行'), 300);
    expect(find.text('わ行'), findsOneWidget);
  });
}
