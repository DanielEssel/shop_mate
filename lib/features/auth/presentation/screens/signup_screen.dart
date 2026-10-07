import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/auth_credentials.dart';
import '../../domain/entities/auth_failure.dart';
import '../../domain/entities/sign_up_outcome.dart';
import '../providers/auth_provider.dart';
import '../utils/email_input.dart';
import '../utils/password_input.dart';
import '../widgets/auth_email_field.dart';
import '../widgets/auth_notice.dart';
import '../widgets/auth_page_frame.dart';
import '../widgets/resend_confirmation_button.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _submitted = false;
  AuthFailure? _failure;

  /// The address a typo suggestion was already shown for, so a second
  /// submit goes ahead with what the user typed.
  String? _suggestionShownFor;

  /// Set once the account is created and waits for email confirmation.
  String? _confirmationSentTo;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    super.dispose();
  }

  Future<void> _signup() async {
    // Ignores a second tap / Enter while a request is in flight.
    if (_isLoading) return;

    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    // A likely domain typo means the confirmation email would go nowhere:
    // pause once and point at the suggestion. Submitting again keeps the
    // address as typed.
    final email = _emailController.text.trim();
    if (EmailInput.suggestCorrection(email) != null &&
        _suggestionShownFor != email) {
      setState(() => _suggestionShownFor = email);
      _emailFocus.requestFocus();
      return;
    }

    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      final outcome = await ref
          .read(signUpProvider)
          .call(
            AuthCredentials(
              email: _emailController.text,
              password: _passwordController.text,
            ),
          );

      if (!mounted) return;
      TextInput.finishAutofillContext();

      if (outcome == SignUpOutcome.emailConfirmationRequired) {
        setState(() {
          _isLoading = false;
          _confirmationSentTo = email;
        });
      }
      // Signed in straight away: stay in the loading state while the auth
      // session changes and the router moves on.
    } on AuthFailure catch (failure) {
      _fail(failure);
    } catch (error) {
      debugPrint('SIGNUP ERROR: $error');
      _fail(const AuthFailure(AuthFailureKind.unknown));
    }
  }

  void _fail(AuthFailure failure) {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _failure = failure;
    });
  }

  void _clearError(String _) {
    if (_failure == null) return;
    setState(() => _failure = null);
  }

  void _useDifferentEmail() {
    setState(() {
      _confirmationSentTo = null;
      _submitted = false;
      _passwordController.clear();
      _confirmPasswordController.clear();
    });
    _emailFocus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final sentTo = _confirmationSentTo;

    return AuthPageFrame(
      child: sentTo == null
          ? _buildForm(context)
          : _buildConfirmation(context, sentTo),
    );
  }

  Widget _buildForm(BuildContext context) {
    return Form(
      key: _formKey,
      autovalidateMode: _submitted
          ? AutovalidateMode.onUserInteraction
          : AutovalidateMode.disabled,
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AuthHeading(
              title: 'Create your account',
              subtitle: 'Create an account to manage your shop.',
            ),

            const SizedBox(height: AppSpacing.xxl),

            if (_failure case final failure?) ...[
              _buildFailure(failure),
              const SizedBox(height: AppSpacing.lg),
            ],

            AuthEmailField(
              controller: _emailController,
              focusNode: _emailFocus,
              enabled: !_isLoading,
              revealSuggestion: _suggestionShownFor != null,
              onChanged: _clearError,
              onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
            ),

            const SizedBox(height: AppSpacing.lg),

            TextFormField(
              controller: _passwordController,
              focusNode: _passwordFocus,
              enabled: !_isLoading,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Password',
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
              enabled: !_isLoading,
              obscureText: _obscureConfirmPassword,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Confirm Password',
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
              onFieldSubmitted: (_) => _signup(),
            ),

            const SizedBox(height: AppSpacing.xxl),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isLoading ? null : _signup,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                          semanticsLabel: 'Creating account',
                        ),
                      )
                    : const Text('Create Account'),
              ),
            ),

            const SizedBox(height: AppSpacing.lg),

            Center(
              child: TextButton(
                onPressed: _isLoading ? null : () => context.go('/login'),
                child: const Text('Already have an account? Sign in'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFailure(AuthFailure failure) {
    if (failure.kind == AuthFailureKind.emailAlreadyRegistered) {
      return AuthNotice(
        tone: AuthNoticeTone.error,
        message: failure.message,
        child: FilledButton.tonal(
          onPressed: () => context.go('/login'),
          child: const Text('Go to sign in'),
        ),
      );
    }

    return AuthNotice(tone: AuthNoticeTone.error, message: failure.message);
  }

  Widget _buildConfirmation(BuildContext context, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthHeading(
          title: 'Almost there',
          subtitle: 'One more step to finish creating your account.',
        ),

        const SizedBox(height: AppSpacing.xxl),

        AuthNotice(
          tone: AuthNoticeTone.success,
          title: 'Check your email to confirm your account.',
          message:
              'We sent a confirmation link to $email. Open it, then sign in. '
              "If it isn't there, check your spam folder.",
          child: ResendConfirmationButton(email: () => email),
        ),

        const SizedBox(height: AppSpacing.xxl),

        FilledButton(
          onPressed: () => context.go('/login'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Back to sign in'),
        ),

        const SizedBox(height: AppSpacing.sm),

        TextButton(
          onPressed: _useDifferentEmail,
          child: const Text('Use a different email'),
        ),
      ],
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
