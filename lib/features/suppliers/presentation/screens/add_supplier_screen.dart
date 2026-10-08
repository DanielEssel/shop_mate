import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
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

  /// Forms read best at a moderate width, even on large windows.
  static const double _formWidth = 880;

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

      showFloatingMessage(context, 'Supplier ${values.name} added.');
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);

      // The form keeps everything the user typed.
      showFloatingMessage(
        context,
        supplierSaveErrorMessage(error),
        clearance: FormActionBar.messageClearance,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
                            title: 'Add Supplier',
                            subtitle: 'Save a supplier you buy stock from',
                            leading: IconButton(
                              tooltip: 'Back',
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          SupplierForm(
                            formKey: _formKey,
                            controllers: _controllers,
                            isSaving: _isSaving,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              FormActionBar(
                primaryLabel: 'Save supplier',
                busyLabel: 'Saving...',
                primaryIcon: Icons.save_outlined,
                isBusy: _isSaving,
                onPrimary: _save,
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
