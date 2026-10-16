import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/discount_percentage.dart';
import '../../domain/entities/discount_pricing.dart';
import '../../domain/entities/discount_scope.dart';
import '../../domain/entities/discount_settings.dart';
import '../../domain/entities/discount_settings_exception.dart';
import '../providers/discount_settings_providers.dart';
import '../widgets/discount_below_cost_warnings.dart';
import '../widgets/discount_dates.dart';
import '../widgets/discount_overview_card.dart';
import '../widgets/discount_product_picker.dart';

/// The form's values, compared with what was loaded to detect changes.
@immutable
class _FormValues {
  const _FormValues({
    required this.isEnabled,
    required this.scope,
    required this.percentageText,
    required this.endDay,
    required this.selectedIds,
  });

  final bool isEnabled;
  final DiscountScope scope;
  final String percentageText;
  final DateTime? endDay;
  final Set<String> selectedIds;

  /// Equal when saving would change nothing.
  bool sameAs(_FormValues other) {
    final percentage = DiscountPercentage.tryParse(percentageText);
    final otherPercentage = DiscountPercentage.tryParse(other.percentageText);
    return isEnabled == other.isEnabled &&
        scope == other.scope &&
        (percentage != null && otherPercentage != null
            ? percentage == otherPercentage
            : percentageText.trim() == other.percentageText.trim()) &&
        endDay == other.endDay &&
        selectedIds.length == other.selectedIds.length &&
        selectedIds.containsAll(other.selectedIds);
  }
}

/// Owner-only discount configuration: a percentage for all products or for
/// selected products, with an optional end date. The server applies it to
/// every sale; this screen only edits the configuration.
///
/// Only owners reach it (the router guards /settings), and it shows nothing
/// to anyone else even if mounted. While the release gate is closed it
/// shows the saved configuration and previews changes, but never writes.
class DiscountSettingsScreen extends ConsumerStatefulWidget {
  const DiscountSettingsScreen({super.key});

  @override
  ConsumerState<DiscountSettingsScreen> createState() =>
      _DiscountSettingsScreenState();
}

