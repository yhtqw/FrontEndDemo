import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:liquid_tab_bar_plugin/liquid_tab_bar_plugin.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('controller 可以在原生 View 创建前保存最终动画状态', (WidgetTester tester) async {
    final controller = LiquidTabBarController();

    controller.collapse();

    expect(controller.isCollapsed, isTrue);
    expect(controller.revision, 1);
  });
}
