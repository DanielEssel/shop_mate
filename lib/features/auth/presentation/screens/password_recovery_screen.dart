import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/auth_failure.dart';
import '../providers/auth_provider.dart';
import '../providers/password_recovery_provider.dart';
import '../utils/password_input.dart';
import '../widgets/auth_email_field.dart';
import '../widgets/auth_notice.dart';
import '../widgets/auth_page_frame.dart';
import '../widgets/cooldown_resend_button.dart';

enum _Step { email, code, newPassword }

/// Password recovery with an emailed one-time code: enter the email, enter
/// the code, choose a new password. No links or deep links are involved, so
/// it works the same on Windows, Android and iOS.
///
/// Verifying the code signs the account in with a recovery session. The
/// router keeps that session on this screen (see [PasswordRecovery]); after
/// the new password is saved the account is signed out and sent to Login.
class PasswordRecoveryScreen extends ConsumerStatefulWidget {
  const PasswordRecoveryScreen({super.key, this.initialEmail});

  /// Prefilled from the Login form.
  final String? initialEmail;

  /// Code length is a Supabase project setting (6 to 10 digits).
  static const minCodeLength = 6;
  static const maxCodeLength = 10;

  @override
  ConsumerState<PasswordRecoveryScreen> createState() =>
      _PasswordRecoveryScreenState();
}

