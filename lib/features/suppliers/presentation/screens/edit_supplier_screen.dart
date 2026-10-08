import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
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

  /// Forms read best at a moderate width, even on large windows.
  static const double _formWidth = 880;

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

      showFloatingMessage(context, 'Supplier ${values.name} updated.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      // The form keeps everything the user typed, including the status.
      showFloatingMessage(
        context,
        supplierSaveErrorMessage(error),
        clearance: FormActionBar.messageClearance,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final supplierAsync = ref.watch(supplierProvider(widget.supplierId));
    final supplier = supplierAsync.value;
    final controllers = supplier == null ? null : _controllersFor(supplier);

    return PopScope(
      canPop: !_isSaving,
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    final horizontal = Breakpoints.pagePadding(
                      width,
                      maxWidth: _formWidth,
                    );

                    return SingleChildScrollView(
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        Breakpoints.of(width).isCompact
                            ? AppSpacing.md
                            : AppSpacing.xxl,
                        horizontal,
                        AppSpacing.xxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PageHeader(
                            title: 'Edit Supplier',
                            subtitle: supplier?.name,
                            leading: IconButton(
                              tooltip: 'Back',
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          supplierAsync.when(
                            loading: () => const SkeletonBox(
                              height: 320,
                              radius: AppRadius.lg,
                            ),
                            error: (_, _) => SurfaceCard(
                              child: ErrorState(
                                compact: true,
                                title: 'Unable to load this supplier',
                                message: 'Check your connection and try again.',
                                retryLabel: 'Retry',
                                onRetry: () => ref.invalidate(
                                  supplierProvider(widget.supplierId),
                                ),
                              ),
                            ),
                            data: (_) => SupplierForm(
                              formKey: _formKey,
                              controllers: controllers!,
                              isSaving: _isSaving,
                              isActive: _isActive,
                              onActiveChanged: (value) {
                                setState(() => _isActive = value);
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (controllers != null)
                FormActionBar(
                  primaryLabel: 'Save changes',
                  busyLabel: 'Saving...',
                  primaryIcon: Icons.save_outlined,
                  isBusy: _isSaving,
                  onPrimary: () => _save(controllers),
                  onSecondary: () => Navigator.of(context).pop(),
                  maxContentWidth: _formWidth,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
