import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/domain/entities/sign_up_outcome.dart';

import '../fake_auth_repository.dart';
import 'auth_form_test_harness.dart';

void main() {
  late FakeAuthRepository auth;

  setUp(() => auth = FakeAuthRepository());

  Future<void> fill(
    WidgetTester tester, {
    String email = 'ama@gmail.com',
    String password = 'secret-pass',
    String? confirm,
  }) async {
    await enterField(tester, 'Email', email);
    await enterField(tester, 'Password', password);
    await enterField(tester, 'Confirm Password', confirm ?? password);
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirmation required shows the check-your-email state', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester, email: ' ama@gmail.com ');
    await submit(tester);

    expect(auth.signUpCalls.single.email, 'ama@gmail.com');
    expect(find.text('Check your email to confirm your account.'), findsOne);
    expect(find.textContaining('ama@gmail.com'), findsWidgets);
    expect(find.text('Create Account'), findsNothing);

    await tester.tap(find.text('Resend Confirmation Email'));
    await tester.pump();
    expect(auth.resendCalls, ['ama@gmail.com']);
    expect(find.text('Resend available in 60s'), findsOne);

    // Leaving for sign in also ends the cooldown timer.
    await tester.tap(find.text('Back to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOne);
  });

  testWidgets('"Use a different email" returns to the form', (tester) async {
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester);
    await submit(tester);

    await tester.tap(find.text('Use a different email'));
    await tester.pumpAndSettle();

    expect(find.text('Create Account'), findsOne);
    expect(find.text('ama@gmail.com'), findsOne);
  });

  testWidgets('an existing account gets a clear message and a way to sign in', (
    tester,
  ) async {
    auth.signUpFailure = const AuthFailure(
      AuthFailureKind.emailAlreadyRegistered,
    );
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester);
    await submit(tester);

    expect(
      find.text(
        'An account with this email already exists. Please sign in instead.',
      ),
      findsOne,
    );

    await tester.tap(find.text('Go to sign in'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome back'), findsOne);
  });

  testWidgets('a weak password from the server is shown inline', (
    tester,
  ) async {
    auth.signUpFailure = const AuthFailure(AuthFailureKind.weakPassword);
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester);
    await submit(tester);

    expect(find.text('Please choose a stronger password.'), findsOne);
    expect(isEnabled(tester, 'Create Account'), isTrue);
  });

  testWidgets('client validation: email, length and matching passwords', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester, email: 'ama@', password: 'short', confirm: 'shorter');
    await submit(tester);

    expect(find.text('Enter a valid email address.'), findsOne);
    expect(find.text('Use at least 8 characters.'), findsOne);
    expect(find.text('Passwords do not match.'), findsOne);
    expect(auth.signUpCalls, isEmpty);
  });

  testWidgets('a domain typo pauses the first submit to suggest a fix', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester, email: 'ama@gmial.com');
    await submit(tester);

    expect(auth.signUpCalls, isEmpty);
    expect(find.text('Did you mean ama@gmail.com?'), findsOne);

    await tester.tap(find.text('Did you mean ama@gmail.com?'));
    await tester.pumpAndSettle();
    await submit(tester);

    expect(auth.signUpCalls.single.email, 'ama@gmail.com');
  });

  testWidgets('submitting again keeps the address exactly as typed', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester, email: 'ama@gmial.com');
    await submit(tester);
    await submit(tester);

    expect(auth.signUpCalls.single.email, 'ama@gmial.com');
  });

  testWidgets('signed in straight away leaves navigation to the router', (
    tester,
  ) async {
    auth.signUpOutcome = SignUpOutcome.signedIn;
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    await fill(tester);
    await tester.ensureVisible(find.text('Create Account'));
    await tester.tap(find.text('Create Account'));
    await tester.pump();

    expect(auth.signUpCalls, hasLength(1));
    expect(find.bySemanticsLabel('Creating account'), findsOne);
    expect(
      find.text('Check your email to confirm your account.'),
      findsNothing,
    );
  });

  testWidgets('keyboard order: email -> password -> confirm -> submit', (
    tester,
  ) async {
    await pumpAuthScreens(tester, auth, initialLocation: '/signup');
    TextField field(String label) => tester.widget<TextField>(
      find.descendant(
        of: fieldLabelled(label),
        matching: find.byType(TextField),
      ),
    );

    expect(field('Email').textInputAction, TextInputAction.next);
    expect(field('Password').textInputAction, TextInputAction.next);
    expect(field('Password').autofillHints, [AutofillHints.newPassword]);
    expect(field('Confirm Password').textInputAction, TextInputAction.done);

    await fill(tester);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(auth.signUpCalls, hasLength(1));
  });
}
