import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_tab_bar_plugin/liquid_tab_bar_plugin.dart';

void main() {
  test('controller 只在 compact 状态改变时递增 revision', () {
    final controller = LiquidTabBarController();
    var notifications = 0;
    controller.addListener(() => notifications += 1);

    controller.collapse();
    controller.collapse();
    controller.expand();

    expect(controller.isCollapsed, isFalse);
    expect(controller.revision, 2);
    expect(notifications, 2);
  });

  test('controller 不保存选中项，避免与路由产生双状态', () {
    final controller = LiquidTabBarController();

    controller.collapse();

    expect(controller.isCollapsed, isTrue);
    expect(controller.revision, 1);
  });
}
