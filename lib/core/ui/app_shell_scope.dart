import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'layout/breakpoints.dart';

/// Provided by the phone shell so any tab page (even one with its own
/// Scaffold) can open the navigation drawer.
class AppShellScope extends InheritedWidget {
  const AppShellScope({
    super.key,
    required this.openDrawer,
    required super.child,
  });

  final VoidCallback openDrawer;

  static AppShellScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppShellScope>();
  }

  @override
  bool updateShouldNotify(AppShellScope oldWidget) {
    return openDrawer != oldWidget.openDrawer;
  }
}

/// The menu button shown on phone-width tab pages. Hidden from medium width
/// up, where navigation is always on screen.
class AppMenuButton extends StatelessWidget {
  const AppMenuButton({super.key});

  @override
  Widget build(BuildContext context) {
    if (Breakpoints.ofWindow(context).isAtLeastMedium) {
      return const SizedBox.shrink();
    }

    return IconButton(
      tooltip: 'Open menu',
      onPressed: () {
        final scope = AppShellScope.maybeOf(context);
        if (scope != null) {
          scope.openDrawer();
        } else {
          Scaffold.maybeOf(context)?.openDrawer();
        }
      },
      icon: const Icon(Icons.menu_rounded),
      iconSize: 24,
      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
    );
  }

  /// Whether the button renders anything at the current window width.
  static bool isVisible(BuildContext context) {
    return Breakpoints.ofWindow(context).isCompact;
  }
}

/// AppBar leading for the first page of a secondary area (Customers,
/// Purchases, …). Those pages sit in their own navigator, so the automatic
/// back button would not appear; this pops the page beneath through the
/// router. Returns null when the AppBar's own back button applies or there
/// is nothing to go back to (e.g. opened from the desktop sidebar).
Widget? secondaryPageLeading(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && route.canPop) return null;

  final router = GoRouter.maybeOf(context);
  if (router == null || !router.canPop()) return null;

  return BackButton(onPressed: router.pop);
}

/// Back button for a [PageHeader] on a secondary page. Unlike an AppBar,
/// the header has no automatic back button, so this covers both a page
/// pushed in its own navigator and one that sits in a secondary area (see
/// [secondaryPageLeading]). Null when there is nothing to go back to.
Widget? pageHeaderLeading(BuildContext context) {
  final route = ModalRoute.of(context);
  if (route != null && route.canPop) return const BackButton();
  return secondaryPageLeading(context);
}
