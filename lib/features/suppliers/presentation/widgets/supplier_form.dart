import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/supplier.dart';

/// Field limits mirror the `public.suppliers` CHECK constraints, which count
/// characters (code points), so the form counts runes rather than UTF-16
/// units.
const supplierNameMaxLength = 120;
const supplierPhoneMaxLength = 40;
const supplierEmailMaxLength = 254;
const supplierAddressMaxLength = 250;
const supplierNotesMaxLength = 1000;

/// Trimmed form values, with blank optional fields as null.
@immutable
class SupplierFormValues {
  const SupplierFormValues({
    required this.name,
    this.phone,
    this.email,
    this.address,
    this.notes,
  });

  final String name;
  final String? phone;
  final String? email;
  final String? address;
  final String? notes;
}

/// Text controllers for the supplier form, owned by the screen's State.
class SupplierFormControllers {
  SupplierFormControllers([Supplier? supplier])
    : name = TextEditingController(text: supplier?.name ?? ''),
      phone = TextEditingController(text: supplier?.phone ?? ''),
      email = TextEditingController(text: supplier?.email ?? ''),
      address = TextEditingController(text: supplier?.address ?? ''),
      notes = TextEditingController(text: supplier?.notes ?? '');

  final TextEditingController name;
  final TextEditingController phone;
  final TextEditingController email;
  final TextEditingController address;
  final TextEditingController notes;

  SupplierFormValues get values {
    return SupplierFormValues(
      name: name.text.trim(),
      phone: _optional(phone.text),
      email: _optional(email.text),
      address: _optional(address.text),
      notes: _optional(notes.text),
    );
  }

  void dispose() {
    name.dispose();
    phone.dispose();
    email.dispose();
    address.dispose();
    notes.dispose();
  }

  static String? _optional(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}

/// Shared add/edit supplier form. The active switch is shown only when
/// [isActive] and [onActiveChanged] are given (edit mode).
class SupplierForm extends StatelessWidget {
  const SupplierForm({
    super.key,
    required this.formKey,
    required this.controllers,
    required this.isSaving,
    required this.submitLabel,
    required this.submitIcon,
    required this.onSubmit,
    this.isActive,
    this.onActiveChanged,
  });

  final GlobalKey<FormState> formKey;
  final SupplierFormControllers controllers;
  final bool isSaving;
  final String submitLabel;
  final IconData submitIcon;
  final VoidCallback onSubmit;
  final bool? isActive;
  final ValueChanged<bool>? onActiveChanged;

  @override
  Widget build(BuildContext context) {
    final isActive = this.isActive;
    final onActiveChanged = this.onActiveChanged;

    return Form(
      key: formKey,
      // Material (not a decorated Container) so the switch tile's ink shows.
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border),
        ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SupplierField(
                controller: controllers.name,
                label: 'Supplier name',
                icon: Icons.storefront_outlined,
                requiredField: true,
                enabled: !isSaving,
                textCapitalization: TextCapitalization.words,
                validator: (value) {
                  final name = value?.trim() ?? '';
                  if (name.isEmpty) return 'Supplier name is required';
                  return _maxLength(name, supplierNameMaxLength);
                },
              ),
              const SizedBox(height: AppSpacing.md),
              _SupplierField(
                controller: controllers.phone,
                label: 'Phone',
                icon: Icons.phone_outlined,
                enabled: !isSaving,
                keyboardType: TextInputType.phone,
                validator: (value) =>
                    _maxLength(value?.trim() ?? '', supplierPhoneMaxLength),
              ),
              const SizedBox(height: AppSpacing.md),
              _SupplierField(
                controller: controllers.email,
                label: 'Email',
                icon: Icons.email_outlined,
                enabled: !isSaving,
                keyboardType: TextInputType.emailAddress,
                validator: _emailValidator,
              ),
              const SizedBox(height: AppSpacing.md),
              _SupplierField(
                controller: controllers.address,
                label: 'Address',
                icon: Icons.location_on_outlined,
                enabled: !isSaving,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    _maxLength(value?.trim() ?? '', supplierAddressMaxLength),
              ),
              const SizedBox(height: AppSpacing.md),
              _SupplierField(
                controller: controllers.notes,
                label: 'Notes',
                icon: Icons.notes_outlined,
                enabled: !isSaving,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                validator: (value) =>
                    _maxLength(value?.trim() ?? '', supplierNotesMaxLength),
              ),
              if (isActive != null && onActiveChanged != null) ...[
                const SizedBox(height: AppSpacing.md),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Active supplier'),
                  subtitle: Text(
                    isActive
                        ? 'Shown in the active supplier list.'
                        : 'Kept for records but hidden from the active list.',
                  ),
                  value: isActive,
                  onChanged: isSaving ? null : onActiveChanged,
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: isSaving ? null : onSubmit,
                  icon: isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(submitIcon),
                  label: Text(isSaving ? 'Saving...' : submitLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? _maxLength(String value, int max) {
    if (value.runes.length > max) {
      return 'Must be $max characters or fewer';
    }
    return null;
  }

  /// Same email pattern as the customer forms; blank is allowed.
  static String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return null;

    final lengthError = _maxLength(email, supplierEmailMaxLength);
    if (lengthError != null) return lengthError;

    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email)) {
      return 'Enter a valid email address';
    }
    return null;
  }
}

class _SupplierField extends StatelessWidget {
  const _SupplierField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.enabled,
    this.requiredField = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool enabled;
  final bool requiredField;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: AppTypography.textTheme.bodyMedium!.copyWith(
        color: AppColors.textPrimary,
      ),
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(icon, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
      ),
    );
  }
}
