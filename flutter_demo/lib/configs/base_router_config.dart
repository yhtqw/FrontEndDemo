import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/ceiling_mount/ceiling_mount_page.dart';
import '../pages/customize_tab/customize_tab_page.dart';
import '../pages/filter_dropdown/filter_dropdown_page.dart';
import '../pages/point_move_animate/point_move_animate_page.dart';
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
      GoRoute(
        path: FilterDropdownPage.routePath,
        builder: (BuildContext context, GoRouterState state) => FilterDropdownPage(),
      ),
      GoRoute(
        path: CeilingMountPage.routePath,
        builder: (BuildContext context, GoRouterState state) => CeilingMountPage(),
      ),
      GoRoute(
        path: PointMoveAnimatePage.routePath,
        builder: (BuildContext context, GoRouterState state) => PointMoveAnimatePage(),
      ),
    ],
  );
}
