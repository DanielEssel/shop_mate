import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/widgets/product_visuals.dart';
import '../../domain/entities/cart_item.dart';
import '../providers/sales_provider.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../../customers/presentation/providers/customers_provider.dart';
import '../../../customers/domain/entities/customer.dart';

/// Payment methods offered at checkout, in display order.
const _paymentMethods = <(String, String)>[
  ('cash', 'Cash'),
  ('mobile_money', 'Mobile Money'),
  ('card', 'Card'),
  ('bank_transfer', 'Bank Transfer'),
  ('credit', 'Credit'),
];

/// Tender methods for a credit sale's initial payment (no credit).
const _tenderMethods = <(String, String)>[
  ('cash', 'Cash'),
  ('mobile_money', 'Mobile Money'),
  ('card', 'Card'),
  ('bank_transfer', 'Bank Transfer'),
];

class NewSaleScreen extends ConsumerStatefulWidget {
  const NewSaleScreen({super.key});

  @override
  ConsumerState<NewSaleScreen> createState() => _NewSaleScreenState();
}

class _NewSaleScreenState extends ConsumerState<NewSaleScreen> {
  final _searchController = TextEditingController();
  final _amountPaidController = TextEditingController();

  String _searchQuery = '';
  String _paymentMethod = 'cash';
  String? _initialPaymentMethod;
  String? _customerId;
  String? _creditRequestFingerprint;
  String? _creditIdempotencyKey;
  bool _isProcessing = false;

  /// Phones list a few products until the user searches or asks for all,
  /// so the current sale stays close.
  bool _showAllProducts = false;
  static const _phoneProductPreview = 6;

  /// From this width the products and the current sale sit side by side.
  static const double _splitFrom = 720;

  /// How far messages float above the bottom so they never cover the pinned
  /// Complete Sale area. Set from the current layout on each build.
  double _messageLift = 0;

