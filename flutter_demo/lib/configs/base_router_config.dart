import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../pages/customize_tab/customize_tab_page.dart';
import '../pages/home/home_page.dart';

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
    ],
  );
}
