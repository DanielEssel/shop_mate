import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_spacing.dart';
import '../providers/shop_provider.dart';
import '../widgets/shop_gate_frame.dart';

class RegisterShopScreen extends ConsumerStatefulWidget {
  const RegisterShopScreen({super.key});

  @override
  ConsumerState<RegisterShopScreen> createState() =>
      _RegisterShopScreenState();
}

class _RegisterShopScreenState extends ConsumerState<RegisterShopScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _phoneFocusNode = FocusNode();

  AutovalidateMode _autovalidateMode = AutovalidateMode.disabled;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  /// Accepts local Ghana formats and returns international form:
  /// 024 123 4567 -> +233241234567, 233241234567 -> +233241234567.
  /// Anything else is passed through and validated as-is.
  String _normalizePhone(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s\-()]'), '');

    if (RegExp(r'^0\d{9}$').hasMatch(cleaned)) {
      return '+233${cleaned.substring(1)}';
    }

    if (RegExp(r'^233\d{9}$').hasMatch(cleaned)) {
      return '+$cleaned';
    }

    return cleaned;
  }

  Future<void> _submit() async {
    // Prevents double submits (button tap + keyboard "done").
    if (_isSubmitting) return;

    if (!_formKey.currentState!.validate()) {
      setState(() {
        _autovalidateMode = AutovalidateMode.onUserInteraction;
      });

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref.read(shopRepositoryProvider).registerShop(
            name: _nameController.text.trim(),
            phone: _normalizePhone(_phoneController.text),
          );

      // Re-check access. The router then moves this user to the
      // "Waiting for approval" screen.
      ref.invalidate(shopAccessProvider);
    } catch (error) {
      debugPrint('REGISTER SHOP ERROR: $error');

      // The account already has a shop (e.g. registered on another device):
      // just refresh, and the router will send the user to the right place.
      if (error is PostgrestException &&
          error.message.contains('already belongs')) {
        ref.invalidate(shopAccessProvider);
        return;
      }

      if (!mounted) return;

      setState(() {
        _errorMessage = _friendlyMessage(error);
      });
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _clearError() {
    if (_errorMessage == null) return;

    setState(() {
      _errorMessage = null;
    });
  }

  String _friendlyMessage(Object error) {
    // register_shop raises plain-English messages (code P0001), such as
    // "Please verify your email before registering a shop".
    if (error is PostgrestException) {
      if (error.code == 'P0001') {
        return error.message;
      }

      return 'Unable to register your shop. Please try again.';
    }

    final text = error.toString().toLowerCase();

    if (text.contains('socketexception') ||
        text.contains('failed host lookup') ||
        text.contains('clientexception')) {
      return "Can't reach ShopMate. "
          'Check your internet connection and try again.';
    }

    return 'Unable to register your shop. Please try again.';
  }

  @override
  Widget build(BuildContext context) {
    return ShopGateFrame(
      footer: const SignedInFooter(),
      child: Form(
        key: _formKey,
        child: AutofillGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const GateHeading(
                title: 'Register your shop',
                message: 'Tell us about your business. We review every new '
                    'shop before it goes live.',
              ),

              const SizedBox(height: AppSpacing.xxl),

              GateErrorBanner(message: _errorMessage),

              TextFormField(
                controller: _nameController,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.organizationName],
                autovalidateMode: _autovalidateMode,
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _phoneFocusNode.requestFocus(),
                decoration: const InputDecoration(
                  labelText: 'Shop name',
                  hintText: 'e.g. Faith Provisions',
                  prefixIcon: Icon(Icons.storefront_outlined),
                ),
                validator: (value) {
                  final name = value?.trim() ?? '';

                  if (name.isEmpty) {
                    return 'Enter your shop name.';
                  }

                  if (name.length < 2 || name.length > 80) {
                    return 'Shop name must be 2 to 80 characters.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.lg),

              TextFormField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.telephoneNumber],
                autovalidateMode: _autovalidateMode,
                onChanged: (_) => _clearError(),
                onFieldSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  hintText: '024 123 4567',
                  helperText: 'We use this number to verify your shop.',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (value) {
                  final phone = _normalizePhone(value ?? '');

                  if (!RegExp(r'^\+?[0-9]{9,15}$').hasMatch(phone)) {
                    return 'Enter a valid phone number, e.g. 024 123 4567.';
                  }

                  return null;
                },
              ),

              const SizedBox(height: AppSpacing.xxl),

              GatePrimaryButton(
                label: 'Submit for approval',
                loadingLabel: 'Submitting…',
                isLoading: _isSubmitting,
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
