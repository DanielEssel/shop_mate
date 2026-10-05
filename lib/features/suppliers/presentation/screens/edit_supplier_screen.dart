import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/supplier.dart';
import '../providers/supplier_providers.dart';
import '../utils/supplier_error_message.dart';
import '../widgets/supplier_form.dart';

/// Edits a supplier's details and active status. id, shop, creator and
/// creation date are not editable.
class EditSupplierScreen extends ConsumerStatefulWidget {
  const EditSupplierScreen({super.key, required this.supplierId});

  final String supplierId;

  @override
  ConsumerState<EditSupplierScreen> createState() => _EditSupplierScreenState();
}

class _EditSupplierScreenState extends ConsumerState<EditSupplierScreen> {
  final _formKey = GlobalKey<FormState>();

  /// Created once from the loaded supplier, so a background refresh never
  /// overwrites what the user is typing.
  SupplierFormControllers? _controllers;
  bool _isActive = true;
  bool _isSaving = false;

  @override
  void dispose() {
    _controllers?.dispose();
    super.dispose();
  }

  SupplierFormControllers _controllersFor(Supplier supplier) {
    final existing = _controllers;
    if (existing != null) return existing;

    _isActive = supplier.isActive;
    return _controllers = SupplierFormControllers(supplier);
  }

  Future<void> _save(SupplierFormControllers controllers) async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final values = controllers.values;
    setState(() => _isSaving = true);

    try {
      await ref
          .read(updateSupplierProvider)
          .call(
            id: widget.supplierId,
            name: values.name,
            isActive: _isActive,
            phone: values.phone,
            email: values.email,
            address: values.address,
            notes: values.notes,
          );

      if (!mounted) return;
      invalidateSupplierData(ref, supplierId: widget.supplierId);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Supplier ${values.name} updated.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      // The form keeps everything the user typed, including the status.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(supplierSaveErrorMessage(error)),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierAsync = ref.watch(supplierProvider(widget.supplierId));

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          backgroundColor: AppColors.background,
          elevation: 0,
          leading: IconButton(
            tooltip: 'Back',
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          title: Text(
            'Edit Supplier',
            style: AppTypography.textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: supplierAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => _LoadError(
              onRetry: () =>
                  ref.invalidate(supplierProvider(widget.supplierId)),
            ),
            data: (supplier) {
              final controllers = _controllersFor(supplier);

              return SingleChildScrollView(
                padding: const EdgeInsets.all(AppSpacing.md),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 640),
                    child: SupplierForm(
                      formKey: _formKey,
                      controllers: controllers,
                      isSaving: _isSaving,
                      submitLabel: 'Save changes',
                      submitIcon: Icons.save_outlined,
                      onSubmit: () => _save(controllers),
                      isActive: _isActive,
                      onActiveChanged: (value) {
                        setState(() => _isActive = value);
                      },
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _LoadError extends StatelessWidget {
  const _LoadError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 44,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load this supplier',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Check your connection and try again.',
              textAlign: TextAlign.center,
              style: AppTypography.textTheme.bodySmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