class _DiscountSettingsScreenState
    extends ConsumerState<DiscountSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _percentageController = TextEditingController();

  /// What was loaded (or last saved); null until the settings load.
  _FormValues? _baseline;

  bool _isEnabled = false;
  DiscountScope _scope = DiscountScope.allProducts;
  DateTime? _endDay;
  Set<String> _selectedIds = <String>{};
  bool _isSaving = false;

  @override
  void dispose() {
    _percentageController.dispose();
    super.dispose();
  }

  _FormValues get _current => _FormValues(
    isEnabled: _isEnabled,
    scope: _scope,
    percentageText: _percentageController.text,
    endDay: _endDay,
    selectedIds: _selectedIds,
  );

  bool get _isDirty {
    final baseline = _baseline;
    return baseline != null && !_current.sameAs(baseline);
  }

  /// Fills the form once from the loaded settings, so a background refresh
  /// never overwrites what the owner is editing.
  void _initializeFrom(DiscountSettings? settings) {
    if (_baseline != null) return;
    final endsAt = settings?.endsAt;
    _isEnabled = settings?.isEnabled ?? false;
    _scope = settings?.scope ?? DiscountScope.allProducts;
    _endDay = endsAt == null ? null : discountEndDayOf(endsAt);
    _selectedIds = {...?settings?.selectedProductIds};
    _percentageController.text = settings?.percentage.inputText ?? '';
    _baseline = _current;
  }

  void _resetTo(_FormValues values) {
    setState(() {
      _isEnabled = values.isEnabled;
      _scope = values.scope;
      _endDay = values.endDay;
      _selectedIds = {...values.selectedIds};
      _percentageController.text = values.percentageText;
    });
    _formKey.currentState?.validate();
  }

  Future<void> _pickEndDay() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final initial = _endDay != null && !_endDay!.isBefore(today)
        ? _endDay!
        : today;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
      helpText: 'Discount ends after',
    );
    if (picked != null && mounted) {
      setState(() => _endDay = DateUtils.dateOnly(picked));
    }
  }

  Future<void> _save({
    required DiscountSettings? settings,
    required List<Product> products,
  }) async {
    if (_isSaving) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final percentage = DiscountPercentage.tryParse(_percentageController.text);
    if (percentage == null) return;
    final endDay = _endDay;
    final draft = DiscountSettingsDraft(
      isEnabled: _isEnabled,
      scope: _scope,
      percentage: percentage,
      endsAt: endDay == null ? null : discountEndsAtForDay(endDay),
      selectedProductIds: {..._selectedIds},
    );
    final saved = _current;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(saveDiscountSettingsProvider)
          .call(
            draft,
            current: settings,
            products: products,
            now: DateTime.now(),
          );
      if (!mounted) return;
      _baseline = saved;
      ref.invalidate(discountSettingsProvider);
      _showMessage('Discount settings saved.');
    } on DiscountSettingsException catch (error) {
      // The form keeps every change; nothing claims to be saved.
      _showMessage(error.message, isError: true);
    } catch (_) {
      _showMessage(DiscountSettingsErrorKind.saveFailed.message, isError: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    showFloatingMessage(
      context,
      message,
      clearance: FormActionBar.messageClearance,
      backgroundColor: isError ? AppColors.danger : null,
    );
  }

  Future<void> _confirmLeave() async {
    final discard = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Your discount changes have not been saved.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      destructive: true,
    );
    if (discard && mounted) {
      final baseline = _baseline;
      if (baseline != null) _resetTo(baseline);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));
    final writesEnabled = ref.watch(discountWritesEnabledProvider);

    if (!isOwner) {
      return const _Frame(
        child: SurfaceCard(
          child: EmptyState(
            compact: true,
            icon: Icons.lock_outline_rounded,
            title: 'Not available',
            message: 'Only the shop owner can manage discounts.',
          ),
        ),
      );
    }

    final settingsAsync = ref.watch(discountSettingsProvider);
    final productsAsync = ref.watch(productsProvider);

    final Widget body = settingsAsync.when(
      loading: () => const SkeletonBox(height: 320, radius: AppRadius.lg),
      error: (error, _) => SurfaceCard(
        child: ErrorState(
          compact: true,
          title: 'Unable to load discount settings',
          message: error is DiscountSettingsException
              ? error.message
              : DiscountSettingsErrorKind.loadFailed.message,
          retryLabel: 'Retry',
          onRetry: () => ref.invalidate(discountSettingsProvider),
        ),
      ),
      data: (settings) {
        _initializeFrom(settings);
        return _buildForm(settings, productsAsync);
      },
    );

    final settings = settingsAsync.value;
    final products = productsAsync.value;
    final canSave =
        settingsAsync.hasValue && products != null && _isDirty && !_isSaving;

    return PopScope(
      canPop: !_isSaving && !_isDirty,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isSaving) _confirmLeave();
      },
      child: _Frame(
        leadingEnabled: !_isSaving,
        footer: settingsAsync.hasValue
            ? FormActionBar(
                primaryLabel: 'Save discount',
                busyLabel: 'Saving...',
                primaryIcon: Icons.save_outlined,
                isBusy: _isSaving,
                onPrimary: canSave
                    ? () => _save(settings: settings, products: products)
                    : null,
                secondaryLabel: 'Discard changes',
                onSecondary: _isDirty && !_isSaving
                    ? () => _resetTo(_baseline!)
                    : null,
                maxContentWidth: ContentWidth.form,
              )
            : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!writesEnabled) ...[
              const _GateNotice(),
              const SizedBox(height: AppSpacing.lg),
            ],
            body,
          ],
        ),
      ),
    );
  }

  Widget _buildForm(
    DiscountSettings? settings,
    AsyncValue<List<Product>> productsAsync,
  ) {
    final percentage = DiscountPercentage.tryParse(_percentageController.text);
    final products = productsAsync.value;
    final belowCost = percentage == null || products == null
        ? const <BelowCostProduct>[]
        : DiscountPricing.belowCost(
            products: products,
            scope: _scope,
            selectedProductIds: _selectedIds,
            percentage: percentage,
          );
    final endDay = _endDay;

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DiscountOverviewCard(settings: settings, now: DateTime.now()),
          const SizedBox(height: AppSpacing.xxl),
          FormSection(
            title: 'Discount',
            subtitle: 'Applied by ShopMate to every sale, never at the till.',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SwitchListTile(
                  key: const ValueKey('discount-enabled'),
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Discount on'),
                  subtitle: Text(
                    _isEnabled
                        ? 'Sales get this discount once saved.'
                        : 'Sales use normal prices.',
                  ),
                  value: _isEnabled,
                  onChanged: _isSaving
                      ? null
                      : (value) => setState(() => _isEnabled = value),
                ),
                const SizedBox(height: AppSpacing.md),
                TextFormField(
                  key: const ValueKey('discount-percentage'),
                  controller: _percentageController,
                  enabled: !_isSaving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  decoration: const InputDecoration(
                    labelText: 'Percentage off',
                    hintText: 'e.g. 10 or 12.5',
                    suffixText: '%',
                    helperText: 'From 0.01 to 99.99, up to two decimals.',
                    border: OutlineInputBorder(),
                  ),
                  validator: DiscountPercentage.validate,
                  // Rebuilds the warnings, the overview of changes and Save.
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  'Applies to',
                  style: AppTypography.textTheme.labelLarge?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<DiscountScope>(
                  segments: const [
                    ButtonSegment(
                      value: DiscountScope.allProducts,
                      label: Text('All products'),
                      icon: Icon(Icons.inventory_2_outlined),
                    ),
                    ButtonSegment(
                      value: DiscountScope.selectedProducts,
                      label: Text('Selected products'),
                      icon: Icon(Icons.checklist_rounded),
                    ),
                  ],
                  selected: {_scope},
                  onSelectionChanged: _isSaving
                      ? null
                      : (selection) => setState(() => _scope = selection.first),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _scope == DiscountScope.allProducts
                      ? 'Every product gets the discount, except any it would '
                            'take below cost: those keep their normal price.'
                      : 'Only the products you select get the discount.',
                  style: AppTypography.textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FormSection(
            title: 'End date',
            subtitle: 'Optional. The discount stops at the end of this day.',
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    endDay == null
                        ? 'No end date'
                        : 'Ends at the end of '
                              '${formatDiscountDay(context, endDay)}',
                    key: const ValueKey('discount-end-date'),
                    style: AppTypography.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: _isSaving ? null : _pickEndDay,
                  icon: const Icon(Icons.event_outlined, size: 18),
                  label: Text(endDay == null ? 'Set end date' : 'Change'),
                ),
                if (endDay != null)
                  IconButton(
                    tooltip: 'Remove end date',
                    onPressed: _isSaving
                        ? null
                        : () => setState(() => _endDay = null),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
            ),
          ),
          if (_scope == DiscountScope.selectedProducts) ...[
            const SizedBox(height: AppSpacing.xl),
            FormSection(
              title: 'Selected products',
              subtitle: 'Your selection is kept if you switch scope.',
              child: productsAsync.when(
                loading: () => const SkeletonBox(
                  height: DiscountProductPicker.listHeight,
                  radius: AppRadius.lg,
                ),
                error: (_, _) => SurfaceCard(
                  child: ErrorState(
                    compact: true,
                    title: 'Unable to load products',
                    message: 'Check your connection and try again.',
                    retryLabel: 'Retry',
                    onRetry: () => ref.invalidate(productsProvider),
                  ),
                ),
                data: (items) => DiscountProductPicker(
                  products: items,
                  selectedIds: _selectedIds,
                  enabled: !_isSaving,
                  onChanged: (ids) => setState(() => _selectedIds = ids),
                ),
              ),
            ),
          ],
          if (belowCost.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.xl),
            DiscountBelowCostWarnings(products: belowCost, scope: _scope),
          ],
        ],
      ),
    );
  }
}

/// Page chrome shared by every state of the screen.
class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.footer, this.leadingEnabled = true});

  final Widget child;
  final Widget? footer;
  final bool leadingEnabled;

  @override
  Widget build(BuildContext context) {
    final footer = this.footer;

    return Scaffold(
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
                    maxWidth: ContentWidth.form,
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
                          title: 'Discounts',
                          subtitle:
                              'A percentage off all products or selected '
                              'products',
                          leading: IconButton(
                            tooltip: 'Back',
                            onPressed: leadingEnabled
                                ? () => Navigator.of(context).maybePop()
                                : null,
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        child,
                      ],
                    ),
                  );
                },
              ),
            ),
            ?footer,
          ],
        ),
      ),
    );
  }
}

/// Shown while this build cannot save discount settings.
class _GateNotice extends StatelessWidget {
  const _GateNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('discount-gate-notice'),
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.infoLight,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ExcludeSemantics(
            child: Icon(Icons.info_outline_rounded, color: AppColors.info),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              "Discount activation isn't available yet. You can review the "
              'saved discount and preview changes here, but saving will be '
              'switched on in a coming ShopMate update.',
              style: AppTypography.textTheme.bodyMedium?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