class _PasswordRecoveryScreenState
    extends ConsumerState<PasswordRecoveryScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _passwordFormKey = GlobalKey<FormState>();

  late final _emailController = TextEditingController(
    text: widget.initialEmail?.trim() ?? '',
  );
  final _codeController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  _Step _step = _Step.email;
  bool _isBusy = false;
  bool _submitted = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  AuthFailure? _failure;

  /// The address the code was sent to.
  String _email = '';

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  PasswordRecoveryNotifier get _recovery =>
      ref.read(passwordRecoveryProvider.notifier);

  /// Runs [action] once at a time with the shared busy/error handling.
  Future<void> _run(Future<void> Function() action) async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _failure = null;
    });
    try {
      await action();
    } on AuthFailure catch (failure) {
      if (mounted) setState(() => _failure = failure);
    } catch (_) {
      if (mounted) {
        setState(() => _failure = const AuthFailure(AuthFailureKind.unknown));
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _sendCode() async {
    if (_isBusy) return;
    setState(() => _submitted = true);
    if (!_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim();
    await _run(() async {
      await ref.read(requestPasswordResetProvider).call(email);
      if (!mounted) return;
      setState(() {
        _email = email;
        _step = _Step.code;
        _submitted = false;
      });
      _codeFocus.requestFocus();
    });
  }

  Future<void> _verifyCode() async {
    if (_isBusy) return;
    setState(() => _submitted = true);
    if (!_codeFormKey.currentState!.validate()) return;

    await _run(() async {
      // Announce the recovery before the session it creates arrives, so the
      // router never treats it as an ordinary sign-in.
      _recovery.start(_email);
      try {
        final user = await ref
            .read(verifyPasswordResetCodeProvider)
            .call(email: _email, code: _codeController.text);
        _recovery.verified(user);
      } catch (_) {
        _recovery.clear();
        rethrow;
      }
      if (!mounted) return;
      setState(() {
        _step = _Step.newPassword;
        _submitted = false;
        _codeController.clear();
      });
      _passwordFocus.requestFocus();
    });
  }

  Future<void> _savePassword() async {
    if (_isBusy) return;
    setState(() => _submitted = true);
    if (!_passwordFormKey.currentState!.validate()) return;

    await _run(() async {
      await ref.read(updatePasswordProvider).call(_passwordController.text);
      TextInput.finishAutofillContext();
      await _endRecovery();
      if (mounted) context.go('/login?reset=done');
    });
  }

  /// Signs the recovery session out (resetting all session-scoped state)
  /// and only then drops the recovery, so the app is never shown in between.
  Future<void> _endRecovery() async {
    if (ref.read(passwordRecoveryProvider)?.userId != null) {
      await ref.read(authSessionProvider.notifier).signOut();
    }
    _recovery.clear();
  }

  Future<void> _cancel() async {
    await _run(() async {
      await _endRecovery();
      if (mounted) context.go('/login');
    });
  }

  void _useDifferentEmail() {
    setState(() {
      _step = _Step.email;
      _failure = null;
      _submitted = false;
      _codeController.clear();
    });
    _emailFocus.requestFocus();
  }

  void _clearError(String _) {
    if (_failure == null) return;
    setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      child: switch (_step) {
        _Step.email => _buildEmailStep(),
        _Step.code => _buildCodeStep(),
        _Step.newPassword => _buildPasswordStep(),
      },
    );
  }

  AutovalidateMode get _autovalidate => _submitted
      ? AutovalidateMode.onUserInteraction
      : AutovalidateMode.disabled;

  List<Widget> _failureNotice() {
    final failure = _failure;
    if (failure == null) return const [];
    return [
      AuthNotice(tone: AuthNoticeTone.error, message: failure.message),
      const SizedBox(height: AppSpacing.lg),
    ];
  }

  Widget _buildEmailStep() {
    return Form(
      key: _emailFormKey,
      autovalidateMode: _autovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeading(
            title: 'Reset your password',
            subtitle:
                "Enter your account's email and we'll send you a code to "
                'reset your password.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          ..._failureNotice(),
          AuthEmailField(
            controller: _emailController,
            focusNode: _emailFocus,
            enabled: !_isBusy,
            revealSuggestion: _submitted,
            onChanged: _clearError,
            onFieldSubmitted: (_) => _sendCode(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _PrimaryButton(
            label: 'Send reset code',
            busyLabel: 'Sending reset code',
            isBusy: _isBusy,
            onPressed: _sendCode,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _isBusy ? null : _cancel,
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildCodeStep() {
    return Form(
      key: _codeFormKey,
      autovalidateMode: _autovalidate,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AuthHeading(
            title: 'Enter your code',
            subtitle: 'The code expires after a short while.',
          ),
          const SizedBox(height: AppSpacing.xxl),
          AuthNotice(
            tone: AuthNoticeTone.success,
            title: 'Check your email for the password reset instructions.',
            // Neutral on purpose: it never says whether the address has an
            // account.
            message:
                'If an account exists for $_email, we sent it a code. '
                "Enter it below. If it isn't there, check your spam folder.",
            child: CooldownResendButton(
              label: 'Send a new code',
              email: () => _email,
              onSend: (email) =>
                  ref.read(requestPasswordResetProvider).call(email),
              sentMessage: (email) => 'A new code was sent to $email.',
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          ..._failureNotice(),
          TextFormField(
            controller: _codeController,
            focusNode: _codeFocus,
            enabled: !_isBusy,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(
                PasswordRecoveryScreen.maxCodeLength,
              ),
            ],
            decoration: const InputDecoration(
              labelText: 'Reset code',
              hintText: '123456',
              prefixIcon: Icon(Icons.pin_outlined),
            ),
            validator: (value) {
              final code = value ?? '';
              if (code.isEmpty) return 'Enter the code from the email.';
              if (code.length < PasswordRecoveryScreen.minCodeLength) {
                return 'The code has at least '
                    '${PasswordRecoveryScreen.minCodeLength} digits.';
              }
              return null;
            },
            onChanged: _clearError,
            onFieldSubmitted: (_) => _verifyCode(),
          ),
          const SizedBox(height: AppSpacing.xxl),
          _PrimaryButton(
            label: 'Verify code',
            busyLabel: 'Verifying code',
            isBusy: _isBusy,
            onPressed: _verifyCode,
          ),
          const SizedBox(height: AppSpacing.sm),
          TextButton(
            onPressed: _isBusy ? null : _useDifferentEmail,
            child: const Text('Use a different email'),
          ),
          TextButton(
            onPressed: _isBusy ? null : _cancel,
            child: const Text('Back to sign in'),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordStep() {
    return Form(
      key: _passwordFormKey,
      autovalidateMode: _autovalidate,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AuthHeading(
              title: 'Choose a new password',
              subtitle: 'For $_email.',
            ),
            const SizedBox(height: AppSpacing.xxl),
            ..._failureNotice(),
            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !_isBusy,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'New password',
                helperText: PasswordInput.helperText,
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: _visibilityToggle(
                  obscured: _obscurePassword,
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: PasswordInput.validateNew,
              onChanged: _clearError,
              onFieldSubmitted: (_) => _confirmPasswordFocus.requestFocus(),
            ),
            const SizedBox(height: AppSpacing.lg),
            TextFormField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocus,
              enabled: !_isBusy,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Confirm new password',
                prefixIcon: const Icon(Icons.lock_outline_rounded),
                suffixIcon: _visibilityToggle(
                  obscured: _obscureConfirmPassword,
                  onPressed: () {
                    setState(() {
                      _obscureConfirmPassword = !_obscureConfirmPassword;
                    });
                  },
                ),
              ),
              validator: (value) => PasswordInput.validateConfirmation(
                value,
                _passwordController.text,
              ),
              onChanged: _clearError,
              onFieldSubmitted: (_) => _savePassword(),
            ),
            const SizedBox(height: AppSpacing.xxl),
            _PrimaryButton(
              label: 'Update password',
              busyLabel: 'Updating password',
              isBusy: _isBusy,
              onPressed: _savePassword,
            ),
            const SizedBox(height: AppSpacing.sm),
            TextButton(
              onPressed: _isBusy ? null : _cancel,
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _visibilityToggle({
    required bool obscured,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: obscured ? 'Show password' : 'Hide password',
      onPressed: onPressed,
      icon: Icon(
        obscured ? Icons.visibility_outlined : Icons.visibility_off_outlined,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    required this.busyLabel,
    required this.isBusy,
    required this.onPressed,
  });

  final String label;
  final String busyLabel;
  final bool isBusy;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: isBusy ? null : onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
      child: isBusy
          ? SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
                semanticsLabel: busyLabel,
              ),
            )
          : Text(label),
    );
  }
}
