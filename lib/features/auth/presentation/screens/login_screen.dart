import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/auth_credentials.dart';
import '../../domain/entities/auth_failure.dart';
import '../providers/auth_provider.dart';
import '../widgets/auth_email_field.dart';
import '../widgets/auth_notice.dart';
import '../widgets/auth_page_frame.dart';
import '../widgets/resend_confirmation_button.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.passwordUpdated = false});

  /// Arrived here right after resetting the password.
  final bool passwordUpdated;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _submitted = false;
  AuthFailure? _failure;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // Ignores a second tap / Enter while a request is in flight.
    if (_isLoading) return;

    setState(() => _submitted = true);
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _failure = null;
    });

    try {
      await ref
          .read(signInProvider)
          .call(
            AuthCredentials(
              email: _emailController.text,
              password: _passwordController.text,
            ),
          );

      TextInput.finishAutofillContext();
      // Stay in the loading state: the auth session now changes and the
      // router takes this account to the right screen.
    } on AuthFailure catch (failure) {
      _fail(failure);
    } catch (error) {
      debugPrint('LOGIN ERROR: $error');
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

  /// Editing the form clears a plain error; the confirm-email card stays so
  /// its resend button keeps working while the address is corrected.
  void _clearError(String _) {
    final failure = _failure;
    if (failure == null || failure.kind == AuthFailureKind.emailNotConfirmed) {
      return;
    }
    setState(() => _failure = null);
  }

  @override
  Widget build(BuildContext context) {
    return AuthPageFrame(
      child: Form(
        key: _formKey,
        autovalidateMode: _submitted
            ? AutovalidateMode.onUserInteraction
            : AutovalidateMode.disabled,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),

              const SizedBox(height: AppSpacing.xxl),

              if (_failure case final failure?) ...[
                _buildFailure(failure),
                const SizedBox(height: AppSpacing.lg),
              ] else if (widget.passwordUpdated) ...[
                const AuthNotice(
                  tone: AuthNoticeTone.success,
                  title: 'Password updated',
                  message: 'Sign in with your new password.',
                ),
                const SizedBox(height: AppSpacing.lg),
              ],

              AuthEmailField(
                controller: _emailController,
                focusNode: _emailFocus,
                enabled: !_isLoading,
                revealSuggestion: _submitted,
                onChanged: _clearError,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),

              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _passwordController,
                focusNode: _passwordFocus,
                enabled: !_isLoading,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: 'Enter your password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    tooltip: _obscurePassword
                        ? 'Show password'
                        : 'Hide password',
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Enter your password.';
                  }
                  return null;
                },
                onChanged: _clearError,
                onFieldSubmitted: (_) => _login(),
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _isLoading
                      ? null
                      : () => context.go(
                          '/forgot-password',
                          extra: _emailController.text.trim(),
                        ),
                  child: const Text('Forgot password?'),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _isLoading ? null : _login,
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
                            semanticsLabel: 'Signing in',
                          ),
                        )
                      : const Text('Sign In'),
                ),
              ),

              const SizedBox(height: AppSpacing.lg),

              Center(
                child: TextButton(
                  onPressed: _isLoading ? null : () => context.go('/signup'),
                  child: const Text("Don't have an account? Sign up"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFailure(AuthFailure failure) {
    if (failure.kind == AuthFailureKind.emailNotConfirmed) {
      return AuthNotice(
        tone: AuthNoticeTone.warning,
        title: 'Confirm your email',
        message: failure.message,
        child: ResendConfirmationButton(email: () => _emailController.text),
      );
    }

    return AuthNotice(tone: AuthNoticeTone.error, message: failure.message);
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back',
          style: Theme.of(
            context,
          ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          'Sign in to manage your ShopMate.',
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
