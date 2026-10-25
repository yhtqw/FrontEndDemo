import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:liquid_tab_bar_plugin/liquid_tab_bar_plugin.dart';
import 'package:liquid_tab_bar_plugin_example/main.dart';

void main() {
  Future<void> pumpRoutingExample(
    WidgetTester tester, {
    required Size size,
    String? initialLocation,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final router = createAppRouter(initialLocation: initialLocation);
    addTearDown(router.dispose);
    await tester.pumpWidget(RoutingExampleApp(router: router));
    await tester.pumpAndSettle();
  }

  NavigationBar navigationBar(WidgetTester tester) {
    return tester.widget<NavigationBar>(find.byType(NavigationBar));
  }

  testWidgets('Deep Link 自动命中发现分支并恢复选中态', (tester) async {
    await pumpRoutingExample(
      tester,
      size: const Size(500, 800),
      initialLocation: '/discover/topic/flutter',
    );

    expect(find.text('专题详情'), findsOneWidget);
    expect(find.text('flutter'), findsOneWidget);
    expect(navigationBar(tester).selectedIndex, 1);
  });

  testWidgets('切换 branch 后首页页面状态仍被保留', (tester) async {
    await pumpRoutingExample(tester, size: const Size(500, 800));

    await tester.tap(find.widgetWithText(FilledButton, '本页状态：0'));
    await tester.pump();
    expect(find.text('本页状态：1'), findsOneWidget);

    navigationBar(tester).onDestinationSelected!(1);
    await tester.pumpAndSettle();
    navigationBar(tester).onDestinationSelected!(0);
    await tester.pumpAndSettle();

    expect(find.text('本页状态：1'), findsOneWidget);
  });

  testWidgets('宽屏只替换导航外壳，使用 NavigationRail', (tester) async {
    await pumpRoutingExample(tester, size: const Size(800, 800));

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(LiquidTabBar), findsNothing);
  });

  testWidgets('宽窄切换只换 Chrome，不重置当前 branch 页面', (tester) async {
    await pumpRoutingExample(tester, size: const Size(500, 800));

    await tester.tap(find.widgetWithText(FilledButton, '本页状态：0'));
    await tester.pump();
    tester.view.physicalSize = const Size(800, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('本页状态：1'), findsOneWidget);

    tester.view.physicalSize = const Size(500, 800);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('本页状态：1'), findsOneWidget);
  });
}
