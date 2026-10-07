import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/auth_provider.dart';
import 'cooldown_resend_button.dart';

/// "Resend Confirmation Email" for an account that hasn't confirmed its
/// address yet, with the shared 60-second cooldown.
class ResendConfirmationButton extends ConsumerWidget {
  const ResendConfirmationButton({
    super.key,
    required this.email,
    this.cooldown = CooldownResendButton.defaultCooldown,
  });

  /// Read when the button is pressed, so it always uses the current address.
  final ValueGetter<String> email;
  final Duration cooldown;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CooldownResendButton(
      label: 'Resend Confirmation Email',
      email: email,
      cooldown: cooldown,
      onSend: (address) =>
          ref.read(resendEmailConfirmationProvider).call(address),
      sentMessage: (address) => 'Confirmation email sent to $address.',
    );
  }
}
