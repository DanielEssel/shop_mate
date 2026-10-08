import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/date_format.dart';
import '../../../../core/utils/money_format.dart';
import '../../domain/entities/purchase_cart_item.dart';
import '../providers/purchases_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/widgets/product_visuals.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/providers/supplier_providers.dart';

/// Payment methods for a purchase, in display order.
const _paymentMethods = <(String, String)>[
  ('cash', 'Cash'),
  ('mobile_money', 'Mobile Money'),
  ('card', 'Card'),
  ('bank_transfer', 'Bank Transfer'),
  ('credit', 'Credit'),
];

class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  ConsumerState<NewPurchaseScreen> createState() => _NewPurchaseScreenState();
}

class _NewPurchaseScreenState extends ConsumerState<NewPurchaseScreen> {
  final _formKey = GlobalKey<FormState>();

  final _supplierNameController = TextEditingController();
  final _supplierPhoneController = TextEditingController();
  final _amountPaidController = TextEditingController();
  final _notesController = TextEditingController();

  String _paymentMethod = 'cash';
  DateTime _purchaseDate = DateTime.now();
  bool _isSaving = false;

  /// Saved supplier linked to this purchase, or null for manual entry. Held
  /// in local state so provider refreshes never change the selection.
  Supplier? _selectedSupplier;

  /// What the user had typed before choosing a saved supplier, restored when
  /// the selection is cleared.
  String _manualSupplierName = '';
  String _manualSupplierPhone = '';

  /// From this width the summary sits beside the form.
  static const double _splitFrom = 900;

  /// How far messages float above the bottom so they never cover the pinned
  /// Complete Purchase area. Set from the current layout on each build.
  double _messageLift = 0;

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _amountPaidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _amountPaid() {
    return double.tryParse(_amountPaidController.text.trim()) ?? 0;
  }

  double _balance(double total) {
    final balance = total - _amountPaid();

    if (balance < 0) {
      return 0;
    }

    return balance;
  }

  void _selectSupplier(Supplier supplier) {
    setState(() {
      if (_selectedSupplier == null) {
        _manualSupplierName = _supplierNameController.text;
        _manualSupplierPhone = _supplierPhoneController.text;
      }
      _selectedSupplier = supplier;
      _supplierNameController.text = supplier.name;
      _supplierPhoneController.text = supplier.phone ?? '';
    });
  }

  void _clearSupplier() {
    if (_selectedSupplier == null) return;

    setState(() {
      _selectedSupplier = null;
      _supplierNameController.text = _manualSupplierName;
      _supplierPhoneController.text = _manualSupplierPhone;
    });
  }

