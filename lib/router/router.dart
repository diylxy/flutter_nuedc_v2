import 'package:flutter/material.dart';
import 'package:flutter_nuedc_v2/view/page/old_page.dart';
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class Routes {
  static const old = '/old';
}

final Map<String, WidgetBuilder> routes = {
  Routes.old: (_) {
    return const OldPage();
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
