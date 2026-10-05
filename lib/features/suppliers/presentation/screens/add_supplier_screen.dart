import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../providers/supplier_providers.dart';
import '../utils/supplier_error_message.dart';
import '../widgets/supplier_form.dart';

class AddSupplierScreen extends ConsumerStatefulWidget {
  const AddSupplierScreen({super.key});

  @override
  ConsumerState<AddSupplierScreen> createState() => _AddSupplierScreenState();
}

class _AddSupplierScreenState extends ConsumerState<AddSupplierScreen> {
  final _formKey = GlobalKey<FormState>();
  final _controllers = SupplierFormControllers();

  bool _isSaving = false;

  @override
  void dispose() {
    _controllers.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    final values = _controllers.values;
    setState(() => _isSaving = true);

    try {
      await ref
          .read(createSupplierProvider)
          .call(
            name: values.name,
            phone: values.phone,
            email: values.email,
            address: values.address,
            notes: values.notes,
          );

      if (!mounted) return;
      invalidateSupplierData(ref);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Supplier ${values.name} added.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      // The form keeps everything the user typed.
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
            'Add Supplier',
            style: AppTypography.textTheme.titleLarge!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 640),
                child: SupplierForm(
                  formKey: _formKey,
                  controllers: _controllers,
                  isSaving: _isSaving,
                  submitLabel: 'Save supplier',
                  submitIcon: Icons.save_outlined,
                  onSubmit: _save,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