  @override
  void dispose() {
    _searchController.dispose();
    _amountPaidController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(salesProductsProvider);
    final cart = ref.watch(saleCartProvider);
    final cartNotifier = ref.read(saleCartProvider.notifier);
    final customersAsync = ref.watch(customersProvider);
    final subtotal = cartNotifier.subtotal;

    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0;

    final change = _paymentMethod == 'credit'
        ? 0.0
        : (amountPaid - subtotal).clamp(0.0, double.infinity).toDouble();

    final checkout = _Checkout(
      cart: cart,
      subtotal: subtotal,
      amountPaid: amountPaid,
      change: change,
      paymentMethod: _paymentMethod,
      initialPaymentMethod: _initialPaymentMethod,
      customerId: _customerId,
      isProcessing: _isProcessing,
    );

    void completeSale() {
      _completeSale(cart: cart, subtotal: subtotal, customerId: _customerId);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isSplit = constraints.maxWidth >= _splitFrom;
            final horizontal = isSplit
                ? Breakpoints.gutter(constraints.maxWidth)
                : Breakpoints.pagePadding(constraints.maxWidth);
            _messageLift = isSplit ? 200 : 104;

            final header = Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isSplit ? AppSpacing.xxl : AppSpacing.md,
                horizontal,
                AppSpacing.lg,
              ),
              child: PageHeader(
                title: 'New Sale',
                subtitle: 'Add products, take payment and complete the sale',
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
                      onRetry: () => ref.invalidate(salesProductsProvider),
                    ),
                  ),
                ],
              ),
              data: (products) {
                final customers =
                    customersAsync.unwrapPrevious().value ?? const [];
                final filtered = _filterProducts(products);

                if (isSplit) {
                  return _buildSplit(
                    header: header,
                    horizontal: horizontal,
                    width: constraints.maxWidth,
                    customers: customers,
                    products: filtered,
                    hasProducts: products.isNotEmpty,
                    checkout: checkout,
                    onAddProduct: cartNotifier.addProduct,
                    onComplete: completeSale,
                  );
                }

                return _buildStacked(
                  header: header,
                  horizontal: horizontal,
                  customers: customers,
                  products: filtered,
                  hasProducts: products.isNotEmpty,
                  checkout: checkout,
                  onAddProduct: cartNotifier.addProduct,
                  onComplete: completeSale,
                );
              },
            );
          },
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // Layouts
  // -----------------------------------------------------------------

  /// Tablet and desktop: products fill the left; the current sale is a
  /// panel on the right with its total and action always in view.
  Widget _buildSplit({
    required Widget header,
    required double horizontal,
    required double width,
    required List<Customer> customers,
    required List<Product> products,
    required bool hasProducts,
    required _Checkout checkout,
    required ValueChanged<Product> onAddProduct,
    required VoidCallback onComplete,
  }) {
    final panelWidth = (width * 0.38).clamp(320.0, 420.0);
    final inCart = {
      for (final item in checkout.cart) item.product.id: item.quantity,
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: header),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  0,
                  horizontal,
                  AppSpacing.lg,
                ),
                sliver: SliverToBoxAdapter(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final customer = _CustomerSelector(
                        customers: customers,
                        value: _customerId,
                        enabled: !_isProcessing,
                        onChanged: _changeCustomer,
                      );
                      final search = _productSearch();

                      if (constraints.maxWidth < 560) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            customer,
                            const SizedBox(height: AppSpacing.md),
                            search,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: customer),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(child: search),
                        ],
                      );
                    },
                  ),
                ),
              ),
              SliverPadding(
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  0,
                  horizontal,
                  AppSpacing.xxl,
                ),
                sliver: products.isEmpty
                    ? SliverToBoxAdapter(
                        child: SurfaceCard(child: _noProducts(hasProducts)),
                      )
                    : SliverGrid.builder(
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 240,
                              mainAxisExtent: 128,
                              crossAxisSpacing: AppSpacing.md,
                              mainAxisSpacing: AppSpacing.md,
                            ),
                        itemCount: products.length,
                        itemBuilder: (context, index) {
                          final product = products[index];
                          return _ProductTile(
                            product: product,
                            inCart: inCart[product.id] ?? 0,
                            onAdd: () => onAddProduct(product),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: panelWidth,
          child: DecoratedBox(
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(left: BorderSide(color: AppColors.border)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.xl,
                    AppSpacing.xl,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: _cartHeading(checkout.cart),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.xl,
                      AppSpacing.md,
                      AppSpacing.xl,
                      AppSpacing.lg,
                    ),
                    children: [
                      if (checkout.cart.isEmpty)
                        const _EmptyCart()
                      else
                        for (var i = 0; i < checkout.cart.length; i++) ...[
                          if (i > 0) const RowDivider(),
                          _CartLine(item: checkout.cart[i]),
                        ],
                      if (checkout.cart.isNotEmpty) ...[
                        const SizedBox(height: AppSpacing.lg),
                        _PaymentSection(
                          checkout: checkout,
                          amountPaidController: _amountPaidController,
                          onPaymentChanged: _changePaymentMethod,
                          onInitialPaymentMethodChanged:
                              _changeInitialPaymentMethod,
                          onAmountChanged: _handleAmountChanged,
                        ),
                      ],
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
                        _Totals(checkout: checkout),
                        const SizedBox(height: AppSpacing.lg),
                        _CompleteSaleButton(
                          checkout: checkout,
                          onPressed: onComplete,
                          expand: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Phones: one scroll (customer, products, current sale, payment) above a
  /// checkout bar that stays in reach and rises with the keyboard.
  Widget _buildStacked({
    required Widget header,
    required double horizontal,
    required List<Customer> customers,
    required List<Product> products,
    required bool hasProducts,
    required _Checkout checkout,
    required ValueChanged<Product> onAddProduct,
    required VoidCallback onComplete,
  }) {
    final searching = _searchQuery.trim().isNotEmpty;
    final limit = searching || _showAllProducts
        ? products.length
        : min(products.length, _phoneProductPreview);
    final hidden = products.length - limit;
    final inCart = {
      for (final item in checkout.cart) item.product.id: item.quantity,
    };
    final cart = checkout.cart;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: EdgeInsets.fromLTRB(0, 0, 0, AppSpacing.xxl),
            children: [
              header,
              Padding(
                padding: EdgeInsets.symmetric(horizontal: horizontal),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _CustomerSelector(
                      customers: customers,
                      value: _customerId,
                      enabled: !_isProcessing,
                      onChanged: _changeCustomer,
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    const SectionHeader(title: 'Products'),
                    const SizedBox(height: AppSpacing.md),
                    _productSearch(),
                    const SizedBox(height: AppSpacing.md),
                    SurfaceCard(
                      padding: EdgeInsets.zero,
                      clip: true,
                      child: products.isEmpty
                          ? _noProducts(hasProducts)
                          : Column(
                              children: [
                                for (var i = 0; i < limit; i++) ...[
                                  if (i > 0) const RowDivider(indent: 64),
                                  _ProductPickRow(
                                    product: products[i],
                                    inCart: inCart[products[i].id] ?? 0,
                                    onAdd: () => onAddProduct(products[i]),
                                  ),
                                ],
                                if (hidden > 0) ...[
                                  const RowDivider(),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _showAllProducts = true),
                                    style: TextButton.styleFrom(
                                      minimumSize: const Size.fromHeight(48),
                                    ),
                                    child: Text(
                                      'Show all ${products.length} products',
                                    ),
                                  ),
                                ],
                              ],
                            ),
                    ),
                    const SizedBox(height: AppSpacing.xxl),
                    _cartHeading(cart),
                    const SizedBox(height: AppSpacing.md),
                    SurfaceCard(
                      padding: cart.isEmpty
                          ? EdgeInsets.zero
                          : const EdgeInsets.symmetric(
                              horizontal: AppSpacing.lg,
                            ),
                      child: cart.isEmpty
                          ? const _EmptyCart()
                          : Column(
                              children: [
                                for (var i = 0; i < cart.length; i++) ...[
                                  if (i > 0) const RowDivider(),
                                  _CartLine(item: cart[i]),
                                ],
                              ],
                            ),
                    ),
                    if (cart.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.xxl),
                      const SectionHeader(title: 'Payment'),
                      const SizedBox(height: AppSpacing.md),
                      SurfaceCard(
                        child: _PaymentSection(
                          checkout: checkout,
                          amountPaidController: _amountPaidController,
                          onPaymentChanged: _changePaymentMethod,
                          onInitialPaymentMethodChanged:
                              _changeInitialPaymentMethod,
                          onAmountChanged: _handleAmountChanged,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
        CheckoutBar(
          label: cart.isEmpty
              ? 'Total'
              : 'Total · ${checkout.itemCount} '
                    '${checkout.itemCount == 1 ? 'item' : 'items'}',
          amount: formatGhs(checkout.subtotal),
          caption: checkout.balanceCaption,
          captionColor: checkout.isCredit
              ? AppColors.warning
              : AppColors.success,
          action: _CompleteSaleButton(
            checkout: checkout,
            onPressed: onComplete,
          ),
        ),
      ],
    );
  }

  // -----------------------------------------------------------------
  // Pieces
  // -----------------------------------------------------------------

  Widget _productSearch() {
    return AppSearchField(
      controller: _searchController,
      hintText: 'Search name, category, SKU or barcode...',
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _noProducts(bool hasProducts) {
    return hasProducts
        ? const EmptyState(
            compact: true,
            icon: Icons.search_off_rounded,
            title: 'No products found',
            message: 'Try another search term.',
          )
        : const EmptyState(
            compact: true,
            icon: Icons.inventory_2_outlined,
            title: 'No products to sell',
            message: 'Products in stock will appear here.',
          );
  }

  Widget _cartHeading(List<CartItem> cart) {
    final count = cart.fold<int>(0, (sum, item) => sum + item.quantity);

    return SectionHeader(
      title: 'Current Sale',
      subtitle: cart.isEmpty
          ? 'No items yet'
          : '$count ${count == 1 ? 'item' : 'items'}',
      trailing: cart.isEmpty
          ? null
          : IconButton(
              tooltip: 'Clear cart',
              onPressed: _isProcessing
                  ? null
                  : ref.read(saleCartProvider.notifier).clearCart,
              color: AppColors.textSecondary,
              icon: const Icon(Icons.delete_sweep_outlined),
            ),
    );
  }

  List<Product> _filterProducts(List<Product> products) {
    final query = _searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          (product.categoryName?.toLowerCase().contains(query) ?? false) ||
          (product.sku?.toLowerCase().contains(query) ?? false) ||
          (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();
  }

  // -----------------------------------------------------------------
  // State changes and checkout (behaviour unchanged)
  // -----------------------------------------------------------------

  void _changePaymentMethod(String value) {
    setState(() {
      _paymentMethod = value;
      _initialPaymentMethod = null;

      if (value == 'credit') {
        _amountPaidController.clear();
      }
    });
  }

  void _changeCustomer(String? customerId) {
    setState(() {
      _customerId = customerId;
    });
  }

  void _changeInitialPaymentMethod(String? paymentMethod) {
    setState(() {
      _initialPaymentMethod = paymentMethod;
    });
  }

  void _handleAmountChanged(String value) {
    final amount = double.tryParse(value.trim());

    setState(() {
      if (_paymentMethod == 'credit' && (amount == null || amount == 0)) {
        _initialPaymentMethod = null;
      }
    });
  }

  String _creditIdempotencyKeyFor({
    required String customerId,
    required List<CartItem> cart,
    required double initialPaymentAmount,
    required String? initialPaymentMethod,
  }) {
    final requestFingerprint = [
      customerId,
      initialPaymentAmount.toStringAsFixed(2),
      initialPaymentMethod ?? '',
      ...cart.map((item) => '${item.product.id}:${item.quantity}'),
    ].join('|');

    if (_creditRequestFingerprint != requestFingerprint ||
        _creditIdempotencyKey == null) {
      _creditRequestFingerprint = requestFingerprint;
      _creditIdempotencyKey = _generateUuidV4();
    }

    return _creditIdempotencyKey!;
  }

  String _generateUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
      growable: false,
    );

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  Future<void> _completeSale({
    required List<CartItem> cart,
    required double subtotal,
    String? customerId,
  }) async {
    final isCreditSale = _paymentMethod == 'credit';

    if (cart.isEmpty) {
      _showMessage('Add at least one product.');
      return;
    }

    final rawAmount = _amountPaidController.text.trim();
    final parsedAmount = double.tryParse(rawAmount);
    final amountPaid = parsedAmount ?? 0;

    if (!isCreditSale && amountPaid < subtotal) {
      _showMessage('Amount paid cannot be less than the total.');
      return;
    }

    if (isCreditSale) {
      if (customerId == null) {
        _showMessage('Please select a customer for a credit sale.');
        return;
      }

      if (rawAmount.isNotEmpty &&
          (parsedAmount == null || !parsedAmount.isFinite)) {
        _showMessage('Enter a valid initial payment amount.');
        return;
      }

      if (amountPaid < 0) {
        _showMessage('Initial payment cannot be negative.');
        return;
      }

      if (amountPaid > subtotal) {
        _showMessage('Initial payment cannot exceed the sale total.');
        return;
      }

      if (amountPaid > 0 && _initialPaymentMethod == null) {
        _showMessage('Select a tender method for the initial payment.');
        return;
      }
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final createSale = ref.read(createSaleProvider);
      final sale = isCreditSale
          ? await createSale.createCreditSaleWithInitialPayment(
              customerId: customerId!,
              items: cart,
              initialPaymentAmount: amountPaid,
              initialPaymentMethod: amountPaid > 0
                  ? _initialPaymentMethod
                  : null,
              idempotencyKey: _creditIdempotencyKeyFor(
                customerId: customerId,
                cart: cart,
                initialPaymentAmount: amountPaid,
                initialPaymentMethod: amountPaid > 0
                    ? _initialPaymentMethod
                    : null,
              ),
            )
          : await createSale.call(
              customerId: customerId,
              items: cart.map((item) {
                return {
                  'product_id': item.product.id,
                  'quantity': item.quantity,
                };
              }).toList(),
              paymentMethod: _paymentMethod,
              amountPaid: amountPaid,
            );

      _creditRequestFingerprint = null;
      _creditIdempotencyKey = null;

      ref.read(saleCartProvider.notifier).clearCart();

      ref.invalidate(productsProvider);
      ref.invalidate(salesProductsProvider);
      ref.invalidate(salesProvider);
      if (isCreditSale && customerId != null) {
        ref.invalidate(customerCreditStatementProvider(customerId));
      }

      if (!mounted) return;

      final viewReceipt = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final textTheme = Theme.of(dialogContext).textTheme;

          return AlertDialog(
            title: const Text('Sale Completed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const IconTile(
                  icon: Icons.check_rounded,
                  color: AppColors.success,
                  size: 56,
                ),
                const SizedBox(height: AppSpacing.lg),
                Text(
                  sale.saleNumber,
                  style: textTheme.titleLarge?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Text(
                  'Total: ${formatGhs(sale.totalAmount)}',
                  style: AppTypography.amount,
                ),
                if (sale.changeAmount > 0)
                  Text(
                    'Change: ${formatGhs(sale.changeAmount)}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Done'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('View receipt'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        context.go(
          viewReceipt == true ? '/sales/${sale.id}/receipt' : '/sales',
        );
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(
        isCreditSale
            ? _friendlySaleError(error)
            : error.toString().replaceFirst('Exception: ', ''),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  String _friendlySaleError(Object error) {
    final message = error is PostgrestException
        ? error.message
        : error.toString();
    final normalized = message.toLowerCase();

    if (normalized.contains('customer is required') ||
        (normalized.contains('customer') &&
            (normalized.contains('not found') ||
                normalized.contains('inactive')))) {
      return 'Select an active customer for this credit sale.';
    }

    if (normalized.contains('payment method') ||
        normalized.contains('tender method') ||
        normalized.contains('initial payment')) {
      if (normalized.contains('exceeds sale total')) {
        return 'Initial payment cannot exceed the sale total.';
      }
      return 'Check the initial payment amount and tender method.';
    }

    if (normalized.contains('idempotency key')) {
      return 'This credit-sale request key was already used with different details. Review the sale and try again.';
    }

    if (normalized.contains('insufficient stock')) {
      return 'Stock is insufficient for one or more items in this sale.';
    }

    return 'Unable to complete the sale. Please try again.';
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
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
}

// =============================================================
// CHECKOUT VALUES
// =============================================================

/// What the checkout widgets read, computed once per build.
class _Checkout {
  const _Checkout({
    required this.cart,
    required this.subtotal,
    required this.amountPaid,
    required this.change,
    required this.paymentMethod,
    required this.initialPaymentMethod,
    required this.customerId,
    required this.isProcessing,
  });

  final List<CartItem> cart;
  final double subtotal;
  final double amountPaid;
  final double change;
  final String paymentMethod;
  final String? initialPaymentMethod;
  final String? customerId;
  final bool isProcessing;

  bool get isCredit => paymentMethod == 'credit';

  int get itemCount => cart.fold<int>(0, (sum, item) => sum + item.quantity);

  double get outstanding =>
      (subtotal - amountPaid).clamp(0.0, double.infinity).toDouble();

  /// "Change GHS 5.00" or "Outstanding GHS 40.00", once there is something
  /// to say.
  String? get balanceCaption {
    if (cart.isEmpty) return null;
    if (isCredit) return 'Outstanding ${formatGhs(outstanding)}';
    if (change > 0) return 'Change ${formatGhs(change)}';
    return null;
  }
}

// =============================================================
// CUSTOMER
// =============================================================

class _CustomerSelector extends StatelessWidget {
  const _CustomerSelector({
    required this.customers,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final List<Customer> customers;
  final String? value;
  final bool enabled;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Customer',
        hintText: 'Select customer',
        prefixIcon: Icon(Icons.person_outline_rounded),
      ),
      items: [
        const DropdownMenuItem<String?>(
          value: null,
          child: Text('Walk-in Customer'),
        ),
        ...customers.map((customer) {
          return DropdownMenuItem<String?>(
            value: customer.id,
            child: Text(
              customer.phone != null && customer.phone!.trim().isNotEmpty
                  ? '${customer.name} • ${customer.phone}'
                  : customer.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: enabled ? onChanged : null,
    );
  }
}

// =============================================================
// PRODUCTS
// =============================================================

/// Desktop/tablet product tile: tap anywhere to add one.
class _ProductTile extends StatelessWidget {
  const _ProductTile({
    required this.product,
    required this.inCart,
    required this.onAdd,
  });

  final Product product;
  final int inCart;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.isOutOfStock;
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      button: !outOfStock,
      enabled: !outOfStock,
      label: outOfStock
          ? '${product.name}, out of stock'
          : 'Add ${product.name}',
      excludeSemantics: true,
      child: SurfaceCard(
        padding: const EdgeInsets.all(AppSpacing.md),
        borderColor: inCart > 0 ? AppColors.primary : AppColors.border,
        color: outOfStock ? AppColors.surfaceSubtle : AppColors.surface,
        onTap: outOfStock ? null : onAdd,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ProductThumb(product: product, size: 36),
                const SizedBox(width: AppSpacing.sm),
                // The badge gives way (truncates) before the tile overflows.
                Expanded(
                  child: Align(
                    alignment: Alignment.topRight,
                    child: inCart > 0
                        ? StatusBadge(
                            label: '$inCart in sale',
                            tone: StatusTone.brand,
                            showDot: false,
                          )
                        : outOfStock
                        ? const StatusBadge(
                            label: 'Out of stock',
                            tone: StatusTone.danger,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              product.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: textTheme.bodyMedium?.copyWith(
                color: outOfStock ? AppColors.textMuted : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                Expanded(
                  child: Text(
                    formatGhs(product.sellingPrice),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.amount,
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  outOfStock ? 'None left' : '${product.stockQuantity} left',
                  style: textTheme.bodySmall?.copyWith(
                    color: product.isLowStock
                        ? AppColors.warning
                        : AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Phone product row: tap the row or the add button to add one.
class _ProductPickRow extends StatelessWidget {
  const _ProductPickRow({
    required this.product,
    required this.inCart,
    required this.onAdd,
  });

  final Product product;
  final int inCart;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.isOutOfStock;

    return ListRow(
      title: product.name,
      details: [formatGhs(product.sellingPrice), stockQuantityLabel(product)],
      leading: ProductThumb(product: product),
      onTap: outOfStock ? null : onAdd,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.sm,
        AppSpacing.sm,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (inCart > 0)
            StatusBadge(
              label: '$inCart',
              tone: StatusTone.brand,
              showDot: false,
            ),
          if (outOfStock)
            const StatusBadge(label: 'Out', tone: StatusTone.danger)
          else
            IconButton(
              tooltip: 'Add ${product.name}',
              onPressed: onAdd,
              color: AppColors.primary,
              icon: const Icon(Icons.add_circle_outline_rounded),
            ),
        ],
      ),
    );
  }
}

// =============================================================
// CART
// =============================================================

/// One line of the sale: name and unit price, quantity, line total and
/// remove. Two rows so long names and amounts never collide.
class _CartLine extends ConsumerWidget {
  const _CartLine({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(saleCartProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final atStockLimit = item.quantity >= item.product.stockQuantity;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(formatGhs(item.subtotal), style: AppTypography.amount),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  atStockLimit
                      ? '${formatGhs(item.product.sellingPrice)} each · '
                            'all ${item.product.stockQuantity} in stock'
                      : '${formatGhs(item.product.sellingPrice)} each',
                  // Wraps beside the stepper on small phones rather than
                  // cutting off the price or the stock warning.
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodySmall?.copyWith(
                    color: atStockLimit
                        ? AppColors.warning
                        : AppColors.textMuted,
                  ),
                ),
              ),
              QuantityStepper(
                quantity: item.quantity,
                itemName: item.product.name,
                onDecrease: () => notifier.decreaseQuantity(item.product.id),
                onIncrease: atStockLimit
                    ? null
                    : () => notifier.increaseQuantity(item.product.id),
              ),
              IconButton(
                tooltip: 'Remove ${item.product.name}',
                onPressed: () => notifier.removeProduct(item.product.id),
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

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      compact: true,
      icon: Icons.shopping_cart_outlined,
      title: 'Your cart is empty',
      message: 'Add products to start a sale.',
    );
  }
}

// =============================================================
// PAYMENT
// =============================================================

class _PaymentSection extends StatelessWidget {
  const _PaymentSection({
    required this.checkout,
    required this.amountPaidController,
    required this.onPaymentChanged,
    required this.onInitialPaymentMethodChanged,
    required this.onAmountChanged,
  });

  final _Checkout checkout;
  final TextEditingController amountPaidController;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String?> onInitialPaymentMethodChanged;
  final ValueChanged<String> onAmountChanged;

  @override
  Widget build(BuildContext context) {
    final isCredit = checkout.isCredit;
    final enabled = !checkout.isProcessing;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OptionChipGroup(
          label: 'Payment method',
          options: _paymentMethods,
          selected: checkout.paymentMethod,
          onSelected: enabled ? onPaymentChanged : null,
        ),
        if (isCredit && checkout.customerId == null) ...[
          const SizedBox(height: AppSpacing.md),
          const _Notice(
            icon: Icons.person_search_outlined,
            text: 'Select a customer above for a credit sale.',
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: amountPaidController,
          enabled: enabled,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.done,
          onChanged: onAmountChanged,
          style: AppTypography.amount,
          decoration: InputDecoration(
            labelText: isCredit ? 'Initial payment' : 'Amount paid',
            helperText: isCredit
                ? 'Optional. Leave empty to sell fully on credit.'
                : null,
            helperMaxLines: 2,
            prefixText: 'GHS ',
          ),
        ),
        if (isCredit && checkout.amountPaid > 0) ...[
          const SizedBox(height: AppSpacing.lg),
          OptionChipGroup(
            label: 'Initial payment method',
            options: _tenderMethods,
            selected: checkout.initialPaymentMethod,
            onSelected: enabled ? onInitialPaymentMethodChanged : null,
          ),
        ],
      ],
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.warningLight,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.warning),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// TOTALS AND ACTION
// =============================================================

class _Totals extends StatelessWidget {
  const _Totals({required this.checkout});

  final _Checkout checkout;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SummaryLine(
          label: 'Total',
          value: formatGhs(checkout.subtotal),
          emphasized: true,
        ),
        if (checkout.cart.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.sm),
          if (checkout.isCredit)
            SummaryLine(
              label: 'Outstanding',
              value: formatGhs(checkout.outstanding),
              valueColor: checkout.outstanding > 0 ? AppColors.warning : null,
            )
          else
            SummaryLine(
              label: 'Change',
              value: formatGhs(checkout.change),
              valueColor: checkout.change > 0 ? AppColors.success : null,
            ),
        ],
      ],
    );
  }
}

class _CompleteSaleButton extends StatelessWidget {
  const _CompleteSaleButton({
    required this.checkout,
    required this.onPressed,
    this.expand = false,
  });

  final _Checkout checkout;
  final VoidCallback onPressed;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final button = FilledButton.icon(
      onPressed: checkout.cart.isEmpty || checkout.isProcessing
          ? null
          : onPressed,
      style: FilledButton.styleFrom(
        minimumSize: const Size(0, 52),
        disabledBackgroundColor: checkout.isProcessing
            ? AppColors.primary
            : null,
        disabledForegroundColor: checkout.isProcessing
            ? AppColors.textOnPrimary
            : null,
      ),
      icon: checkout.isProcessing
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: AppColors.textOnPrimary,
              ),
            )
          : const Icon(Icons.check_circle_outline_rounded),
      label: Text(
        checkout.isProcessing ? 'Processing...' : 'Complete Sale',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );

    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}
