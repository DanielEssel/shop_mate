import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/new_shop_attendant.dart';
import '../../domain/entities/shop_members_exception.dart';
import '../providers/shop_members_providers.dart';
import '../utils/attendant_input.dart';

/// Opens the Add Shop Attendant form as a centered dialog on wide (desktop)
/// layouts and as a modal bottom sheet on phones.
///
/// Returns the created account, or null when the form was closed.
Future<CreatedShopAttendant?> showAddShopAttendantForm(
  BuildContext context,
) async {
  final isDesktop = MediaQuery.sizeOf(context).width >= 900;

  if (isDesktop) {
    return showDialog<CreatedShopAttendant>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          insetPadding: const EdgeInsets.all(AppSpacing.md),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 520,
              maxHeight: MediaQuery.sizeOf(dialogContext).height * 0.92,
            ),
            child: const AddShopAttendantForm(),
          ),
        );
      },
    );
  }

  return showModalBottomSheet<CreatedShopAttendant>(
    context: context,
    isScrollControlled: true,
    useRootNavigator: true,
    useSafeArea: true,
    enableDrag: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
    ),
    builder: (sheetContext) {
      // Lift the form above the keyboard; the field list scrolls inside.
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
          ),
          child: const AddShopAttendantForm(),
        ),
      );
    },
  );
}

/// Creates a Shop Attendant login through the `create-shop-attendant` Edge
/// Function. The temporary password lives only in its text field and the
/// one request; it is never stored, logged or shown again.
class AddShopAttendantForm extends ConsumerStatefulWidget {
  const AddShopAttendantForm({super.key});

  @override
  ConsumerState<AddShopAttendantForm> createState() =>
      _AddShopAttendantFormState();
}

class _AddShopAttendantFormState extends ConsumerState<AddShopAttendantForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _submitError;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _clearError() {
    if (_submitError != null) setState(() => _submitError = null);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _isSubmitting = true;
      _submitError = null;
    });

    try {
      final created = await ref
          .read(createShopAttendantProvider)
          .call(
            NewShopAttendant(
              email: AttendantInput.normalizeEmail(_emailController.text),
              displayName: AttendantInput.normalizeName(_nameController.text),
              temporaryPassword: _passwordController.text,
            ),
          );
      if (!mounted) return;
      // Nothing about the password outlives the form.
      _passwordController.clear();
      Navigator.of(context).pop(created);
    } on ShopMembersException catch (error) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _submitError = ShopMembersErrorKind.createFailed.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final submitError = _submitError;

    return PopScope(
      canPop: !_isSubmitting,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Add Shop Attendant',
                        style: AppTypography.textTheme.titleLarge?.copyWith(
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Create a login for someone who works in your shop.',
                        style: AppTypography.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _isSubmitting
                      ? null
                      : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    FieldRow(
                      children: [
                        TextFormField(
                          controller: _nameController,
                          enabled: !_isSubmitting,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Full name',
                            prefixIcon: Icon(Icons.person_outline_rounded),
                          ),
                          validator: AttendantInput.validateName,
                          onChanged: (_) => _clearError(),
                        ),
                        TextFormField(
                          controller: _emailController,
                          enabled: !_isSubmitting,
                          keyboardType: TextInputType.emailAddress,
                          autocorrect: false,
                          enableSuggestions: false,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.mail_outline_rounded),
                          ),
                          validator: AttendantInput.validateEmail,
                          onChanged: (_) => _clearError(),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.md),
                    // No autofill hints: this is someone else's password and
                    // must not be saved to the owner's password manager.
                    TextFormField(
                      controller: _passwordController,
                      enabled: !_isSubmitting,
                      obscureText: _obscurePassword,
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        labelText: 'Temporary password',
                        helperText: AttendantInput.passwordHelperText,
                        helperMaxLines: 3,
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
                      validator: (value) =>
                          AttendantInput.validateTemporaryPassword(
                            value,
                            _emailController.text,
                          ),
                      onChanged: (_) => _clearError(),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    if (submitError != null) ...[
                      const SizedBox(height: AppSpacing.md),
                      _SubmitErrorBanner(message: submitError),
                    ],
                  ],
                ),
              ),
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _isSubmitting ? null : _submit,
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              semanticsLabel: 'Creating attendant',
                            ),
                          )
                        : const Text('Add Attendant'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitErrorBanner extends StatelessWidget {
  const _SubmitErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(
              Icons.error_outline_rounded,
              size: 20,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.danger,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
