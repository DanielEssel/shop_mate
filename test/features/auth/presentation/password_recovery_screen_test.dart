import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/auth/domain/entities/auth_failure.dart';
import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/auth/presentation/providers/password_recovery_provider.dart';
import 'package:shopmate/features/products/domain/entities/product.dart';
import 'package:shopmate/features/sales/presentation/providers/sales_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';

import '../../../app/app_test_harness.dart';
import '../fake_auth_repository.dart';

const _active = {
  'user-a': ShopAccessStatus.active,
  'user-b': ShopAccessStatus.active,
};

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _type(WidgetTester tester, String label, String text) async {
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.tap(find.text(label));
  await settleApp(tester);
  // Let page transitions finish so only the new page is on screen.
  await tester.pump(const Duration(milliseconds: 500));
}

String _value(WidgetTester tester, String label) {
  return tester.widget<TextFormField>(_field(label)).controller!.text;
}

bool _enabled(WidgetTester tester, String label) {
  final button = find.ancestor(
    of: find.text(label),
    matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
  );
  return tester.widget<ButtonStyleButton>(button).enabled;
}

/// Login -> Forgot password? -> email sent -> code step.
Future<AppHarness> _toCodeStep(WidgetTester tester) async {
  final h = await pumpApp(tester, answers: _active);
  await _type(tester, 'Email', userA.email!);
  await _tap(tester, 'Forgot password?');
  await _tap(tester, 'Send reset code');
  return h;
}

