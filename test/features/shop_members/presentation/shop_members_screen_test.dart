import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:shopmate/features/auth/presentation/providers/auth_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_access.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_provider.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_member.dart';
import 'package:shopmate/features/shop_members/domain/entities/shop_members_exception.dart';
import 'package:shopmate/features/shop_members/presentation/providers/shop_members_providers.dart';
import 'package:shopmate/features/shop_members/presentation/screens/shop_members_screen.dart';
import 'package:shopmate/features/shop_members/presentation/widgets/shop_member_card.dart';

import '../fake_shop_members_repository.dart';

const _password = 'Temp-Pass-123';

const _desktop = Size(1200, 1000);
const _phone = Size(400, 860);

Future<void> _pump(
  WidgetTester tester,
  FakeShopMembersRepository repository, {
  Size size = _desktop,
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = GoRouter(
    initialLocation: '/users',
    routes: [
      GoRoute(path: '/users', builder: (_, _) => const ShopMembersScreen()),
      GoRoute(
        path: '/more',
        builder: (_, _) => const Scaffold(body: Text('More')),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
        currentUserIdProvider.overrideWithValue(ownerUserId),
        shopMembersRepositoryProvider.overrideWithValue(repository),
        shopAccessProvider.overrideWith(
          (ref) async => const ShopAccess(
            userId: ownerUserId,
            status: ShopAccessStatus.active,
            shopId: 'shop-1',
            shopName: 'Test Shop',
            role: 'owner',
          ),
        ),
      ],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

FakeShopMembersRepository _repository({List<ShopMember>? members}) {
  return FakeShopMembersRepository(
    members:
        members ??
        [
          ownerMember,
          shopMember(
            'staff-1',
            displayName: 'Ama Mensah',
            email: 'ama@shop.test',
          ),
          shopMember(
            'staff-2',
            displayName: 'Kofi Boateng',
            email: 'kofi@shop.test',
            status: ShopMemberStatus.suspended,
          ),
        ],
  );
}

/// Any Material button (Filled, Outlined, Text…) showing [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate((widget) => widget is ButtonStyleButton),
);

Finder _dialogButton(String label) =>
    find.descendant(of: find.byType(AlertDialog), matching: _button(label));

Finder _card(String text) => find.ancestor(
  of: find.textContaining(text),
  matching: find.byType(ShopMemberCard),
);

Finder _inCard(String member, Finder finder) =>
    find.descendant(of: _card(member), matching: finder);

Finder _field(String label) => find.widgetWithText(TextFormField, label);

Future<void> _openForm(WidgetTester tester) async {
  await tester.tap(_button('Add Shop Attendant'));
  await tester.pumpAndSettle();
}

Future<void> _fillForm(
  WidgetTester tester, {
  String name = '  Esi Mensah ',
  String email = '  Esi.Mensah@Shop.TEST ',
  String password = _password,
}) async {
  await tester.enterText(_field('Full name'), name);
  await tester.enterText(_field('Email'), email);
  await tester.enterText(_field('Temporary password'), password);
  await tester.pump();
}

Future<void> _submitForm(WidgetTester tester) async {
  await tester.ensureVisible(_button('Add Attendant'));
  await tester.tap(_button('Add Attendant'));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('member list', () {
    testWidgets('shows a spinner while loading', (tester) async {
      final repository = _repository()..loadGate = Completer<void>();
      await _pump(tester, repository, settle: false);
      await tester.pump();

      expect(find.bySemanticsLabel('Loading shop users'), findsOne);

      repository.loadGate!.complete();
      await tester.pumpAndSettle();
      expect(find.text('Ama Mensah'), findsOne);
    });

    testWidgets('lists the owner and attendants with role and status', (
      tester,
    ) async {
      await _pump(tester, _repository());

      expect(find.text('Users & Permissions'), findsOne);
      expect(find.text('Kwame Owner (You)'), findsOne);
      expect(find.text('Shop Owner'), findsOne);
      expect(find.text('Shop attendants (2)'), findsOne);

      expect(find.text('Ama Mensah'), findsOne);
      expect(find.text('ama@shop.test'), findsOne);
      expect(find.text('Kofi Boateng'), findsOne);
      expect(find.text('kofi@shop.test'), findsOne);
      expect(find.text('Shop Attendant'), findsNWidgets(2));
      expect(_inCard('Ama Mensah', find.text('Active')), findsOne);
      expect(_inCard('Kofi Boateng', find.text('Suspended')), findsOne);
      expect(_inCard('Ama Mensah', _button('Suspend access')), findsOne);
      expect(_inCard('Kofi Boateng', _button('Restore access')), findsOne);
      expect(_button('Revoke access'), findsNWidgets(2));
    });

    testWidgets('the owner has no suspend or revoke controls', (tester) async {
      await _pump(tester, _repository());

      final owner = _card('Kwame Owner');
      expect(owner, findsOne);
      for (final action in ShopMemberAction.values) {
        expect(
          find.descendant(of: owner, matching: find.text(action.label)),
          findsNothing,
          reason: action.label,
        );
      }
    });

    testWidgets('an attendant without a name is shown by email', (
      tester,
    ) async {
      await _pump(
        tester,
        _repository(members: [ownerMember, shopMember('staff-9')]),
      );

      expect(find.text('staff-9@shop.test'), findsOne);
      expect(_button('Suspend access'), findsOne);
    });

    testWidgets('a load error shows a safe message and Retry recovers', (
      tester,
    ) async {
      final repository = _repository()
        ..loadError = const ShopMembersException(
          ShopMembersErrorKind.loadFailed,
          code: 'XX000',
        );
      await _pump(tester, repository);

      expect(find.text('Unable to load shop users'), findsOne);
      expect(find.text(ShopMembersErrorKind.loadFailed.message), findsOne);
      expect(find.textContaining('XX000'), findsNothing);
      expect(find.textContaining('list_shop_members'), findsNothing);

      await tester.tap(_button('Retry'));
      await tester.pumpAndSettle();

      expect(find.text('Ama Mensah'), findsOne);
      expect(repository.loads, 2);
    });

    testWidgets('no attendants: an empty state, the owner still listed', (
      tester,
    ) async {
      await _pump(tester, _repository(members: [ownerMember]));

      expect(find.text('No shop attendants yet'), findsOne);
      expect(find.textContaining('Add a Shop Attendant'), findsOne);
      expect(find.text('Kwame Owner (You)'), findsOne);
      expect(_button('Add Shop Attendant'), findsOne);
    });

    testWidgets('works at phone width', (tester) async {
      await _pump(tester, _repository(), size: _phone);

      expect(tester.takeException(), isNull);
      expect(find.text('Ama Mensah'), findsOne);
      expect(_button('Add Shop Attendant'), findsOne);
    });
  });

  group('suspend, restore and revoke', () {
    testWidgets('suspend asks first; Cancel changes nothing', (tester) async {
      final repository = _repository();
      await _pump(tester, repository);

      await tester.tap(_inCard('Ama Mensah', _button('Suspend access')));
      await tester.pumpAndSettle();

      expect(find.text('Suspend access for Ama Mensah?'), findsOne);
      expect(
        find.text(
          'The attendant will no longer be able to access this shop until '
          'their access is restored.',
        ),
        findsOne,
      );

      await tester.tap(_dialogButton('Cancel'));
      await tester.pumpAndSettle();

      expect(repository.actions, isEmpty);
      expect(_inCard('Ama Mensah', find.text('Active')), findsOne);
    });

    testWidgets('a confirmed suspend updates the list', (tester) async {
      final repository = _repository();
      await _pump(tester, repository);

      await tester.tap(_inCard('Ama Mensah', _button('Suspend access')));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('Suspend access'));
      await tester.pumpAndSettle();

      expect(repository.actions, ['suspend staff-1']);
      expect(find.text("Ama Mensah's access is suspended."), findsOne);
      expect(_inCard('Ama Mensah', find.text('Suspended')), findsOne);
      expect(_inCard('Ama Mensah', _button('Restore access')), findsOne);
    });

    testWidgets('restore asks first, then restores access', (tester) async {
      final repository = _repository();
      await _pump(tester, repository);

      await tester.tap(_inCard('Kofi Boateng', _button('Restore access')));
      await tester.pumpAndSettle();

      expect(find.text('Restore access for Kofi Boateng?'), findsOne);
      expect(
        find.text("This will restore the attendant's access to this shop."),
        findsOne,
      );

      await tester.tap(_dialogButton('Restore access'));
      await tester.pumpAndSettle();

      expect(repository.actions, ['restore staff-2']);
      expect(find.text("Kofi Boateng's access is restored."), findsOne);
      expect(_inCard('Kofi Boateng', find.text('Active')), findsOne);
    });

    testWidgets('revoke explains the account is kept, then removes them', (
      tester,
    ) async {
      final repository = _repository();
      await _pump(tester, repository);

      await tester.tap(_inCard('Ama Mensah', _button('Revoke access')));
      await tester.pumpAndSettle();

      expect(find.text('Revoke access for Ama Mensah?'), findsOne);
      expect(
        find.text(
          "Revoking removes this attendant's access to your shop. Their "
          'ShopMate account is not deleted.',
        ),
        findsOne,
      );
      expect(find.textContaining('Delete account'), findsNothing);

      await tester.tap(_dialogButton('Cancel'));
      await tester.pumpAndSettle();
      expect(repository.actions, isEmpty);

      await tester.tap(_inCard('Ama Mensah', _button('Revoke access')));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('Revoke access'));
      await tester.pumpAndSettle();

      expect(repository.actions, ['revoke staff-1']);
      expect(
        find.text("Ama Mensah's access to your shop is revoked."),
        findsOne,
      );
      expect(_card('Ama Mensah'), findsNothing);
      expect(find.text('Shop attendants (1)'), findsOne);
    });

    testWidgets('a change made elsewhere shows a safe error and reloads', (
      tester,
    ) async {
      final repository = _repository()
        ..actionError = const ShopMembersException(
          ShopMembersErrorKind.statusChanged,
          code: '55000',
        );
      await _pump(tester, repository);
      final loadsBefore = repository.loads;

      await tester.tap(_inCard('Ama Mensah', _button('Suspend access')));
      await tester.pumpAndSettle();
      await tester.tap(_dialogButton('Suspend access'));
      await tester.pumpAndSettle();

      expect(find.text(ShopMembersErrorKind.statusChanged.message), findsOne);
      expect(find.textContaining('55000'), findsNothing);
      expect(repository.loads, greaterThan(loadsBefore));
    });
  });

  group('add shop attendant', () {
    testWidgets('empty fields are rejected before anything is sent', (
      tester,
    ) async {
      final repository = _repository();
      await _pump(tester, repository);
      await _openForm(tester);

      expect(find.text('Add Shop Attendant'), findsWidgets);
      expect(
        find.text(
          'The attendant will use this temporary password to sign in. They '
          'should change it after their first login.',
        ),
        findsOne,
      );

      await _submitForm(tester);

      expect(find.text("Enter the attendant's full name."), findsOne);
      expect(find.text("Enter the attendant's email address."), findsOne);
      expect(find.text('Enter a temporary password.'), findsOne);
      expect(repository.created, isEmpty);
    });

    testWidgets('an invalid email is rejected', (tester) async {
      final repository = _repository();
      await _pump(tester, repository);
      await _openForm(tester);

      await _fillForm(tester, email: 'not-an-email');
      await _submitForm(tester);

      expect(find.text('Enter a valid email address.'), findsOne);
      expect(repository.created, isEmpty);
    });

    testWidgets('invalid temporary passwords are rejected', (tester) async {
      final repository = _repository();
      await _pump(tester, repository);
      await _openForm(tester);

      final cases = {
        'short': 'Use at least 8 characters.',
        '          ': 'The password cannot be only spaces.',
        'x' * 73: 'Use a shorter password (72 characters or fewer).',
        'ESI.mensah@shop.test': 'The password cannot be the email address.',
      };
      for (final MapEntry(key: password, value: message) in cases.entries) {
        await _fillForm(tester, password: password);
        await _submitForm(tester);
        expect(find.text(message), findsOne, reason: password);
      }
      expect(repository.created, isEmpty);
    });

    testWidgets('a name with a line break is rejected', (tester) async {
      final repository = _repository();
      await _pump(tester, repository);
      await _openForm(tester);

      await _fillForm(tester, name: 'Esi\tMensah');
      await _submitForm(tester);

      expect(find.text('Remove line breaks and tabs from the name.'), findsOne);
      expect(repository.created, isEmpty);
    });

    testWidgets('the password can be shown and hidden', (tester) async {
      await _pump(tester, _repository());
      await _openForm(tester);
      await _fillForm(tester);

      EditableText password() => tester.widget<EditableText>(
        find.descendant(
          of: _field('Temporary password'),
          matching: find.byType(EditableText),
        ),
      );

      expect(password().obscureText, isTrue);
      await tester.tap(find.byTooltip('Show password'));
      await tester.pump();
      expect(password().obscureText, isFalse);
      await tester.tap(find.byTooltip('Hide password'));
      await tester.pump();
      expect(password().obscureText, isTrue);
    });

    testWidgets('success sends normalized input, refreshes and confirms', (
      tester,
    ) async {
      final repository = _repository();
      await _pump(tester, repository);
      await _openForm(tester);
      await _fillForm(tester);
      await _submitForm(tester);

      final request = repository.created.single;
      expect(request.email, 'esi.mensah@shop.test');
      expect(request.displayName, 'Esi Mensah');
      expect(request.temporaryPassword, _password);

      // The form is closed, the list reloaded, and the password is gone.
      expect(find.byType(TextFormField), findsNothing);
      expect(find.text('Esi Mensah'), findsOne);
      expect(find.text('Shop attendants (3)'), findsOne);
      expect(
        find.text(
          'Shop attendant created. A confirmation email has been sent to '
          'esi.mensah@shop.test.',
        ),
        findsOne,
      );
      expect(find.textContaining(_password), findsNothing);
    });

    testWidgets('if the confirmation email failed, the owner is told', (
      tester,
    ) async {
      final repository = _repository()..confirmationEmailSent = false;
      await _pump(tester, repository);
      await _openForm(tester);
      await _fillForm(tester);
      await _submitForm(tester);

      expect(find.textContaining("confirmation email couldn't"), findsOne);
    });

    testWidgets('the button is disabled while the request runs', (
      tester,
    ) async {
      final repository = _repository()..createGate = Completer<void>();
      await _pump(tester, repository);
      await _openForm(tester);
      await _fillForm(tester);
      await tester.tap(_button('Add Attendant'));
      await tester.pump();

      expect(find.bySemanticsLabel('Creating attendant'), findsOne);
      final submit = tester.widget<FilledButton>(
        find.ancestor(
          of: find.bySemanticsLabel('Creating attendant'),
          matching: find.byType(FilledButton),
        ),
      );
      expect(submit.onPressed, isNull);

      repository.createGate!.complete();
      await tester.pumpAndSettle();
      expect(repository.created, hasLength(1));
    });

    testWidgets('an existing email keeps the form open with a clear error', (
      tester,
    ) async {
      final repository = _repository()
        ..createError = const ShopMembersException(
          ShopMembersErrorKind.emailExists,
          code: 'email_exists',
        );
      await _pump(tester, repository);
      await _openForm(tester);
      await _fillForm(tester);
      await _submitForm(tester);

      expect(
        find.text(
          'This email already has a ShopMate account. Use another email '
          'address.',
        ),
        findsOne,
      );
      expect(_field('Email'), findsOne);
      expect(find.text('Shop attendants (2)'), findsOne);
      // The password stays only in its own, still hidden, field for a retry.
      final matches = find.textContaining(_password).evaluate().toList();
      expect(matches, hasLength(1));
      final field = matches.single.widget;
      expect(field, isA<EditableText>());
      expect((field as EditableText).obscureText, isTrue);
    });

    testWidgets('on a phone the form opens as a sheet and still works', (
      tester,
    ) async {
      final repository = _repository();
      await _pump(tester, repository, size: _phone);
      await _openForm(tester);

      expect(find.byType(BottomSheet), findsOne);
      await _fillForm(tester);
      await _submitForm(tester);

      expect(repository.created, hasLength(1));
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Esi Mensah'), findsOne);
    });
  });

  group('layout', () {
    final longMembers = [
      ownerMember,
      shopMember(
        'staff-1',
        displayName: 'Akosua Darko-Appiah Mensah-Bonsu Owusu-Ansah',
        email: 'akosua.darko-appiah.mensah-bonsu@kaneshie-market-branch.test',
      ),
      shopMember(
        'staff-2',
        displayName: 'Kofi Boateng',
        email: 'kofi@shop.test',
        status: ShopMemberStatus.suspended,
      ),
    ];

    for (final (label, size) in [
      ('320px', const Size(320, 1600)),
      ('tablet', const Size(820, 1400)),
      ('desktop', const Size(1440, 1000)),
    ]) {
      testWidgets('long member details fit at $label', (tester) async {
        await _pump(tester, _repository(members: longMembers), size: size);

        expect(tester.takeException(), isNull);
        expect(find.text('Users & Permissions'), findsOne);
        expect(_button('Add Shop Attendant').hitTestable(), findsOne);
        // Every attendant keeps reachable actions; the owner has none.
        expect(_button('Revoke access'), findsNWidgets(2));
        expect(_inCard('Kofi Boateng', _button('Restore access')), findsOne);
      });
    }

    testWidgets('the add form fits at 320px and keeps its actions', (
      tester,
    ) async {
      await _pump(tester, _repository(), size: const Size(320, 700));
      await _openForm(tester);

      expect(tester.takeException(), isNull);
      expect(_button('Add Attendant').hitTestable(), findsOne);
      expect(_button('Cancel').hitTestable(), findsOne);
    });

    testWidgets('suspend and revoke confirm destructively; restore does not', (
      tester,
    ) async {
      await _pump(tester, _repository());

      Color? confirmColor(String label) => tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byType(AlertDialog),
              matching: find.widgetWithText(FilledButton, label),
            ),
          )
          .style
          ?.backgroundColor
          ?.resolve({});

      await tester.tap(_inCard('Ama Mensah', _button('Revoke access')));
      await tester.pumpAndSettle();
      expect(confirmColor('Revoke access'), isNotNull);
      await tester.tap(_dialogButton('Cancel'));
      await tester.pumpAndSettle();

      await tester.tap(_inCard('Kofi Boateng', _button('Restore access')));
      await tester.pumpAndSettle();
      expect(confirmColor('Restore access'), isNull);
      await tester.tap(_dialogButton('Cancel'));
      await tester.pumpAndSettle();
    });
  });
}
