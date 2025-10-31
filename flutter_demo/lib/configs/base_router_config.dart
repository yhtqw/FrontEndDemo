import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/customize_tab/customize_tab_page.dart';
import '../pages/transform_use/transform_use_page.dart';
import '../pages/home/home_page.dart';
import '../pages/seamless_scrolling/seamless_scrolling_page.dart';

class BaseRouterConfig {
  static GoRouter router = GoRouter(
    initialLocation: HomePage.routePath,
    routes: [
      GoRoute(
        path: HomePage.routePath,
        builder: (BuildContext context, GoRouterState state) => HomePage(),
      ),
      GoRoute(
        path: CustomizeTabPage.routePath,
        builder: (BuildContext context, GoRouterState state) => CustomizeTabPage(),
      ),
      GoRoute(
        path: SeamlessScrollingPage.routePath,
        builder: (BuildContext context, GoRouterState state) => SeamlessScrollingPage(),
      ),
      GoRoute(
        path: TransformUsePage.routePath,
        builder: (BuildContext context, GoRouterState state) => TransformUsePage(),
      ),
    ],
  );
}
