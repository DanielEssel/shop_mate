
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_shadows.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/customer.dart';
import '../providers/customers_provider.dart';

class CustomerDetailsScreen extends ConsumerStatefulWidget {
  const CustomerDetailsScreen({
    super.key,
    required this.customerId,
  });

  final String customerId;

  @override
  ConsumerState<CustomerDetailsScreen> createState() =>
      _CustomerDetailsScreenState();
}

class _CustomerDetailsScreenState
    extends ConsumerState<CustomerDetailsScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _notesController = TextEditingController();

  bool _isEditing = false;
  bool _isSaving = false;
  bool _fieldsInitialized = false;

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

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer updated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to update customer: ${_friendlyError(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
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
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate customer?'),
          content: Text(
            'This will deactivate ${customer.name}. '
            'They will no longer appear in the active customer list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await ref
          .read(customersProvider.notifier)
          .deleteCustomer(customer.id);

      ref.invalidate(customerProvider(widget.customerId));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deactivated successfully.'),
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to deactivate customer: ${_friendlyError(error)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
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

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

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
    final customerAsync = ref.watch(
      customerProvider(widget.customerId),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _isSaving
              ? null
              : () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
        title: Text(
          'Customer Details',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          customerAsync.whenOrNull(
            data: (customer) {
              if (_isEditing) return null;

              return IconButton(
                tooltip: 'Edit customer',
                onPressed: _startEditing,
                icon: const Icon(Icons.edit_outlined),
              );
            },
          ) ?? const SizedBox.shrink(),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      body: customerAsync.when(
        loading: () => const _DetailsLoading(),
        error: (error, stackTrace) {
          return _DetailsError(
            message: error.toString(),
            onRetry: () {
              ref.invalidate(
                customerProvider(widget.customerId),
              );
            },
          );
        },
        data: (customer) {
          _initializeFields(customer);

          return SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 900;

                return SingleChildScrollView(
                  padding: EdgeInsets.all(
                    isDesktop
                        ? AppSpacing.xl
                        : AppSpacing.md,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(
                        maxWidth: 1000,
                      ),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          _CustomerHeader(
                            customer: customer,
                            isEditing: _isEditing,
                            isDesktop: isDesktop,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          _DetailsCard(
                            formKey: _formKey,
                            customer: customer,
                            isEditing: _isEditing,
                            isSaving: _isSaving,
                            isDesktop: isDesktop,
                            nameController: _nameController,
                            phoneController: _phoneController,
                            emailController: _emailController,
                            addressController: _addressController,
                            notesController: _notesController,
                            emailValidator: _emailValidator,
                            onSave: () => _saveCustomer(customer),
                            onCancel: () =>
                                _cancelEditing(customer),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (!_isEditing)
                            _CustomerActions(
                              customer: customer,
                              onDeactivate: () =>
                                  _deactivateCustomer(customer),
                            ),
                          const SizedBox(height: 60),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _CustomerHeader extends StatelessWidget {
  const _CustomerHeader({
    required this.customer,
    required this.isEditing,
    required this.isDesktop,
  });

  final Customer customer;
  final bool isEditing;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final initial = customer.name.trim().isEmpty
        ? '?'
        : customer.name.trim().substring(0, 1).toUpperCase();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isDesktop ? AppSpacing.xl : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Row(
        children: [
          Container(
            width: isDesktop ? 78 : 64,
            height: isDesktop ? 78 : 64,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(
                alpha: 0.10,
              ),
              borderRadius: BorderRadius.circular(
                AppRadius.lg,
              ),
            ),
            child: Text(
              initial,
              style: AppTypography.textTheme.displayMedium!
                  .copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography
                      .textTheme
                      .headlineMedium!
                      .copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                ),
                const SizedBox(height: AppSpacing.xs),
                if (customer.phone != null &&
                    customer.phone!.trim().isNotEmpty)
                  Text(
                    customer.phone!,
                    style: AppTypography
                        .textTheme
                        .bodyMedium!
                        .copyWith(
                          color: AppColors.textSecondary,
                        ),
                  )
                else
                  Text(
                    'No phone number',
                    style: AppTypography
                        .textTheme
                        .bodyMedium!
                        .copyWith(
                          color: AppColors.textSecondary,
                        ),
                  ),
                const SizedBox(height: AppSpacing.sm),
                _StatusBadge(
                  isActive: customer.isActive,
                ),
              ],
            ),
          ),
          if (isDesktop && !isEditing)
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.person_outline_rounded,
              ),
              label: const Text('Customer'),
            ),
        ],
      ),
    );
  }
}

class _DetailsCard extends StatelessWidget {
  const _DetailsCard({
    required this.formKey,
    required this.customer,
    required this.isEditing,
    required this.isSaving,
    required this.isDesktop,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.notesController,
    required this.emailValidator,
    required this.onSave,
    required this.onCancel,
  });

  final GlobalKey<FormState> formKey;
  final Customer customer;
  final bool isEditing;
  final bool isSaving;
  final bool isDesktop;

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController notesController;

  final String? Function(String?) emailValidator;
  final VoidCallback onSave;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(
        isDesktop ? AppSpacing.xl : AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border,
        ),
        boxShadow: AppShadows.card,
      ),
      child: Form(
        key: formKey,
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEditing
                        ? 'Edit Customer'
                        : 'Customer Information',
                    style: AppTypography
                        .textTheme
                        .titleLarge!
                        .copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                  ),
                ),
                if (!isEditing)
                  const Icon(
                    Icons.info_outline_rounded,
                    color: AppColors.textSecondary,
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            if (isEditing)
              _EditableFields(
                isDesktop: isDesktop,
                nameController: nameController,
                phoneController: phoneController,
                emailController: emailController,
                addressController: addressController,
                notesController: notesController,
                emailValidator: emailValidator,
              )
            else
              _ReadOnlyFields(
                customer: customer,
                isDesktop: isDesktop,
              ),
            if (isEditing) ...[
              const SizedBox(height: AppSpacing.xl),
              const Divider(
                color: AppColors.border,
                height: 1,
              ),
              const SizedBox(height: AppSpacing.lg),
              Row(
                mainAxisAlignment:
                    MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed:
                        isSaving ? null : onCancel,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  FilledButton.icon(
                    onPressed:
                        isSaving ? null : onSave,
                    icon: isSaving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Icon(
                            Icons.save_outlined,
                          ),
                    label: Text(
                      isSaving
                          ? 'Saving...'
                          : 'Save Changes',
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EditableFields extends StatelessWidget {
  const _EditableFields({
    required this.isDesktop,
    required this.nameController,
    required this.phoneController,
    required this.emailController,
    required this.addressController,
    required this.notesController,
    required this.emailValidator,
  });

  final bool isDesktop;

  final TextEditingController nameController;
  final TextEditingController phoneController;
  final TextEditingController emailController;
  final TextEditingController addressController;
  final TextEditingController notesController;

  final String? Function(String?) emailValidator;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _DetailsField(
          controller: nameController,
          label: 'Customer Name',
          icon: Icons.person_outline_rounded,
          requiredField: true,
          textCapitalization:
              TextCapitalization.words,
          validator: (value) {
            if (value == null ||
                value.trim().isEmpty) {
              return 'Customer name is required';
            }

            if (value.trim().length < 2) {
              return 'Enter a valid customer name';
            }

            return null;
          },
        ),
        const SizedBox(height: AppSpacing.md),
        if (isDesktop)
          Row(
            children: [
              Expanded(
                child: _DetailsField(
                  controller: phoneController,
                  label: 'Phone Number',
                  icon: Icons.phone_outlined,
                  keyboardType:
                      TextInputType.phone,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: _DetailsField(
                  controller: emailController,
                  label: 'Email Address',
                  icon: Icons.email_outlined,
                  keyboardType:
                      TextInputType.emailAddress,
                  validator: emailValidator,
                ),
              ),
            ],
          )
        else ...[
          _DetailsField(
            controller: phoneController,
            label: 'Phone Number',
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.md),
          _DetailsField(
            controller: emailController,
            label: 'Email Address',
            icon: Icons.email_outlined,
            keyboardType:
                TextInputType.emailAddress,
            validator: emailValidator,
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        _DetailsField(
          controller: addressController,
          label: 'Address',
          icon: Icons.location_on_outlined,
          maxLines: 2,
          textCapitalization:
              TextCapitalization.sentences,
        ),
        const SizedBox(height: AppSpacing.md),
        _DetailsField(
          controller: notesController,
          label: 'Notes',
          icon: Icons.notes_outlined,
          maxLines: 4,
          textCapitalization:
              TextCapitalization.sentences,
        ),
      ],
    );
  }
}

class _ReadOnlyFields extends StatelessWidget {
  const _ReadOnlyFields({
    required this.customer,
    required this.isDesktop,
  });

  final Customer customer;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _ReadOnlyFieldData(
        label: 'Customer Name',
        value: customer.name,
        icon: Icons.person_outline_rounded,
      ),
      _ReadOnlyFieldData(
        label: 'Phone Number',
        value: customer.phone,
        icon: Icons.phone_outlined,
      ),
      _ReadOnlyFieldData(
        label: 'Email Address',
        value: customer.email,
        icon: Icons.email_outlined,
      ),
      _ReadOnlyFieldData(
        label: 'Address',
        value: customer.address,
        icon: Icons.location_on_outlined,
      ),
      _ReadOnlyFieldData(
        label: 'Notes',
        value: customer.notes,
        icon: Icons.notes_outlined,
      ),
    ];

    // MOBILE FIRST
    if (!isDesktop) {
      return Column(
        children: [
          for (int index = 0; index < fields.length; index++) ...[
            _ReadOnlyField(
              data: fields[index],
            ),
            if (index != fields.length - 1)
              const SizedBox(height: AppSpacing.sm),
          ],
        ],
      );
    }

    // TABLET / DESKTOP
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: fields.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 4.5,
      ),
      itemBuilder: (context, index) {
        return _ReadOnlyField(
          data: fields[index],
        );
      },
    );
  }
}

class _ReadOnlyFieldData {
  const _ReadOnlyFieldData({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String? value;
  final IconData icon;
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.data,
  });

  final _ReadOnlyFieldData data;

  @override
  Widget build(BuildContext context) {
    final value = data.value?.trim();

    return Container(
      padding: const EdgeInsets.all(
        AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius:
            BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Icon(
            data.icon,
            size: 20,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                Text(
                  data.label,
                  style: AppTypography
                      .textTheme
                      .labelSmall!
                      .copyWith(
                        color:
                            AppColors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 3),
                Text(
                  value == null || value.isEmpty
                      ? 'Not provided'
                      : value,
                  maxLines: 2,
                  overflow:
                      TextOverflow.ellipsis,
                  style: AppTypography
                      .textTheme
                      .bodyMedium!
                      .copyWith(
                        color:
                            value == null ||
                                    value.isEmpty
                                ? AppColors
                                    .textSecondary
                                : AppColors
                                    .textPrimary,
                        fontWeight:
                            value == null ||
                                    value.isEmpty
                                ? FontWeight.w400
                                : FontWeight.w600,
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

class _DetailsField extends StatelessWidget {
  const _DetailsField({
    required this.controller,
    required this.label,
    required this.icon,
    this.requiredField = false,
    this.keyboardType,
    this.textCapitalization =
        TextCapitalization.none,
    this.maxLines = 1,
    this.validator,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool requiredField;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final int maxLines;
  final String? Function(String?)? validator;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      maxLines: maxLines,
      validator: validator,
      style: AppTypography
          .textTheme
          .bodyMedium!
          .copyWith(
            color: AppColors.textPrimary,
          ),
      decoration: InputDecoration(
        labelText: requiredField
            ? '$label *'
            : label,
        prefixIcon: Icon(
          icon,
          color: AppColors.textSecondary,
        ),
        filled: true,
        fillColor: AppColors.background,
        contentPadding:
            const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            AppRadius.md,
          ),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            AppRadius.md,
          ),
          borderSide: const BorderSide(
            color: AppColors.border,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            AppRadius.md,
          ),
          borderSide: const BorderSide(
            color: AppColors.primary,
            width: 1.5,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            AppRadius.md,
          ),
          borderSide: const BorderSide(
            color: AppColors.error,
          ),
        ),
        focusedErrorBorder:
            OutlineInputBorder(
          borderRadius:
              BorderRadius.circular(
            AppRadius.md,
          ),
          borderSide: const BorderSide(
            color: AppColors.error,
            width: 1.5,
          ),
        ),
      ),
    );
  }
}

class _CustomerActions extends StatelessWidget {
  const _CustomerActions({
    required this.customer,
    required this.onDeactivate,
  });

  final Customer customer;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(
          AppRadius.lg,
        ),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Text(
            'Customer Actions',
            style: AppTypography
                .textTheme
                .titleMedium!
                .copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Manage the status of this customer.',
            style: AppTypography
                .textTheme
                .bodySmall!
                .copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (customer.isActive)
            OutlinedButton.icon(
              onPressed: onDeactivate,
              icon: const Icon(
                Icons.person_off_outlined,
              ),
              label: const Text(
                'Deactivate Customer',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    AppColors.error,
                side: const BorderSide(
                  color: AppColors.error,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.isActive,
  });

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.success.withValues(
                alpha: 0.10,
              )
            : AppColors.error.withValues(
                alpha: 0.10,
              ),
        borderRadius:
            BorderRadius.circular(
          AppRadius.pill,
        ),
      ),
      child: Text(
        isActive ? 'Active' : 'Inactive',
        style: AppTypography
            .textTheme
            .labelSmall!
            .copyWith(
              color: isActive
                  ? AppColors.success
                  : AppColors.error,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}

class _DetailsLoading extends StatelessWidget {
  const _DetailsLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _DetailsError extends StatelessWidget {
  const _DetailsError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(
              height: AppSpacing.md,
            ),
            Text(
              'Unable to load customer',
              style: AppTypography
                  .textTheme
                  .titleMedium!
                  .copyWith(
                    fontWeight:
                        FontWeight.w800,
                    color:
                        AppColors.textPrimary,
                  ),
            ),
            const SizedBox(
              height: AppSpacing.xs,
            ),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow:
                  TextOverflow.ellipsis,
              style: AppTypography
                  .textTheme
                  .bodySmall!
                  .copyWith(
                    color:
                        AppColors.textSecondary,
                  ),
            ),
            const SizedBox(
              height: AppSpacing.md,
            ),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label:
                  const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
