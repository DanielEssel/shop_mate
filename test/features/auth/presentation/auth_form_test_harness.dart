import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/auth/presentation/screens/login_screen.dart';
import 'package:shopmate/features/auth/presentation/screens/signup_screen.dart';

import '../fake_auth_repository.dart';

/// Login and Signup on a minimal router, backed by [auth].
Future<GoRouter> pumpAuthScreens(
  WidgetTester tester,
  FakeAuthRepository auth, {
  String initialLocation = '/login',
  Size size = const Size(420, 1000),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(path: '/signup', builder: (_, _) => const SignupScreen()),
    ],
  );
  addTearDown(router.dispose);
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [authRepositoryProvider.overrideWithValue(auth)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  await tester.pumpAndSettle();
  return router;
}

Finder fieldLabelled(String label) => find.widgetWithText(TextFormField, label);

Future<void> enterField(WidgetTester tester, String label, String text) async {
  await tester.enterText(fieldLabelled(label), text);
  await tester.pump();
}

Finder buttonLabelled(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

/// Whether the button showing [label] can be pressed.
bool isEnabled(WidgetTester tester, String label) {
  return tester.widget<ButtonStyleButton>(buttonLabelled(label)).enabled;
}