  Future<void> _selectDate() async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: _purchaseDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (selectedDate != null) {
      setState(() {
        _purchaseDate = selectedDate;
      });
    }
  }

  Future<void> _completePurchase() async {
    FocusScope.of(context).unfocus();

    final cart = ref.read(purchaseCartProvider);
    final cartNotifier = ref.read(purchaseCartProvider.notifier);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (cart.isEmpty) {
      _showMessage('Please add at least one product.', isError: true);
      return;
    }

    final total = cartNotifier.total;
    final amountPaid = _amountPaid();

    if (_paymentMethod != 'credit' && amountPaid > total) {
      _showMessage(
        'Amount paid cannot be greater than the purchase total.',
        isError: true,
      );
      return;
    }

    if (_paymentMethod == 'credit') {
      // Credit purchases may be recorded with zero payment.
      // If the user enters an amount, we still allow it.
      if (amountPaid > total) {
        _showMessage(
          'Amount paid cannot be greater than the purchase total.',
          isError: true,
        );
        return;
      }
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final items = cart.map((item) {
        return {
          'product_id': item.product.id,
          'product_name': item.product.name,
          'quantity': item.quantity,
          'unit_cost': item.unitCost,
        };
      }).toList();

      final selectedSupplier = _selectedSupplier;
      final supplierName = selectedSupplier != null
          ? selectedSupplier.name
          : _supplierNameController.text;
      final supplierPhone = selectedSupplier != null
          ? selectedSupplier.phone ?? ''
          : _supplierPhoneController.text;

      final purchase = await ref
          .read(createPurchaseProvider)
          .call(
            supplierId: selectedSupplier?.id,
            supplierName: supplierName.trim().isEmpty
                ? null
                : supplierName.trim(),
            supplierPhone: supplierPhone.trim().isEmpty
                ? null
                : supplierPhone.trim(),
            paymentMethod: _paymentMethod,
            amountPaid: amountPaid,
            purchaseDate: _purchaseDate,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
            items: items,
          );

      cartNotifier.clearCart();

      ref.invalidate(purchasesProvider);
      ref.invalidate(purchaseProvider(purchase.id));
      ref.invalidate(purchaseProductsProvider);

      if (!mounted) {
        return;
      }

      _showMessage('Purchase ${purchase.purchaseNumber} created successfully.');

      context.pushReplacement('/purchases/${purchase.id}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_selectedSupplier != null && _isUnavailableSupplierError(error)) {
        _clearSupplier();
        ref.invalidate(suppliersProvider);
        _showMessage(
          'This supplier is no longer active. Please select another supplier.',
          isError: true,
        );
        return;
      }

      _showMessage('Unable to create purchase: $error', isError: true);
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  /// The create_purchase RPC rejects a supplier that is missing, inactive or
  /// from another shop with this exact message.
  bool _isUnavailableSupplierError(Object error) {
    return error is PostgrestException &&
        error.message.contains(
          'not found, inactive, or unavailable for this shop',
        );
  }

  void _showMessage(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg + _messageLift,
          ),
        ),
      );
  }

  Widget _supplierPicker() {
    return _SavedSupplierPicker(
      selected: _selectedSupplier,
      enabled: !_isSaving,
      onSelected: _selectSupplier,
      onCleared: _clearSupplier,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(purchaseProductsProvider);

    final cart = ref.watch(purchaseCartProvider);
    final cartNotifier = ref.read(purchaseCartProvider.notifier);

    final total = cartNotifier.total;
    final amountPaid = _amountPaid();
    final balance = _balance(total);

    final summary = _SummaryValues(
      cart: cart,
      total: total,
      amountPaid: amountPaid,
      balance: balance,
      paymentMethod: _paymentMethod,
      isSaving: _isSaving,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSplit = constraints.maxWidth >= _splitFrom;
            _messageLift = isSplit ? 200 : 104;
            final horizontal = isSplit
                ? Breakpoints.gutter(constraints.maxWidth)
                : Breakpoints.pagePadding(
                    constraints.maxWidth,
                    maxWidth: ContentWidth.form,
                  );

            final header = Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isSplit ? AppSpacing.xxl : AppSpacing.md,
                horizontal,
                AppSpacing.xl,
              ),
              child: PageHeader(
                title: 'New Purchase',
                subtitle: 'Record stock bought from a supplier',
                leading: pageHeaderLeading(context),
              ),
            );

            return productsAsync.when(
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: PageSkeleton(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                    ),
                  ),
                ],
              ),
              error: (error, stackTrace) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: ErrorState(
                      title: 'Unable to load products',
                      message: 'Check your connection and try again.',
                      retryLabel: 'Retry',
                      onRetry: () => ref.invalidate(purchaseProductsProvider),
                    ),
                  ),
                ],
              ),
              data: (List<Product> products) {
                final form = _PurchaseForm(
                  products: products,
                  cart: cart,
                  supplierNameController: _supplierNameController,
                  supplierPhoneController: _supplierPhoneController,
                  supplierPicker: _supplierPicker(),
                  supplierLocked: _selectedSupplier != null,
                  notesController: _notesController,
                  purchaseDate: _purchaseDate,
                  onDateSelected: _selectDate,
                  onClearCart: _isSaving ? null : _showClearCartDialog,
                  payment: isSplit
                      ? null
                      : _PaymentFields(
                          summary: summary,
                          amountPaidController: _amountPaidController,
                          onPaymentChanged: _changePaymentMethod,
                          onAmountChanged: _amountChanged,
                        ),
                );

                return Form(
                  key: _formKey,
                  child: isSplit
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ListView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xxxl,
                                ),
                                children: [
                                  header,
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontal,
                                    ),
                                    child: form,
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(
                              width: (constraints.maxWidth * 0.36).clamp(
                                340.0,
                                420.0,
                              ),
                              child: _SummaryPanel(
                                summary: summary,
                                amountPaidController: _amountPaidController,
                                onPaymentChanged: _changePaymentMethod,
                                onAmountChanged: _amountChanged,
                                onComplete: _completePurchase,
                              ),
                            ),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Expanded(
                              child: ListView(
                                keyboardDismissBehavior:
                                    ScrollViewKeyboardDismissBehavior.onDrag,
                                padding: const EdgeInsets.only(
                                  bottom: AppSpacing.xxl,
                                ),
                                children: [
                                  header,
                                  Padding(
                                    padding: EdgeInsets.symmetric(
                                      horizontal: horizontal,
                                    ),
                                    child: form,
                                  ),
                                ],
                              ),
                            ),
                            CheckoutBar(
                              label: summary.barLabel,
                              amount: formatGhs(total),
                              caption: summary.balanceCaption,
                              captionColor: AppColors.warning,
                              action: _CompletePurchaseButton(
                                summary: summary,
                                onPressed: _completePurchase,
                                showIcon:
                                    MediaQuery.sizeOf(context).width >= 360,
                              ),
                            ),
                          ],
                        ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _changePaymentMethod(String value) {
    setState(() {
      _paymentMethod = value;
    });
  }

  void _amountChanged(String _) {
    setState(() {});
  }

  Future<void> _showClearCartDialog() async {
    final shouldClear = await showConfirmDialog(
      context,
      title: 'Clear purchase?',
      message: 'All products currently added to this purchase will be removed.',
      confirmLabel: 'Clear',
    );

    if (shouldClear) {
      ref.read(purchaseCartProvider.notifier).clearCart();
    }
  }
}

