import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/auth/presentation/widgets/resend_confirmation_button.dart';

import '../fake_auth_repository.dart';
import 'auth_form_test_harness.dart';

const _resend = 'Resend Confirmation Email';

void main() {
  late FakeAuthRepository auth;
  late String email;

  setUp(() {
    auth = FakeAuthRepository();
    email = 'ama@gmail.com';
  });

  tearDown(() => auth.dispose());

  Future<void> pumpButton(WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authRepositoryProvider.overrideWithValue(auth)],
        child: MaterialApp(
          home: Scaffold(
            body: Center(child: ResendConfirmationButton(email: () => email)),
          ),
        ),
      ),
    );
  }

  testWidgets('sends through the resend use case, then cools down for 60s', (
    tester,
  ) async {
    await pumpButton(tester);
    expect(isEnabled(tester, _resend), isTrue);

    await tester.tap(find.text(_resend));
    await tester.pump();

    expect(auth.resendCalls, ['ama@gmail.com']);
    expect(find.text('Confirmation email sent to ama@gmail.com.'), findsOne);
    expect(find.text('Resend available in 60s'), findsOne);
    expect(isEnabled(tester, 'Resend available in 60s'), isFalse);

    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Resend available in 59s'), findsOne);

    // Tapping during the cooldown does nothing.
    await tester.tap(find.text('Resend available in 59s'));
    await tester.pump(const Duration(seconds: 58));
    expect(find.text('Resend available in 1s'), findsOne);
    expect(auth.resendCalls, hasLength(1));

    await tester.pump(const Duration(seconds: 1));
    expect(find.text(_resend), findsOne);
    expect(isEnabled(tester, _resend), isTrue);

    await tester.tap(find.text(_resend));
    await tester.pump();
    expect(auth.resendCalls, hasLength(2));
  });

  testWidgets('a failure shows the typed message and no cooldown', (
    tester,
  ) async {
    auth.resendFailure = const AuthFailure(AuthFailureKind.tooManyRequests);
    await pumpButton(tester);

    await tester.tap(find.text(_resend));
    await tester.pump();

    expect(
      find.text('Too many attempts. Please wait a moment and try again.'),
      findsOne,
    );
    expect(find.textContaining('Confirmation email sent'), findsNothing);
    expect(isEnabled(tester, _resend), isTrue);
  });

  testWidgets('an invalid address is caught before any request', (
    tester,
  ) async {
    email = 'ama@';
    await pumpButton(tester);

    await tester.tap(find.text(_resend));
    await tester.pump();

    expect(auth.resendCalls, isEmpty);
    expect(find.text('Enter a valid email address.'), findsOne);
  });

  testWidgets('leaving the screen mid-cooldown cancels the timer', (
    tester,
  ) async {
    await pumpButton(tester);
    await tester.tap(find.text(_resend));
    await tester.pump();
    expect(find.text('Resend available in 60s'), findsOne);

    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    await tester.pump(const Duration(seconds: 61));

    // A timer that outlived its widget would fail this test ("A Timer is
    // still pending") and would have thrown on setState after dispose.
    expect(tester.takeException(), isNull);
  });
}
