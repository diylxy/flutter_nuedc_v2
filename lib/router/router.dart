import 'package:flutter/material.dart';
import 'package:flutter_nuedc_v2/view/page/main_page.dart';
import 'package:flutter_nuedc_v2/view/page/old_page.dart';
import 'package:flutter_nuedc_v2/view/page/settings_page.dart';
import 'package:flutter_nuedc_v2/view/page/splash_page.dart';
import 'package:flutter_nuedc_v2/view/page/three_d_page.dart';
import 'package:flutter_nuedc_v2/view/page/two_d_page.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class Routes {
  static const splash = '/splash';
  static const main = '/';
  static const old = '/old';
  static const twod = '/twod';
  static const threed = '/threed';
  static const settings = '/settings';
}

final Map<String, WidgetBuilder> routes = {
  Routes.splash: (_) {
    return const SplashPage();
  },
  Routes.old: (_) {
    return const OldPage();
  },
  Routes.main: (_) {
    return const MainPage();
  },
  Routes.twod: (_) {
    return const TwodPage();
  },
  Routes.threed: (_) {
    return const ThreedPage();
  },
  Routes.settings: (_) {
    return const SettingsPage();
  },
};

goNamedRoute(String routeName, {dynamic arguments}) {
  if (arguments != null) {
    return navigatorKey.currentState!.pushNamed(
      routeName,
      arguments: arguments,
    );
  } else {
    return navigatorKey.currentState!.pushNamed(routeName);
  }
}

goReplaceNamedRoute(String routeName, {dynamic arguments}) {
  if (arguments != null) {
    return navigatorKey.currentState!.pushReplacementNamed(
      routeName,
      arguments: arguments,
    );
  } else {
    return navigatorKey.currentState!.pushReplacementNamed(routeName);
  }
}

goBack([dynamic result]) {
  if (result != null) {
    return navigatorKey.currentState!.pop(result);
  } else {
    return navigatorKey.currentState!.pop();
  }
}

dynamic getArguments(BuildContext context) {
  return ModalRoute.of(context)?.settings.arguments;
}

BuildContext getContext() {
  return navigatorKey.currentContext!;
}

double getScreenWidth() {
  return MediaQuery.of(getContext()).size.width;
}

double getScreenHeight() {
  return MediaQuery.of(getContext()).size.height;
}
