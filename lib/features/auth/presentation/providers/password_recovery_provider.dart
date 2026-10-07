import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/auth_user.dart';
import 'auth_provider.dart';

/// A password recovery in progress. Verifying the emailed code signs the
/// account in with a recovery session; while this matches the signed-in
/// account, the router keeps it on the recovery screen until a new password
/// is set, instead of letting it into the app.
@immutable
class PasswordRecovery {
  const PasswordRecovery({required this.email, this.userId});

  /// Lower-cased address the code was sent to.
  final String email;

  /// Set once the code is verified: the recovering account.
  final String? userId;

  /// Whether the signed-in account ([userId], [email]) is the one recovering.
  /// Before the code is verified only the address is known.
  bool belongsTo({required String? userId, required String? email}) {
    final recoveringId = this.userId;
    if (recoveringId != null) return recoveringId == userId;
    return email != null && email.trim().toLowerCase() == this.email;
  }
}

final passwordRecoveryProvider =
    NotifierProvider<PasswordRecoveryNotifier, PasswordRecovery?>(
      PasswordRecoveryNotifier.new,
    );

class PasswordRecoveryNotifier extends Notifier<PasswordRecovery?> {
  @override
  PasswordRecovery? build() {
    // Once the recovering account signs out (or another one signs in), the
    // recovery is over: it never carries over to a different session.
    ref.listen<String?>(currentUserIdProvider, (_, next) {
      final recoveringId = state?.userId;
      if (recoveringId != null && next != recoveringId) state = null;
    });
    return null;
  }

  /// Call just before verifying the code, so the recovery session it creates
  /// is recognised from its first event.
  void start(String email) {
    state = PasswordRecovery(email: email.trim().toLowerCase());
  }

  void verified(AuthUser user) {
    final current = state;
    if (current == null) return;
    state = PasswordRecovery(email: current.email, userId: user.id);
  }

  void clear() => state = null;
}
