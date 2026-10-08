import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../domain/entities/customer.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../providers/customers_provider.dart';
import '../widgets/customer_credit_section.dart';

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  const CustomerDetailsScreen({super.key, required this.customerId});

  final String customerId;

  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState extends ConsumerState<CustomerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _fieldsInitialized = false;

  /// Forms read best at a moderate width, even on large windows.
  static const double _formWidth = 880;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _notesController.dispose();

    super.dispose();
  }

  void _initializeFields(Customer customer) {
    if (_fieldsInitialized) return;

    _nameController.text = customer.name;
    _phoneController.text = customer.phone ?? '';
    _emailController.text = customer.email ?? '';
    _addressController.text = customer.address ?? '';
    _notesController.text = customer.notes ?? '';

    _fieldsInitialized = true;
  }

  void _startEditing() {
    setState(() {
      _isEditing = true;
    });
  }

  void _cancelEditing(Customer customer) {
    _nameController.text = customer.name;
    _phoneController.text = customer.phone ?? '';
    _emailController.text = customer.email ?? '';
    _addressController.text = customer.address ?? '';
    _notesController.text = customer.notes ?? '';

    setState(() {
      _isEditing = false;
    });
  }

  Future<void> _saveCustomer(Customer customer) async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final updatedCustomer = Customer(
      id: customer.id,
      name: _nameController.text.trim(),
      phone: _nullableValue(_phoneController.text),
      email: _nullableValue(_emailController.text),
      address: _nullableValue(_addressController.text),
      notes: _nullableValue(_notesController.text),
      isActive: customer.isActive,
      createdAt: customer.createdAt,
      updatedAt: customer.updatedAt,
    );

    try {
      await ref
          .read(customersProvider.notifier)
          .updateCustomer(updatedCustomer);

      ref.invalidate(customerProvider(widget.customerId));

      if (!mounted) return;

      setState(() {
        _isEditing = false;
      });

      showFloatingMessage(context, 'Customer updated successfully.');
    } catch (error) {
      if (!mounted) return;

      // The form (and its Save bar) stays open, so float above the bar.
      showFloatingMessage(
        context,
        'Unable to update customer: ${_friendlyError(error)}',
        clearance: FormActionBar.messageClearance,
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<void> _deactivateCustomer(Customer customer) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Deactivate customer?',
      message:
          'This will deactivate ${customer.name}. '
          'They will no longer appear in the active customer list.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );

    if (!confirmed) return;

    try {
      await ref.read(customersProvider.notifier).deleteCustomer(customer.id);

      ref.invalidate(customerProvider(widget.customerId));

      if (!mounted) return;

      showFloatingMessage(context, 'Customer deactivated successfully.');

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      showFloatingMessage(
        context,
        'Unable to deactivate customer: ${_friendlyError(error)}',
      );
    }
  }

  String? _nullableValue(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  String? _emailValidator(String? value) {
    final email = value?.trim() ?? '';

    if (email.isEmpty) {
      return null;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address';
    }

    return null;
  }

  String _friendlyError(Object error) {
    final message = error.toString();

    if (message.contains('permission')) {
      return 'You do not have permission to perform this action.';
    }

    return message;
  }

  @override
  Widget build(BuildContext context) {
    final customerAsync = ref.watch(customerProvider(widget.customerId));
    // Deactivating a customer is deleting it: owner-only.
    final canDeactivate = ref.watch(
      shopAccessProvider.select(selectIsShopOwner),
    );
    final customer = customerAsync.value;
    if (customer != null) _initializeFields(customer);

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
                      maxWidth: _isEditing ? _formWidth : ContentWidth.standard,
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
                        AppSpacing.xxxl,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          PageHeader(
                            title: _isEditing
                                ? 'Edit Customer'
                                : 'Customer Details',
                            leading: IconButton(
                              tooltip: 'Back',
                              onPressed: _isSaving
                                  ? null
                                  : () => Navigator.of(context).pop(),
                              icon: const Icon(Icons.arrow_back_rounded),
                            ),
                            actions: [
                              if (customer != null && !_isEditing)
                                SecondaryButton(
                                  label: 'Edit Customer',
                                  icon: Icons.edit_outlined,
                                  onPressed: _startEditing,
                                ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xxl),
                          customerAsync.when(
                            loading: () => const _DetailsSkeleton(),
                            error: (error, stackTrace) => SurfaceCard(
                              child: ErrorState(
                                compact: true,
                                title: 'Unable to load customer',
                                message: 'Check your connection and try again.',
                                retryLabel: 'Retry',
                                onRetry: () => ref.invalidate(
                                  customerProvider(widget.customerId),
                                ),
                              ),
                            ),
                            data: (customer) => _isEditing
                                ? _EditForm(
                                    formKey: _formKey,
                                    isSaving: _isSaving,
                                    nameController: _nameController,
                                    phoneController: _phoneController,
                                    emailController: _emailController,
                                    addressController: _addressController,
                                    notesController: _notesController,
                                    emailValidator: _emailValidator,
                                  )
                                : _CustomerOverview(
                                    customer: customer,
                                    wide: width >= Breakpoints.expanded,
                                    canDeactivate: canDeactivate,
                                    onDeactivate: () =>
                                        _deactivateCustomer(customer),
                                  ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              if (_isEditing && customer != null)
                FormActionBar(
                  primaryLabel: 'Save Changes',
                  busyLabel: 'Saving...',
                  primaryIcon: Icons.save_outlined,
                  isBusy: _isSaving,
                  onPrimary: () => _saveCustomer(customer),
                  onSecondary: () => _cancelEditing(customer),
                  maxContentWidth: _formWidth,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// VIEW
// =============================================================

class _CustomerOverview extends StatelessWidget {
  const _CustomerOverview({
    required this.customer,
    required this.wide,
    required this.canDeactivate,
    required this.onDeactivate,
  });

  final Customer customer;
  final bool wide;
  final bool canDeactivate;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final phone = customer.phone?.trim();

    final identity = IdentityPanel(
      visual: InitialAvatar(name: customer.name, size: 64),
      title: customer.name,
      subtitle: phone == null || phone.isEmpty ? 'No phone number' : phone,
      badges: [
        customer.isActive
            ? const StatusBadge(label: 'Active', tone: StatusTone.success)
            : const StatusBadge(label: 'Inactive', tone: StatusTone.neutral),
      ],
    );

    final information = InfoSection(
      title: 'Customer Information',
      items: [
        InfoItem(label: 'Phone Number', value: customer.phone),
        InfoItem(label: 'Email Address', value: customer.email),
        InfoItem(label: 'Address', value: customer.address, wide: true),
        InfoItem(label: 'Notes', value: customer.notes, wide: true),
      ],
    );

    final actions = canDeactivate && customer.isActive
        ? _CustomerActions(onDeactivate: onDeactivate)
        : null;

    final credit = CustomerCreditSection(
      customerId: customer.id,
      customerName: customer.name,
    );

    const gap = SizedBox(height: AppSpacing.xxl);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        identity,
        gap,
        if (wide && actions != null)
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: information),
              const SizedBox(width: AppSpacing.xxl),
              Expanded(flex: 2, child: actions),
            ],
          )
        else
          information,
        gap,
        credit,
        if (!wide && actions != null) ...[gap, actions],
      ],
    );
  }
}

/// Owner-only: status changes, kept apart from everyday actions.
class _CustomerActions extends StatelessWidget {
  const _CustomerActions({required this.onDeactivate});

  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Customer Actions',
          subtitle: 'Manage the status of this customer.',
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Deactivated customers are kept for records but leave the '
                'active list.',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              OutlinedButton.icon(
                onPressed: onDeactivate,
                icon: const Icon(Icons.person_off_outlined, size: 18),
                label: const Text('Deactivate Customer'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.danger,
                  side: BorderSide(
                    color: AppColors.danger.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// =============================================================
// EDIT
// =============================================================

class _EditForm extends StatelessWidget {
  const _EditForm({
    required this.formKey,
    required this.isSaving,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.notesController,
    required this.emailValidator,
  });

  final GlobalKey<FormState> formKey;
  final bool isSaving;

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController notesController;

  final String? Function(String?) emailValidator;

  @override
  Widget build(BuildContext context) {
    const fieldGap = SizedBox(height: AppSpacing.lg);

    return Form(
      key: formKey,
      child: FormSection(
        title: 'Customer Information',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _DetailsField(
              controller: nameController,
              label: 'Customer Name',
              icon: Icons.person_outline_rounded,
              enabled: !isSaving,
              requiredField: true,
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Customer name is required';
                }

                if (value.trim().length < 2) {
                  return 'Enter a valid customer name';
                }

                return null;
              },
            ),
            fieldGap,
            FieldRow(
              children: [
                _DetailsField(
                  controller: phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  enabled: !isSaving,
                  keyboardType: TextInputType.phone,
                ),
                _DetailsField(
                  controller: emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  enabled: !isSaving,
                  keyboardType: TextInputType.emailAddress,
                  validator: emailValidator,
                ),
              ],
            ),
            fieldGap,
            _DetailsField(
              controller: addressController,
              label: 'Address',
              icon: Icons.location_on_outlined,
              enabled: !isSaving,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
            ),
            fieldGap,
            _DetailsField(
              controller: notesController,
              label: 'Notes',
              icon: Icons.notes_outlined,
              enabled: !isSaving,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailsField extends StatelessWidget {
  const _DetailsField({
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
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      enabled: enabled,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      decoration: InputDecoration(
        labelText: requiredField ? '$label *' : label,
        prefixIcon: Icon(icon),
        alignLabelWithHint: maxLines > 1,
      ),
    );
  }
}

class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SkeletonBox(height: 112, radius: AppRadius.lg),
        SizedBox(height: AppSpacing.xxl),
        SkeletonBox(height: 180, radius: AppRadius.lg),
      ],
    );
  }
}