// =============================================================
// SUMMARY VALUES
// =============================================================

class _SummaryValues {
  const _SummaryValues({
    required this.cart,
    required this.total,
    required this.amountPaid,
    required this.balance,
    required this.paymentMethod,
    required this.isSaving,
  });

  final List<PurchaseCartItem> cart;
  final double total;
  final double amountPaid;
  final double balance;
  final String paymentMethod;
  final bool isSaving;

  int get totalQuantity =>
      cart.fold<int>(0, (sum, item) => sum + item.quantity);

  String get barLabel {
    if (cart.isEmpty) return 'Total';
    final products = cart.length;
    return 'Total · $products ${products == 1 ? 'product' : 'products'}';
  }

  String? get balanceCaption {
    if (cart.isEmpty || balance <= 0) return null;
    return 'Balance ${formatGhs(balance)}';
  }
}

// =============================================================
// PURCHASE FORM
// =============================================================

class _PurchaseForm extends StatelessWidget {
  const _PurchaseForm({
    required this.products,
    required this.cart,
    required this.supplierNameController,
    required this.supplierPhoneController,
    required this.supplierPicker,
    required this.supplierLocked,
    required this.notesController,
    required this.purchaseDate,
    required this.onDateSelected,
    required this.onClearCart,
    required this.payment,
  });

  final List<Product> products;
  final List<PurchaseCartItem> cart;

  final TextEditingController supplierNameController;
  final TextEditingController supplierPhoneController;

  /// Saved-supplier selector shown above the manual fields.
  final Widget supplierPicker;

  /// True while a saved supplier is selected: the name/phone snapshot comes
  /// from that supplier and cannot be edited.
  final bool supplierLocked;
  final TextEditingController notesController;

  final DateTime purchaseDate;
  final VoidCallback onDateSelected;

  /// Asks before emptying the purchase; null while saving.
  final VoidCallback? onClearCart;

  /// Payment fields, shown in the form on phones (the summary panel holds
  /// them on wide layouts).
  final Widget? payment;

