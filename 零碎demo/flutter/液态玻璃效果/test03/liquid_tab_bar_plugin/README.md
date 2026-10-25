# Liquid Tab Bar Plugin

这是博客《把原生 Liquid Glass TabBar 做成可复用 Flutter Plugin》及其路由篇的完整示例工程。

它不是把 Liquid Glass 复制到所有平台：

- iOS 26+：固定 `UiKitView` 宿主，内部 UIKit 子视图使用 `UIGlassEffect` 动画。
- iOS 26 以下：同一套 API、同一套 UIKit 按钮和动画，材质自动降级为 `UIBlurEffect.systemMaterial`。
- Android、Web、桌面和测试环境：纯 Flutter Material 3 `NavigationBar`，不再额外嵌入 Android Platform View。
- 示例应用：`go_router 18.0.2` 的 `StatefulShellRoute.indexedStack`、独立 branch Navigator、Deep Link 和宽屏 `NavigationRail`。

## 环境

- Flutter 3.47.2
- Xcode 26+，用于编译 iOS 26 SDK 的 `UIGlassEffect`
- iOS Deployment Target 15.0

## 运行示例

```bash
fvm flutter pub get
cd example
fvm flutter pub get
fvm flutter run
```

示例注册了仅供本地调试的自定义 Scheme，因此可以把应用打开到发现页详情：

```bash
# iOS Simulator
xcrun simctl openurl booted liquidnavdemo://app/discover/topic/flutter

# Android Emulator / 设备
adb shell am start -a android.intent.action.VIEW \
  -d 'liquidnavdemo://app/discover/topic/flutter'
```

自定义 Scheme 只能验证 App 到 Flutter Router 的链路。生产环境的 HTTPS 链接仍需分别配置 iOS Associated Domains + `apple-app-site-association`，以及 Android App Links + `assetlinks.json`。

## 验证

```bash
fvm flutter analyze
fvm flutter test
cd example
fvm flutter test
fvm flutter build ios --simulator
```

## 公开 API

`LiquidTabBarDestination` 以稳定的 `id`、Material `IconData` 与 SF Symbol 名称描述一个目的地；Flutter 图标不会穿过 Channel。

`LiquidTabBar` 是受控组件：`selectedIndex` 必须由宿主传入。和 `go_router` 集成时，直接传 `navigationShell.currentIndex`；原生点击只触发 `onSelected`，由宿主调用 `goBranch()`，再由新的路由状态回灌选中项。

`LiquidTabBarController` 只保存 compact 状态与递增 revision。`LiquidTabBarScrollDriver` 是可选帮助类，用来把连续滚动压缩为低频的 `collapse()` / `expand()` 调用。

```dart
LiquidTabBar(
  destinations: destinations,
  selectedIndex: navigationShell.currentIndex,
  controller: chromeController,
  onSelected: (index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  },
)
```

`StatefulShellRoute.indexedStack` 已经为每个 branch 保留了独立 Navigator 和 `IndexedStack`，示例没有再额外手写一层。它解决的是同一进程内切换 Tab 后的页面栈和 Widget 状态保留；被系统杀进程后的恢复需要单独配置 Flutter state restoration。

底栏目的地通常是静态配置。如果运行时替换 destinations，组件会用新配置重新创建 iOS Platform View；正常滚动、选中和收起状态不会重新创建原生 View。

## 发布前

这是文章配套代码，尚未发布到 pub.dev。发布前请修改 `pubspec.yaml`、`ios/liquid_tab_bar_plugin.podspec` 中的包描述、主页、作者和许可证信息，再运行 `flutter pub publish --dry-run`。