/// ... -> valid code -> new password step, signed in for recovery.
Future<AppHarness> _toPasswordStep(WidgetTester tester) async {
  final h = await _toCodeStep(tester);
  await _type(tester, 'Reset code', '123456');
  await _tap(tester, 'Verify code');
  return h;
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('forgot password', () {
    testWidgets('opens from Login with the email carried over', (tester) async {
      final h = await pumpApp(tester, answers: _active);
      await _type(tester, 'Email', 'ama@gmail.com');

      await _tap(tester, 'Forgot password?');

      expect(h.location, '/forgot-password');
      expect(find.text('Reset your password'), findsOne);
      expect(_value(tester, 'Email'), 'ama@gmail.com');
    });

    testWidgets('an invalid email is rejected before any request', (
      tester,
    ) async {
      final h = await pumpApp(tester, answers: _active);
      await _tap(tester, 'Forgot password?');

      await _type(tester, 'Email', 'ama@');
      await _tap(tester, 'Send reset code');

      expect(find.text('Enter a valid email address.'), findsOne);
      expect(h.auth.resetRequests, isEmpty);
    });

    testWidgets('a valid email requests the code once, with a loading state', (
      tester,
    ) async {
      final h = await pumpApp(tester, answers: _active);
      await _tap(tester, 'Forgot password?');
      await _type(tester, 'Email', ' a@shop.test ');
      final gate = h.auth.resetGate = Completer<void>();

      await tester.tap(find.text('Send reset code'));
      await tester.pump();
      expect(find.bySemanticsLabel('Sending reset code'), findsOne);

      // A second tap and Enter while sending are ignored.
      await tester.tap(find.byType(FilledButton));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      gate.complete();
      await settleApp(tester);

      expect(h.auth.resetRequests, ['a@shop.test']);
      expect(
        find.text('Check your email for the password reset instructions.'),
        findsOne,
      );
      expect(
        find.textContaining('If an account exists for a@shop.test'),
        findsOne,
      );
    });

    testWidgets('typed failures are shown safely', (tester) async {
      final h = await pumpApp(tester, answers: _active);
      h.auth.resetRequestFailure = const AuthFailure(
        AuthFailureKind.tooManyRequests,
        code: 'over_email_send_rate_limit',
      );
      await _tap(tester, 'Forgot password?');
      await _type(tester, 'Email', 'a@shop.test');
      await _tap(tester, 'Send reset code');

      expect(
        find.text('Too many attempts. Please wait a moment and try again.'),
        findsOne,
      );
      expect(find.textContaining('over_email_send'), findsNothing);
      expect(find.text('Reset code'), findsNothing);
    });

    testWidgets('"Send a new code" reuses the 60-second cooldown', (
      tester,
    ) async {
      final h = await _toCodeStep(tester);

      await _tap(tester, 'Send a new code');

      expect(h.auth.resetRequests, [userA.email, userA.email]);
      expect(find.text('Resend available in 60s'), findsOne);
      await tester.pump(const Duration(seconds: 60));
      expect(_enabled(tester, 'Send a new code'), isTrue);
    });
  });

  group('recovery code', () {
    testWidgets('a short code is rejected locally', (tester) async {
      final h = await _toCodeStep(tester);

      await _type(tester, 'Reset code', '123');
      await _tap(tester, 'Verify code');

      expect(find.text('The code has at least 6 digits.'), findsOne);
      expect(h.auth.verifyCalls, isEmpty);
    });

    testWidgets('only digits are accepted', (tester) async {
      await _toCodeStep(tester);

      await _type(tester, 'Reset code', '12a3 4-56');

      expect(_value(tester, 'Reset code'), '123456');
    });

    testWidgets('a wrong or expired code is reported and signs nobody in', (
      tester,
    ) async {
      final h = await _toCodeStep(tester);

      await _type(tester, 'Reset code', '000000');
      await _tap(tester, 'Verify code');

      expect(
        find.text(
          'That code is invalid or has expired. Check your latest email or '
          'send a new code.',
        ),
        findsOne,
      );
      expect(h.container.read(currentUserIdProvider), isNull);
      expect(h.container.read(passwordRecoveryProvider), isNull);
      expect(h.location, '/forgot-password');
    });

    testWidgets('a valid code opens the new-password step and keeps the '
        'recovery session out of the app', (tester) async {
      final h = await _toPasswordStep(tester);

      expect(h.auth.verifyCalls.single, (userA.email!, '123456'));
      expect(h.container.read(currentUserIdProvider), userA.id);
      expect(h.container.read(passwordRecoveryProvider)?.userId, userA.id);
      expect(find.text('Choose a new password'), findsOne);
      // Signed in with an active shop, yet held on the recovery screen.
      expect(h.location, '/forgot-password');

      h.router.go('/dashboard');
      await settleApp(tester);
      expect(h.location, '/forgot-password');
    });
  });

  group('new password', () {
    testWidgets('8 to 72 characters, and both fields must match', (
      tester,
    ) async {
      final h = await _toPasswordStep(tester);

      await _type(tester, 'New password', 'short');
      await _type(tester, 'Confirm new password', 'short');
      await _tap(tester, 'Update password');
      expect(find.text('Use at least 8 characters.'), findsOne);

      await _type(tester, 'New password', 'a' * 73);
      expect(find.text('Use 72 characters or fewer.'), findsOne);

      await _type(tester, 'New password', 'new-secret-1');
      await _type(tester, 'Confirm new password', 'new-secret-2');
      expect(find.text('Passwords do not match.'), findsOne);
      expect(h.auth.passwordUpdates, isEmpty);
    });

    testWidgets('success signs out, clears recovery and returns to Login', (
      tester,
    ) async {
      final h = await _toPasswordStep(tester);
      // State created during the recovery session must not survive it.
      h.container
          .read(saleCartProvider.notifier)
          .addProduct(
            const Product(
              id: 'p1',
              name: 'Rice',
              costPrice: 1,
              sellingPrice: 2,
              stockQuantity: 3,
              lowStockThreshold: 1,
            ),
          );

      await _type(tester, 'New password', 'new-secret-1');
      await _type(tester, 'Confirm new password', 'new-secret-1');
      await _tap(tester, 'Update password');

      expect(h.auth.passwordUpdates, ['new-secret-1']);
      expect(h.container.read(currentUserIdProvider), isNull);
      expect(h.container.read(passwordRecoveryProvider), isNull);
      expect(h.container.read(saleCartProvider), isEmpty);
      expect(h.location, '/login');
      expect(find.text('Password updated'), findsOne);
      expect(find.text('Sign in with your new password.'), findsOne);
    });

    testWidgets('a failure keeps the recovery so another password can be '
        'tried', (tester) async {
      final h = await _toPasswordStep(tester);
      h.auth.updatePasswordFailure = const AuthFailure(
        AuthFailureKind.samePassword,
      );

      await _type(tester, 'New password', 'old-secret-1');
      await _type(tester, 'Confirm new password', 'old-secret-1');
      await _tap(tester, 'Update password');

      expect(
        find.text('Choose a password different from your current one.'),
        findsOne,
      );
      expect(h.location, '/forgot-password');
      expect(h.container.read(currentUserIdProvider), userA.id);
      expect(_enabled(tester, 'Update password'), isTrue);

      h.auth.updatePasswordFailure = null;
      await _type(tester, 'New password', 'new-secret-1');
      await _type(tester, 'Confirm new password', 'new-secret-1');
      await _tap(tester, 'Update password');
      expect(h.location, '/login');
    });

    testWidgets('a double submit sends one update', (tester) async {
      final h = await _toPasswordStep(tester);
      await _type(tester, 'New password', 'new-secret-1');
      await _type(tester, 'Confirm new password', 'new-secret-1');
      final gate = h.auth.updateGate = Completer<void>();

      await tester.tap(find.text('Update password'));
      await tester.pump();
      expect(find.bySemanticsLabel('Updating password'), findsOne);
      await tester.tap(find.byType(FilledButton));
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      gate.complete();
      await settleApp(tester);

      expect(h.auth.passwordUpdates, hasLength(1));
    });

    testWidgets('Cancel signs the recovery session out', (tester) async {
      final h = await _toPasswordStep(tester);

      await _tap(tester, 'Cancel');

      expect(h.auth.passwordUpdates, isEmpty);
      expect(h.container.read(currentUserIdProvider), isNull);
      expect(h.container.read(passwordRecoveryProvider), isNull);
      expect(h.location, '/login');
      expect(find.text('Password updated'), findsNothing);
    });
  });

  group('session', () {
    testWidgets('after a recovery, another account signs in normally', (
      tester,
    ) async {
      final h = await _toPasswordStep(tester);
      await _type(tester, 'New password', 'new-secret-1');
      await _type(tester, 'Confirm new password', 'new-secret-1');
      await _tap(tester, 'Update password');
      expect(h.location, '/login');

      await _type(tester, 'Email', userB.email!);
      await _type(tester, 'Password', 'b-password');
      await _tap(tester, 'Sign In');

      expect(h.container.read(currentUserIdProvider), userB.id);
      expect(h.location, '/dashboard');
    });

    testWidgets('a recovery started for A never holds B', (tester) async {
      final h = await pumpApp(tester, answers: _active);
      h.container.read(passwordRecoveryProvider.notifier).start(userA.email!);

      h.auth.changeUser(userB);
      await settleApp(tester);

      expect(h.location, '/dashboard');
    });

    testWidgets('a signed-in account cannot open the recovery screen', (
      tester,
    ) async {
      final h = await pumpApp(tester, user: userA, answers: _active);
      expect(h.location, '/dashboard');

      h.router.go('/forgot-password');
      await settleApp(tester);

      expect(h.location, '/dashboard');
    });

    testWidgets('sign-in still works, and A3 confirmation handling is intact', (
      tester,
    ) async {
      final h = await pumpApp(tester, answers: _active);
      h.auth.signInFailure = const AuthFailure(
        AuthFailureKind.emailNotConfirmed,
      );
      await _type(tester, 'Email', userA.email!);
      await _type(tester, 'Password', 'a-password');
      await _tap(tester, 'Sign In');
      expect(find.text('Resend Confirmation Email'), findsOne);

      h.auth.signInFailure = null;
      await _tap(tester, 'Sign In');
      expect(h.location, '/dashboard');
    });
  });
}