  @override
  Widget build(BuildContext context) {
    final payment = this.payment;

    final nameField = TextFormField(
      controller: supplierNameController,
      readOnly: supplierLocked,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      decoration: InputDecoration(
        labelText: 'Supplier name',
        hintText: supplierLocked ? null : 'e.g. ABC Distributors',
        helperText: supplierLocked ? 'From the selected saved supplier' : null,
        prefixIcon: const Icon(Icons.storefront_outlined),
        suffixIcon: supplierLocked
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
    );
    final phoneField = TextFormField(
      controller: supplierPhoneController,
      readOnly: supplierLocked,
      keyboardType: TextInputType.phone,
      decoration: InputDecoration(
        labelText: 'Supplier phone',
        hintText: supplierLocked ? 'No phone saved' : 'e.g. 0240000000',
        prefixIcon: const Icon(Icons.phone_outlined),
        suffixIcon: supplierLocked
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionHeader(
          title: 'Supplier',
          subtitle: 'Choose a saved supplier or enter their details',
        ),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              supplierPicker,
              const SizedBox(height: AppSpacing.md),
              LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxWidth < 520) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        nameField,
                        const SizedBox(height: AppSpacing.md),
                        phoneField,
                      ],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: nameField),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(child: phoneField),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.xxl),
        SectionHeader(
          title: 'Items',
          subtitle: cart.isEmpty
              ? 'Search for products and enter what you paid'
              : '${cart.length} ${cart.length == 1 ? 'product' : 'products'}',
          trailing: cart.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Clear cart',
                  onPressed: onClearCart,
                  color: AppColors.textSecondary,
                  icon: const Icon(Icons.delete_sweep_outlined),
                ),
        ),
        const SizedBox(height: AppSpacing.md),
        _PurchaseProductSearch(products: products),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          padding: cart.isEmpty
              ? EdgeInsets.zero
              : const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          child: cart.isEmpty
              ? const _EmptyPurchaseCart()
              : Column(
                  children: [
                    for (var i = 0; i < cart.length; i++) ...[
                      if (i > 0) const RowDivider(),
                      _PurchaseCartRow(
                        key: ValueKey(cart[i].product.id),
                        item: cart[i],
                      ),
                    ],
                  ],
                ),
        ),
        if (payment != null) ...[
          const SizedBox(height: AppSpacing.xxl),
          const SectionHeader(title: 'Payment'),
          const SizedBox(height: AppSpacing.md),
          SurfaceCard(child: payment),
        ],
        const SizedBox(height: AppSpacing.xxl),
        const SectionHeader(title: 'Date & Notes'),
        const SizedBox(height: AppSpacing.md),
        SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onDateSelected,
                borderRadius: BorderRadius.circular(AppRadius.md),
                child: InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Purchase date',
                    prefixIcon: Icon(Icons.calendar_month_outlined),
                    suffixIcon: Icon(Icons.expand_more_rounded),
                  ),
                  child: Text(formatShortDate(purchaseDate)),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText: 'Optional purchase notes...',
                  alignLabelWithHint: true,
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
// PRODUCT SEARCH
// =============================================================

class _PurchaseProductSearch extends ConsumerWidget {
  const _PurchaseProductSearch({required this.products});

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(purchaseCartProvider.notifier);

    // The suggestion list matches the field's width, so it never runs off a
    // narrow screen.
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        return Autocomplete<Product>(
          displayStringForOption: (Product product) => product.name,

          optionsBuilder: (TextEditingValue textEditingValue) {
            final query = textEditingValue.text.trim().toLowerCase();

            if (query.isEmpty) {
              return products;
            }

            return products.where((Product product) {
              return product.name.toLowerCase().contains(query) ||
                  (product.sku?.toLowerCase().contains(query) ?? false) ||
                  (product.barcode?.toLowerCase().contains(query) ?? false);
            });
          },

          onSelected: (Product product) {
            notifier.addProduct(product);
          },

          fieldViewBuilder:
              (
                BuildContext context,
                TextEditingController controller,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted,
              ) {
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  textInputAction: TextInputAction.search,
                  decoration: const InputDecoration(
                    labelText: 'Search product',
                    hintText: 'Search by name, SKU or barcode',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                );
              },

          optionsViewBuilder:
              (
                BuildContext context,
                AutocompleteOnSelected<Product> onSelected,
                Iterable<Product> options,
              ) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 6,
                    color: AppColors.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: const BorderSide(color: AppColors.border),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: 300,
                        maxWidth: width,
                      ),
                      child: ListView.separated(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        separatorBuilder: (_, _) =>
                            const RowDivider(indent: 64),
                        itemBuilder: (context, index) {
                          final Product product = options.elementAt(index);

                          return ListRow(
                            title: product.name,
                            details: [
                              'Current stock: ${product.stockQuantity}',
                            ],
                            leading: ProductThumb(product: product),
                            trailing: RowValue(
                              value: formatGhs(product.costPrice),
                              caption: 'cost',
                            ),
                            onTap: () => onSelected(product),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
        );
      },
    );
  }
}

