import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/auth/presentation/screens/login_screen.dart';
import 'package:shopmate/features/auth/presentation/widgets/auth_notice.dart';

import '../fake_auth_repository.dart';
import 'auth_form_test_harness.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  Future<void> fillAndSubmit(
    WidgetTester tester, {
    String email = 'ama@gmail.com',
    String password = 'secret-pass',
  }) async {
    await enterField(tester, 'Email', email);
    await enterField(tester, 'Password', password);
    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
  }

  testWidgets('signs in through the use case and updates the session', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth);
    await enterField(tester, 'Email', '  ama@gmail.com ');
    await enterField(tester, 'Password', 'secret-pass');

    await tester.tap(find.text('Sign In'));
    await tester.pump();
    await tester.pump();

    expect(auth.signInCalls.single.email, 'ama@gmail.com');
    expect(auth.signInCalls.single.password, 'secret-pass');
    // The session provider picked up the new account; the router (not this
    // screen) navigates from here, so the form stays busy and can't be
    // submitted twice.
    final container = ProviderScope.containerOf(
      tester.element(find.byType(LoginScreen)),
    );
    expect(container.read(authSessionProvider), userA);
    expect(find.byType(AuthNotice), findsNothing);
    expect(find.bySemanticsLabel('Signing in'), findsOne);

    await tester.tap(find.byType(FilledButton));
    await tester.pump();
    expect(auth.signInCalls, hasLength(1));
  });

  testWidgets('invalid input is shown inline and nothing is sent', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth);

    await tester.tap(find.text('Sign In'));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email address.'), findsOne);
    expect(find.text('Enter your password.'), findsOne);

    await enterField(tester, 'Email', 'ama@gmail');
    expect(find.text('Enter a valid email address.'), findsOne);
    expect(auth.signInCalls, isEmpty);
  });

  testWidgets('Enter on the password field submits', (tester) async {
    await pumpAuthScreens(tester, auth);
    await enterField(tester, 'Email', 'ama@gmail.com');
    await enterField(tester, 'Password', 'secret-pass');

    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(auth.signInCalls, hasLength(1));
  });

  testWidgets('unconfirmed email shows the warning with a resend action', (
    tester,
  ) async {
    auth.signInFailure = const AuthFailure(AuthFailureKind.emailNotConfirmed);
    await pumpAuthScreens(tester, auth);

    await fillAndSubmit(tester);

    expect(find.text('Confirm your email'), findsOne);
    expect(find.text('Please confirm your email before signing in.'), findsOne);

    // Resends to the address currently in the field.
    await enterField(tester, 'Email', 'ama.owusu@gmail.com');
    await tester.tap(find.text('Resend Confirmation Email'));
    await tester.pump();

    expect(auth.resendCalls, ['ama.owusu@gmail.com']);
    expect(find.text('Resend available in 60s'), findsOne);
    await tester.pump(const Duration(seconds: 60));
  });

  const messages = {
    AuthFailureKind.invalidCredentials: 'Incorrect email or password.',
    AuthFailureKind.invalidEmail: 'Enter a valid email address.',
    AuthFailureKind.tooManyRequests:
        'Too many attempts. Please wait a moment and try again.',
    AuthFailureKind.network:
        "We couldn't reach ShopMate. Check your internet connection and try "
        'again.',
    AuthFailureKind.unknown: 'Something went wrong. Please try again.',
  };
  messages.forEach((kind, message) {
    testWidgets('${kind.name} shows "$message"', (tester) async {
      auth.signInFailure = AuthFailure(kind, code: 'raw_backend_code');
      await pumpAuthScreens(tester, auth);

      await fillAndSubmit(tester);

      expect(find.text(message), findsOne);
      expect(find.textContaining('raw_backend_code'), findsNothing);
      expect(find.text('Resend Confirmation Email'), findsNothing);
      // The form is usable again.
      expect(isEnabled(tester, 'Sign In'), isTrue);
    });
  });

  testWidgets('editing the form clears a plain error', (tester) async {
    auth.signInFailure = const AuthFailure(AuthFailureKind.invalidCredentials);
    await pumpAuthScreens(tester, auth);
    await fillAndSubmit(tester);
    expect(find.text('Incorrect email or password.'), findsOne);

    await enterField(tester, 'Password', 'another-pass');

    expect(find.text('Incorrect email or password.'), findsNothing);
  });

  testWidgets('a domain typo is suggested, never applied silently', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth);

    await enterField(tester, 'Email', 'ama@gmial.com');
    // Not while the user is still typing in the field.
    expect(find.textContaining('Did you mean'), findsNothing);

    await tester.testTextInput.receiveAction(TextInputAction.next);
    await tester.pumpAndSettle();
    expect(find.text('Did you mean ama@gmail.com?'), findsOne);
    expect(find.text('ama@gmial.com'), findsOne);

    await tester.tap(find.text('Did you mean ama@gmail.com?'));
    await tester.pumpAndSettle();
    expect(find.text('ama@gmail.com'), findsOne);
    expect(find.textContaining('Did you mean'), findsNothing);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await pumpAuthScreens(tester, auth);
    bool obscured() => tester
        .widget<EditableText>(
          find.descendant(
            of: fieldLabelled('Password'),
            matching: find.byType(EditableText),
          ),
        )
        .obscureText;

    expect(obscured(), isTrue);
    await tester.tap(find.byTooltip('Show password'));
    await tester.pump();
    expect(obscured(), isFalse);
    expect(find.byTooltip('Hide password'), findsOne);
  });

  testWidgets('fields offer email and password autofill', (tester) async {
    await pumpAuthScreens(tester, auth);

    expect(find.byType(AutofillGroup), findsOne);
    final email = tester.widget<TextField>(
      find.descendant(
        of: fieldLabelled('Email'),
        matching: find.byType(TextField),
      ),
    );
    final password = tester.widget<TextField>(
      find.descendant(
        of: fieldLabelled('Password'),
        matching: find.byType(TextField),
      ),
    );
    expect(email.autofillHints, [AutofillHints.email]);
    expect(email.textInputAction, TextInputAction.next);
    expect(password.autofillHints, [AutofillHints.password]);
    expect(password.textInputAction, TextInputAction.done);
  });
}
