import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_tab_bar_plugin/liquid_tab_bar_plugin.dart';

void main() {
  runApp(RoutingExampleApp(router: createAppRouter()));
}

/// 只在没有平台 Deep Link 时作为默认入口。
/// 不要设置 overridePlatformDefaultLocation，否则冷启动 Deep Link 会被覆盖。
GoRouter createAppRouter({String? initialLocation}) {
  final homeNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'homeBranch');
  final discoverNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'discoverBranch',
  );
  final profileNavigatorKey = GlobalKey<NavigatorState>(
    debugLabel: 'profileBranch',
  );

  return GoRouter(
    initialLocation: initialLocation ?? AppSection.home.rootPath,
    routes: <RouteBase>[
      // 根路径只负责跳到第一个 branch，真正页面都在 StatefulShellRoute 内。
      GoRoute(path: '/', redirect: (_, _) => AppSection.home.rootPath),
      StatefulShellRoute.indexedStack(
        builder:
            (
              BuildContext context,
              GoRouterState state,
              StatefulNavigationShell navigationShell,
            ) {
              return AppNavigationShell(navigationShell: navigationShell);
            },
        branches: <StatefulShellBranch>[
          StatefulShellBranch(
            navigatorKey: homeNavigatorKey,
            initialLocation: AppSection.home.rootPath,
            routes: <RouteBase>[
              GoRoute(
                path: AppSection.home.rootPath,
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const BranchLandingPage(
                    title: '首页',
                    subtitle: '这是首页',
                    accent: Color(0xFF5B7CFF),
                    detailPath: '/home/article/liquid-glass',
                  ),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'article/:articleId',
                    builder: (context, state) => DetailPage(
                      title: '文章详情',
                      value: state.pathParameters['articleId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: discoverNavigatorKey,
            initialLocation: AppSection.discover.rootPath,
            routes: <RouteBase>[
              GoRoute(
                path: AppSection.discover.rootPath,
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const BranchLandingPage(
                    title: '发现',
                    subtitle: '这是发现页',
                    accent: Color(0xFFFF8A5B),
                    detailPath: '/discover/topic/flutter',
                  ),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'topic/:topicId',
                    builder: (context, state) => DetailPage(
                      title: '专题详情',
                      value: state.pathParameters['topicId']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: profileNavigatorKey,
            initialLocation: AppSection.profile.rootPath,
            routes: <RouteBase>[
              GoRoute(
                path: AppSection.profile.rootPath,
                pageBuilder: (context, state) => NoTransitionPage<void>(
                  key: state.pageKey,
                  child: const BranchLandingPage(
                    title: '我的',
                    subtitle: '这是我的页',
                    accent: Color(0xFF27A772),
                    detailPath: '/profile/settings',
                  ),
                ),
                routes: <RouteBase>[
                  GoRoute(
                    path: 'settings',
                    builder: (context, state) =>
                        const DetailPage(title: '设置', value: 'settings'),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

/// 枚举顺序就是 StatefulShellBranch 与导航目的地的共同顺序。
///
/// 路由路径、Flutter 图标和 SF Symbol 收在一起，新增分支时不会只改其中一半。
enum AppSection {
  home(
    '/home',
    LiquidTabBarDestination(
      id: 'home',
      label: '首页',
      materialIcon: Icons.home_outlined,
      selectedMaterialIcon: Icons.home,
      iosSymbolName: 'house',
      selectedIosSymbolName: 'house.fill',
    ),
  ),
  discover(
    '/discover',
    LiquidTabBarDestination(
      id: 'discover',
      label: '发现',
      materialIcon: Icons.explore_outlined,
      selectedMaterialIcon: Icons.explore,
      iosSymbolName: 'safari',
      selectedIosSymbolName: 'safari.fill',
    ),
  ),
  profile(
    '/profile',
    LiquidTabBarDestination(
      id: 'profile',
      label: '我的',
      materialIcon: Icons.person_outline,
      selectedMaterialIcon: Icons.person,
      iosSymbolName: 'person',
      selectedIosSymbolName: 'person.fill',
    ),
  );

  const AppSection(this.rootPath, this.destination);

  final String rootPath;
  final LiquidTabBarDestination destination;
}

class RoutingExampleApp extends StatelessWidget {
  const RoutingExampleApp({required this.router, super.key});

  final GoRouter router;

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Liquid TabBar Router',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5B7CFF),
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}

/// Shell 才拥有底栏 controller；branch 页面不维护任何 Tab 选中状态。
class AppNavigationShell extends StatefulWidget {
  const AppNavigationShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  @override
  State<AppNavigationShell> createState() => _AppNavigationShellState();
}

class _AppNavigationShellState extends State<AppNavigationShell> {
  final _tabBarController = LiquidTabBarController();
  late final _scrollDriver = LiquidTabBarScrollDriver(_tabBarController);

  static final _destinations = AppSection.values
      .map((section) => section.destination)
      .toList(growable: false);

  void _goBranch(int index) {
    // 再点当前 Tab 时回到该 branch 的根路由；切到其他 Tab 则恢复原栈。
    // 这是视觉状态，不能替代 navigationShell.currentIndex。
    _tabBarController.expand();
    widget.navigationShell.goBranch(
      index,
      initialLocation: index == widget.navigationShell.currentIndex,
    );
  }

  @override
  void dispose() {
    _tabBarController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchBody = NotificationListener<ScrollNotification>(
      onNotification: _scrollDriver.onNotification,
      child: widget.navigationShell,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final useNavigationRail = constraints.maxWidth >= 600;

        return Scaffold(
          body: Row(
            children: <Widget>[
              // 这个位置在窄宽布局下都存在，确保 branchBody 始终是同一个
              // Expanded 子节点。我们只替换导航 Chrome，不搬动路由树。
              SizedBox(
                width: useNavigationRail ? 80 : 0,
                child: useNavigationRail
                    ? SafeArea(
                        right: false,
                        child: NavigationRail(
                          selectedIndex: widget.navigationShell.currentIndex,
                          onDestinationSelected: _goBranch,
                          labelType: NavigationRailLabelType.all,
                          useIndicator: true,
                          destinations: <NavigationRailDestination>[
                            for (final destination in _destinations)
                              NavigationRailDestination(
                                icon: Icon(destination.materialIcon),
                                selectedIcon: Icon(
                                  destination.selectedMaterialIcon ??
                                      destination.materialIcon,
                                ),
                                label: Text(destination.label),
                              ),
                          ],
                        ),
                      )
                    : null,
              ),
              VerticalDivider(width: useNavigationRail ? 1 : 0),
              Expanded(child: branchBody),
            ],
          ),
          bottomNavigationBar: useNavigationRail
              ? null
              : LiquidTabBar(
                  destinations: _destinations,
                  controller: _tabBarController,
                  // 路由是唯一真相，不能在这里再维护一份 _selectedIndex。
                  selectedIndex: widget.navigationShell.currentIndex,
                  onSelected: _goBranch,
                ),
        );
      },
    );
  }
}

class BranchLandingPage extends StatefulWidget {
  const BranchLandingPage({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.detailPath,
    super.key,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final String detailPath;

  @override
  State<BranchLandingPage> createState() => _BranchLandingPageState();
}

class _BranchLandingPageState extends State<BranchLandingPage> {
  int _counter = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: widget.accent.withValues(alpha: 0.04),
      appBar: AppBar(title: Text(widget.title)),
      body: CustomScrollView(
        key: PageStorageKey<String>('scroll-${widget.title}'),
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    widget.subtitle,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () {
                      setState(() {
                        _counter += 1;
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text('本页状态：$_counter'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () => context.push(widget.detailPath),
                    child: const Text('进入详情页'),
                  ),
                ],
              ),
            ),
          ),
          SliverList.builder(
            itemCount: 24,
            itemBuilder: (context, index) => ListTile(
              leading: CircleAvatar(
                backgroundColor: widget.accent.withValues(alpha: 0.18),
                child: Text('${index + 1}'),
              ),
              title: Text('${widget.title}内容 ${index + 1}'),
              subtitle: const Text('测试文本'),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

class DetailPage extends StatelessWidget {
  const DetailPage({required this.title, required this.value, super.key});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(value, style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => context.pop(),
                child: const Text('返回'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