// =============================================================
// PURCHASE CART ROW
// =============================================================

/// One product being bought: name and line total, then unit cost,
/// quantity and remove.
class _PurchaseCartRow extends ConsumerWidget {
  const _PurchaseCartRow({super.key, required this.item});

  final PurchaseCartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(purchaseCartProvider.notifier);
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'In stock now: ${item.product.stockQuantity}',
                      style: textTheme.bodySmall?.copyWith(
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(formatGhs(item.subtotal), style: AppTypography.amount),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: item.unitCost.toStringAsFixed(2),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: AppTypography.amount,
                  decoration: const InputDecoration(
                    labelText: 'Unit cost',
                    prefixText: 'GHS ',
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final cost = double.tryParse(value.trim());

                    if (cost != null) {
                      notifier.updateUnitCost(item.product.id, cost);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              QuantityStepper(
                quantity: item.quantity,
                itemName: item.product.name,
                onDecrease: () => notifier.decreaseQuantity(item.product.id),
                onIncrease: () => notifier.increaseQuantity(item.product.id),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () {
                  notifier.removeProduct(item.product.id);
                },
                color: AppColors.textMuted,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EmptyPurchaseCart extends StatelessWidget {
  const _EmptyPurchaseCart();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      compact: true,
      icon: Icons.shopping_cart_outlined,
      title: 'No products added',
      message: 'Search above to add products.',
    );
  }
}

// =============================================================
// PAYMENT AND SUMMARY
// =============================================================

class _PaymentFields extends StatelessWidget {
  const _PaymentFields({
    required this.summary,
    required this.amountPaidController,
    required this.onPaymentChanged,
    required this.onAmountChanged,
  });

  final _SummaryValues summary;
  final TextEditingController amountPaidController;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionChipGroup(
          label: 'Payment method',
          options: _paymentMethods,
          selected: summary.paymentMethod,
          onSelected: summary.isSaving ? null : onPaymentChanged,
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: amountPaidController,
          enabled: !summary.isSaving,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: onAmountChanged,
          style: AppTypography.amount,
          decoration: InputDecoration(
            labelText: 'Amount paid',
            prefixText: 'GHS ',
            helperText: summary.paymentMethod == 'credit'
                ? 'Optional. Leave empty to buy fully on credit.'
                : null,
            helperMaxLines: 2,
          ),
        ),
      ],
    );
  }
}

class _Totals extends StatelessWidget {
  const _Totals({required this.summary});

  final _SummaryValues summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryLine(
          label: 'Total',
          value: formatGhs(summary.total),
          emphasized: true,
        ),
        const SizedBox(height: AppSpacing.sm),
        SummaryLine(
          label: 'Balance',
          value: formatGhs(summary.balance),
          valueColor: summary.balance > 0 && summary.cart.isNotEmpty
              ? AppColors.warning
              : null,
        ),
      ],
    );
  }
}

/// Wide layouts: counts and payment scroll; the totals and the action stay
/// pinned at the bottom.
class _SummaryPanel extends StatelessWidget {
  const _SummaryPanel({
    required this.summary,
    required this.amountPaidController,
    required this.onPaymentChanged,
    required this.onAmountChanged,
    required this.onComplete,
  });

  final _SummaryValues summary;
  final TextEditingController amountPaidController;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: SectionHeader(
              title: 'Purchase Summary',
              subtitle: 'Review payment before completing',
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(AppSpacing.xl),
              children: [
                SummaryLine(label: 'Items', value: '${summary.cart.length}'),
                const SizedBox(height: AppSpacing.sm),
                SummaryLine(
                  label: 'Total quantity',
                  value: '${summary.totalQuantity}',
                ),
                const SizedBox(height: AppSpacing.xl),
                _PaymentFields(
                  summary: summary,
                  amountPaidController: amountPaidController,
                  onPaymentChanged: onPaymentChanged,
                  onAmountChanged: onAmountChanged,
                ),
              ],
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _Totals(summary: summary),
                  const SizedBox(height: AppSpacing.lg),
                  SizedBox(
                    width: double.infinity,
                    child: _CompletePurchaseButton(
                      summary: summary,
                      onPressed: onComplete,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CompletePurchaseButton extends StatelessWidget {
  const _CompletePurchaseButton({
    required this.summary,
    required this.onPressed,
    this.showIcon = true,
  });

  final _SummaryValues summary;
  final VoidCallback onPressed;
  final bool showIcon;

  @override
  Widget build(BuildContext context) {
    final isSaving = summary.isSaving;
    final label = Text(
      isSaving ? 'Saving Purchase...' : 'Complete Purchase',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
    final style = FilledButton.styleFrom(
      minimumSize: const Size(0, 52),
      disabledBackgroundColor: isSaving ? AppColors.primary : null,
      disabledForegroundColor: isSaving ? AppColors.textOnPrimary : null,
    );
    final onPressed = isSaving ? null : this.onPressed;

    if (!showIcon && !isSaving) {
      return FilledButton(onPressed: onPressed, style: style, child: label);
    }

    return FilledButton.icon(
      onPressed: onPressed,
      style: style,
      icon: isSaving
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textOnPrimary,
              ),
            )
          : const Icon(Icons.check_circle_outline_rounded),
      label: label,
    );
  }
}

// =============================================================
// SAVED SUPPLIER PICKER
// =============================================================

/// Optional link to a saved, active supplier. Loading, error and empty
/// states only replace the selector; the manual supplier fields below stay
/// usable in every state.
class _SavedSupplierPicker extends ConsumerWidget {
  const _SavedSupplierPicker({
    required this.selected,
    required this.enabled,
    required this.onSelected,
    required this.onCleared,
  });

  final Supplier? selected;
  final bool enabled;
  final ValueChanged<Supplier> onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final suppliersAsync = ref.watch(suppliersProvider);
    final selected = this.selected;

    final Widget selector = suppliersAsync.when(
      loading: () => const _PickerMessage(
        icon: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        text: 'Loading saved suppliers...',
      ),
      error: (_, _) => _PickerMessage(
        icon: const Icon(
          Icons.error_outline_rounded,
          size: 18,
          color: AppColors.danger,
        ),
        text:
            'Could not load saved suppliers. You can still enter '
            'supplier details below.',
        action: TextButton(
          onPressed: () => ref.invalidate(suppliersProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (suppliers) {
        if (suppliers.isEmpty && selected == null) {
          return const _PickerMessage(
            icon: Icon(
              Icons.info_outline_rounded,
              size: 18,
              color: AppColors.textSecondary,
            ),
            text:
                'No saved suppliers yet. Enter supplier details '
                'below.',
          );
        }

        return _SupplierDropdown(
          suppliers: suppliers,
          selected: selected,
          enabled: enabled,
          onSelected: onSelected,
          onCleared: onCleared,
        );
      },
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        selector,
        if (selected != null)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: enabled ? onCleared : null,
              icon: const Icon(Icons.close_rounded, size: 18),
              label: const Text('Clear supplier'),
            ),
          ),
      ],
    );
  }
}

class _SupplierDropdown extends StatelessWidget {
  const _SupplierDropdown({
    required this.suppliers,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    required this.onCleared,
  });

  final List<Supplier> suppliers;
  final Supplier? selected;
  final bool enabled;
  final ValueChanged<Supplier> onSelected;
  final VoidCallback onCleared;

  @override
  Widget build(BuildContext context) {
    final selected = this.selected;

    // Keep the current selection listed even if a refresh no longer returns
    // it, so a background reload never silently drops the user's choice.
    final options = [
      ...suppliers,
      if (selected != null &&
          suppliers.every((supplier) => supplier.id != selected.id))
        selected,
    ];

    return DropdownButtonFormField<String?>(
      // Re-keyed so a selection cleared outside the dropdown is reflected.
      key: ValueKey<String?>(selected?.id),
      initialValue: selected?.id,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Saved supplier',
        prefixIcon: Icon(Icons.business_outlined),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('No saved supplier'),
        ),
        for (final supplier in options)
          DropdownMenuItem<String?>(
            value: supplier.id,
            child: Text(
              supplier.phone == null
                  ? supplier.name
                  : '${supplier.name} · ${supplier.phone}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
      ],
      onChanged: enabled
          ? (id) {
              if (id == null) {
                onCleared();
                return;
              }
              onSelected(options.firstWhere((supplier) => supplier.id == id));
            }
          : null,
    );
  }
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({required this.icon, required this.text, this.action});

  final Widget icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              text,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
