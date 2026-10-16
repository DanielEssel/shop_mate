import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/widgets/product_visuals.dart';
import '../../../discounts/domain/entities/discount_pricing.dart';
import '../../../discounts/domain/entities/discount_settings.dart';
import '../../../discounts/presentation/providers/discount_settings_providers.dart';
import '../../domain/entities/cart_item.dart';
import '../../domain/entities/pending_sale_request.dart';
import '../../domain/entities/recorded_sale.dart';
import '../../domain/entities/sale_outcome.dart';
import '../../domain/entities/sale_request_exception.dart';
import '../providers/pending_sale_controller.dart';
import '../providers/sales_provider.dart';
import '../widgets/pending_sale_panel.dart';
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

/// Shown for SQLSTATE SMD01 (recognised in the data layer by its code).
const _discountRefusedMessage =
    'Discount could not be applied to one or more selected products. '
    'Review the discount settings or remove the affected product before '
    'trying again.';

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
  bool _isProcessing = false;

  /// Whether the first answer about a saved, unconfirmed sale has been
  /// handled (a saved sale found on entry is looked up once, automatically).
  bool _pendingChecked = false;

  @override
  void initState() {
    super.initState();
    ref.listenManual(
      pendingSaleControllerProvider,
      (_, next) => _checkSavedSaleOnEntry(next),
      fireImmediately: true,
    );
  }

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
    // An estimate with the shop's discount; the recorded sale is what
    // counts.
    final pricing = _CheckoutPricing.of(
      cart,
      discounts: ref.watch(discountSettingsProvider),
      now: DateTime.now(),
    );
    final total = pricing.total;

    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0;

    final change = _paymentMethod == 'credit'
        ? 0.0
        : (amountPaid - total).clamp(0.0, double.infinity).toDouble();

    // A sale whose outcome is unconfirmed blocks new sales until resolved
    // (and while the device's saved record is still being read).
    final pendingAsync = ref.watch(pendingSaleControllerProvider);
    final pendingState = pendingAsync.value;
    final locked = pendingState == null || pendingState.blocksCheckout;
    void addProduct(Product product) {
      if (!locked && !_isProcessing) cartNotifier.addProduct(product);
    }

    final checkout = _Checkout(
      cart: cart,
      pricing: pricing,
      total: total,
      amountPaid: amountPaid,
      change: change,
      paymentMethod: _paymentMethod,
      initialPaymentMethod: _initialPaymentMethod,
      customerId: _customerId,
      isProcessing: _isProcessing,
      locked: locked,
    );

    void completeSale() {
      _completeSale(cart: cart, estimatedTotal: total, customerId: _customerId);
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
                    onAddProduct: addProduct,
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
                  onAddProduct: addProduct,
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
                      if (_pendingPanel() case final panel?) ...[
                        panel,
                        const SizedBox(height: AppSpacing.lg),
                      ],
                      if (checkout.cart.isEmpty)
                        const _EmptyCart()
                      else
                        for (var i = 0; i < checkout.cart.length; i++) ...[
                          if (i > 0) const RowDivider(),
                          _CartLine(
                            item: checkout.cart[i],
                            preview: checkout.pricing.previewFor(
                              checkout.cart[i],
                            ),
                            enabled: !checkout.locked,
                          ),
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
                    if (_pendingPanel() case final panel?) ...[
                      panel,
                      const SizedBox(height: AppSpacing.lg),
                    ],
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
                                  _CartLine(
                                    item: cart[i],
                                    preview: checkout.pricing.previewFor(
                                      cart[i],
                                    ),
                                    enabled: !checkout.locked,
                                  ),
                                ],
                              ],
                            ),
                    ),
                    if (cart.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.md),
                      _DiscountBreakdown(pricing: checkout.pricing),
                    ],
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
          amount: formatGhs(checkout.total),
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
              onPressed: _isProcessing || _isCheckoutLocked
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

  Future<void> _completeSale({
    required List<CartItem> cart,
    required double estimatedTotal,
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

    // Checked against the estimate; the server checks the recorded total.
    if (!isCreditSale && amountPaid < estimatedTotal) {
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

      if (amountPaid > estimatedTotal) {
        _showMessage('Initial payment cannot exceed the sale total.');
        return;
      }

      if (amountPaid > 0 && _initialPaymentMethod == null) {
        _showMessage('Select a tender method for the initial payment.');
        return;
      }
    }

    final draft = SaleDraft(
      kind: isCreditSale ? SaleRequestKind.credit : SaleRequestKind.standard,
      paymentMethod: _paymentMethod,
      customerId: customerId,
      amountPaid: amountPaid,
      initialPaymentMethod: isCreditSale && amountPaid > 0
          ? _initialPaymentMethod
          : null,
      // Exactly what is sent, in cart order: the request's fingerprint.
      items: [
        for (final item in cart)
          SaleRequestItem(productId: item.product.id, quantity: item.quantity),
      ],
      estimatedTotal: estimatedTotal,
    );

    setState(() {
      _isProcessing = true;
    });

    try {
      final outcome = await ref
          .read(pendingSaleControllerProvider.notifier)
          .submit(draft);
      if (!mounted) return;
      await _handleOutcome(
        outcome,
        isCredit: isCreditSale,
        estimatedTotal: estimatedTotal,
      );
    } catch (_) {
      if (mounted) _showMessage(_unknownMessage);
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  // -----------------------------------------------------------------
  // Unconfirmed sales
  // -----------------------------------------------------------------

  static const _unknownMessage =
      "We couldn't confirm whether this sale was recorded. It is saved on "
      'this device: check it below before doing anything else, and do not '
      'charge the customer again.';

  bool get _isCheckoutLocked =>
      ref.read(pendingSaleControllerProvider).value?.blocksCheckout ?? true;

  /// A saved, unconfirmed sale found when New Sale opens is looked up once,
  /// automatically (a lookup never creates a sale).
  void _checkSavedSaleOnEntry(AsyncValue<PendingSaleState> value) {
    final state = value.value;
    if (_pendingChecked || state == null) return;
    _pendingChecked = true;
    if (state.phase == PendingSalePhase.pending) {
      Future.microtask(_lookUpPending);
    }
  }

  /// The unresolved sale, and any set-aside sale recorded after all.
  Widget? _pendingPanel() {
    final state = ref.watch(pendingSaleControllerProvider).value;
    final recordedLater = ref.watch(abandonedSalesProvider).value ?? const [];
    final panels = [
      for (final item in recordedLater)
        AbandonedSaleRecordedNotice(
          item: item,
          onOpenSale: () => context.go('/sales/${item.recorded.saleId}'),
          onAcknowledge: () => _acknowledgeAbandoned(item),
        ),
      if (state != null && state.blocksCheckout)
        PendingSalePanel(
          state: state,
          onLookUp: _lookUpPending,
          onRetry: _retryPending,
          onAbandon: _abandonPending,
          onReload: () =>
              ref.read(pendingSaleControllerProvider.notifier).reload(),
          onOpenSales: () => context.go('/sales'),
        ),
    ];
    if (panels.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < panels.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.md),
          panels[i],
        ],
      ],
    );
  }

  PendingSaleRequest? get _pendingRequest =>
      ref.read(pendingSaleControllerProvider).value?.pending;

  Future<void> _lookUpPending() async {
    final pending = _pendingRequest;
    if (pending == null) return;
    try {
      final outcome = await ref
          .read(pendingSaleControllerProvider.notifier)
          .lookUp();
      if (!mounted) return;
      await _handleOutcome(
        outcome,
        isCredit: pending.draft.kind == SaleRequestKind.credit,
        estimatedTotal: pending.draft.estimatedTotal,
      );
    } catch (_) {
      if (mounted) {
        _showMessage(
          "We couldn't check this sale right now. Check your connection "
          'and try again.',
        );
      }
    }
  }

  Future<void> _retryPending() async {
    final pending = _pendingRequest;
    if (pending == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Has the customer already paid?',
      message:
          'Only retry if the customer has already paid for this sale and is '
          'still waiting. ShopMate will send exactly the same sale again; if '
          'it was recorded meanwhile, you will get that sale, not a new one.',
      confirmLabel: 'Customer has paid: retry',
    );
    if (!confirmed || !mounted) return;
    try {
      final outcome = await ref
          .read(pendingSaleControllerProvider.notifier)
          .retry(customerConfirmedPaid: true);
      if (!mounted) return;
      await _handleOutcome(
        outcome,
        isCredit: pending.draft.kind == SaleRequestKind.credit,
        estimatedTotal: pending.draft.estimatedTotal,
      );
    } catch (_) {
      if (mounted) _showMessage(_unknownMessage);
    }
  }

  /// Sets the unresolved sale aside (the customer left or did not pay).
  /// It is kept on this device and checked again later: setting it aside
  /// cannot stop the original request from being recorded.
  Future<void> _abandonPending() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Set this sale aside?',
      message:
          'Only do this if the customer did not pay or has left. It does not '
          'cancel the sale: the request already sent may still be recorded. '
          'ShopMate keeps it on this device and keeps checking; if it is '
          'recorded, you will be told here. You can then start a new sale.',
      confirmLabel: 'Set aside',
      cancelLabel: 'Keep it',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final abandoned = await ref
        .read(pendingSaleControllerProvider.notifier)
        .abandon();
    if (mounted && !abandoned) {
      _showMessage(
        "The sale couldn't be set aside on this device, so it is still "
        'here. Please try again.',
      );
    }
  }

  Future<void> _acknowledgeAbandoned(AbandonedSaleRecorded item) async {
    final removed = await ref
        .read(abandonedSalesProvider.notifier)
        .acknowledge(item.abandoned.request.idempotencyKey);
    if (mounted && !removed) {
      _showMessage("This notice couldn't be cleared. Please try again.");
    }
  }

  /// One place for every result: new sales, retries and lookups.
  Future<void> _handleOutcome(
    SaleOutcome? outcome, {
    required bool isCredit,
    required double estimatedTotal,
  }) async {
    switch (outcome) {
      case null:
        return;
      case SaleOutcomeRecorded():
        await _finishRecorded(outcome, estimatedTotal: estimatedTotal);
      case SaleOutcomeRejected(:final error, requestKept: true):
        _showMessage(
          '${_rejectionMessage(error, isCredit: isCredit)} The first '
          'attempt may still be recorded, so this sale stays saved here.',
        );
      case SaleOutcomeRejected(:final error):
        _showMessage(_rejectionMessage(error, isCredit: isCredit));
      case SaleOutcomeUnknown():
        _showMessage(_unknownMessage);
      case SaleOutcomeNotFound():
        _showMessage(
          'No recorded sale was found for it yet. If the customer has paid '
          'and is waiting, you can retry this same sale.',
        );
      case SaleOutcomeLookupFailed():
        _showMessage(
          "We couldn't check this sale right now. Check your connection "
          'and try again.',
        );
      case SaleOutcomeBlocked():
        _showMessage('Resolve the unconfirmed sale above first.');
      case SaleOutcomeNotSaved():
        _showMessage(
          "This sale couldn't be prepared on this device, so nothing was "
          'sent. Try again; if it keeps failing, restart ShopMate.',
        );
    }
  }

  Future<void> _finishRecorded(
    SaleOutcomeRecorded outcome, {
    required double estimatedTotal,
  }) async {
    final recorded = outcome.recorded;

    ref.read(saleCartProvider.notifier).clearCart();
    _amountPaidController.clear();
    ref.invalidate(productsProvider);
    ref.invalidate(salesProductsProvider);
    ref.invalidate(salesProvider);
    ref.invalidate(customerCreditStatementProvider);

    final openRecorded = await _showRecordedSale(
      recorded,
      estimatedTotal: estimatedTotal,
      alreadyRecorded: outcome.alreadyRecorded,
      fromRecovery: outcome.fromRecovery,
    );

    if (mounted) {
      final id = recorded.saleId;
      context.go(switch (openRecorded) {
        true when recorded.hasDetails => '/sales/$id/receipt',
        true => '/sales/$id',
        _ => '/sales',
      });
    }
  }

  /// Shows what the database recorded: its total, discount and change,
  /// never the cart's estimate. Resolves true to open the sale.
  Future<bool?> _showRecordedSale(
    RecordedSale recorded, {
    required double estimatedTotal,
    required bool alreadyRecorded,
    required bool fromRecovery,
  }) {
    final sale = recorded.sale;

    return showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final textTheme = Theme.of(dialogContext).textTheme;
        final secondary = textTheme.bodyMedium?.copyWith(
          color: AppColors.textSecondary,
        );

        if (sale == null) {
          // Recorded, but the read-back failed: never submit it again.
          return AlertDialog(
            title: const Text('Sale Recorded'),
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
                  "The sale was recorded, but its details couldn't be "
                  'loaded. Open it from Sales to see the total, change and '
                  'receipt. Do not record it again.',
                  textAlign: TextAlign.center,
                  style: secondary,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Done'),
              ),
              FilledButton.icon(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                icon: const Icon(Icons.open_in_new_rounded),
                label: const Text('Open sale'),
              ),
            ],
          );
        }

        final adjusted =
            DiscountPricing.toCents(sale.totalAmount) !=
            DiscountPricing.toCents(estimatedTotal);

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
              if (alreadyRecorded || fromRecovery) ...[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  alreadyRecorded
                      ? 'This sale had already been recorded. Do not '
                            'collect payment again.'
                      : 'This sale is now recorded. The customer has '
                            'already paid: do not collect payment again.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              Text(
                'Total: ${formatGhs(sale.totalAmount)}',
                style: AppTypography.amount,
              ),
              if (sale.discountAmount > 0)
                Text(
                  'Discount: ${formatGhs(sale.discountAmount)}',
                  style: secondary,
                ),
              if (sale.changeAmount > 0)
                Text(
                  'Change: ${formatGhs(sale.changeAmount)}',
                  style: secondary,
                ),
              if (adjusted && !alreadyRecorded && !fromRecovery) ...[
                const SizedBox(height: AppSpacing.md),
                Text(
                  'The final total was adjusted at checkout (the estimate '
                  'was ${formatGhs(estimatedTotal)}). The amounts above are '
                  'what was recorded.',
                  textAlign: TextAlign.center,
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Done'),
            ),
            FilledButton.icon(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              icon: const Icon(Icons.receipt_long_outlined),
              label: const Text('View receipt'),
            ),
          ],
        );
      },
    );
  }

  /// A refused sale's message, chosen by the error's code.
  String _rejectionMessage(
    SaleRequestException error, {
    required bool isCredit,
  }) {
    return switch (error.kind) {
      SaleRequestErrorKind.discountRefused => _discountRefusedMessage,
      SaleRequestErrorKind.keyConflict =>
        "This sale's request key was already used for a different sale, so "
            'nothing was recorded. Check Sales, then start the sale again.',
      SaleRequestErrorKind.creditKeyConflict =>
        'This credit-sale request key was already used with different '
            'details. Review the sale and try again.',
      SaleRequestErrorKind.serviceUnavailable =>
        "Sales can't be recorded until ShopMate's database is updated. "
            'Nothing was recorded. Contact your ShopMate administrator.',
      SaleRequestErrorKind.outcomeUnknown => _unknownMessage,
      SaleRequestErrorKind.rejected =>
        isCredit
            ? _friendlySaleError(error.serverMessage ?? '')
            : error.serverMessage ??
                  'Unable to complete the sale. Please try again.',
    };
  }

  String _friendlySaleError(String message) {
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
    required this.pricing,
    required this.total,
    required this.amountPaid,
    required this.change,
    required this.paymentMethod,
    required this.initialPaymentMethod,
    required this.customerId,
    required this.isProcessing,
    required this.locked,
  });

  final List<CartItem> cart;
  final _CheckoutPricing pricing;

  /// The estimated total to pay, after any discount.
  final double total;
  final double amountPaid;
  final double change;
  final String paymentMethod;
  final String? initialPaymentMethod;
  final String? customerId;
  final bool isProcessing;

  /// An unconfirmed sale must be resolved before a new one starts.
  final bool locked;

  bool get isCredit => paymentMethod == 'credit';

  int get itemCount => cart.fold<int>(0, (sum, item) => sum + item.quantity);

  double get outstanding =>
      (total - amountPaid).clamp(0.0, double.infinity).toDouble();

  /// "Change GHS 5.00" or "Outstanding GHS 40.00", once there is something
  /// to say.
  String? get balanceCaption {
    if (cart.isEmpty) return null;
    if (isCredit) return 'Outstanding ${formatGhs(outstanding)}';
    if (change > 0) return 'Change ${formatGhs(change)}';
    return null;
  }
}

/// Whether the shop's discount could be taken into account.
enum _DiscountStatus { none, active, checking, unavailable }

/// The cart priced with the shop's discount, in whole cents, using the
/// database's rule. An estimate for the cashier: the server prices the sale
/// when it is recorded, and only its recorded totals count.
class _CheckoutPricing {
  const _CheckoutPricing._(
    this._previews, {
    required this.status,
    required this.subtotalCents,
    required this.discountCents,
    required this.anyLikelyRefused,
  });

  factory _CheckoutPricing.of(
    List<CartItem> cart, {
    required AsyncValue<DiscountSettings?> discounts,
    required DateTime now,
  }) {
    // Never promise a discount that couldn't be read.
    final settings = discounts.hasError ? null : discounts.value;
    final status = discounts.hasError
        ? _DiscountStatus.unavailable
        : !discounts.hasValue
        ? _DiscountStatus.checking
        : settings != null && settings.isActiveAt(now)
        ? _DiscountStatus.active
        : _DiscountStatus.none;

    final previews = <String, LineDiscountPreview>{};
    var subtotalCents = 0;
    var discountCents = 0;
    var anyLikelyRefused = false;
    for (final item in cart) {
      final preview = DiscountPricing.preview(
        item.product,
        settings: settings,
        now: now,
      );
      previews[item.product.id] = preview;
      subtotalCents += preview.originalCents * item.quantity;
      discountCents += preview.discountCents * item.quantity;
      anyLikelyRefused = anyLikelyRefused || preview.likelyRefused;
    }

    return _CheckoutPricing._(
      previews,
      status: status,
      subtotalCents: subtotalCents,
      discountCents: discountCents,
      anyLikelyRefused: anyLikelyRefused,
    );
  }

  final _DiscountStatus status;
  final Map<String, LineDiscountPreview> _previews;
  final int subtotalCents;
  final int discountCents;
  final bool anyLikelyRefused;

  int get totalCents => subtotalCents - discountCents;
  double get total => totalCents / 100;

  LineDiscountPreview previewFor(CartItem item) =>
      _previews[item.product.id] ??
      LineDiscountPreview.none(
        DiscountPricing.toCents(item.product.sellingPrice),
      );
}

/// Subtotal and discount when one applies, and what the cashier should know
/// about the estimate. Nothing at all for an ordinary sale.
class _DiscountBreakdown extends StatelessWidget {
  const _DiscountBreakdown({required this.pricing});

  final _CheckoutPricing pricing;

  @override
  Widget build(BuildContext context) {
    final note = switch (pricing.status) {
      _DiscountStatus.unavailable =>
        "Discounts couldn't be checked, so normal prices are shown. The "
            'final total is confirmed when the sale is recorded.',
      _DiscountStatus.checking => 'Checking discounts...',
      _DiscountStatus.active when pricing.discountCents > 0 =>
        'Estimated with the current discount. The final total is confirmed '
            'when the sale is recorded.',
      _ => null,
    };
    final hasDiscount = pricing.discountCents > 0;
    if (note == null && !hasDiscount && !pricing.anyLikelyRefused) {
      return const SizedBox.shrink();
    }

    final small = Theme.of(context).textTheme.bodySmall;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasDiscount) ...[
          SummaryLine(
            label: 'Subtotal',
            value: formatGhs(pricing.subtotalCents / 100),
          ),
          const SizedBox(height: AppSpacing.xs),
          SummaryLine(
            label: 'Discount',
            value: '-${formatGhs(pricing.discountCents / 100)}',
            valueColor: AppColors.success,
          ),
          const SizedBox(height: AppSpacing.xs),
        ],
        if (note != null)
          Text(note, style: small?.copyWith(color: AppColors.textSecondary)),
        if (pricing.anyLikelyRefused)
          Text(
            "A product in this sale can't get the current discount; the sale "
            'may be refused.',
            style: small?.copyWith(color: AppColors.danger),
          ),
      ],
    );
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
  const _CartLine({
    required this.item,
    required this.preview,
    required this.enabled,
  });

  /// False while an unconfirmed sale blocks changes.
  final bool enabled;

  final CartItem item;

  /// The expected price under the shop's discount (no cost is shown).
  final LineDiscountPreview preview;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(saleCartProvider.notifier);
    final textTheme = Theme.of(context).textTheme;
    final atStockLimit = item.quantity >= item.product.stockQuantity;
    final unitPrice = preview.isDiscounted
        ? '${formatGhs(preview.finalCents / 100)} each · was '
              '${formatGhs(preview.originalCents / 100)}, '
              '${preview.percentageLabel} off'
        : '${formatGhs(item.product.sellingPrice)} each';

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
              Text(
                formatGhs(preview.finalCents * item.quantity / 100),
                style: AppTypography.amount,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: Text(
                  atStockLimit
                      ? '$unitPrice · all ${item.product.stockQuantity} in '
                            'stock'
                      : unitPrice,
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
                onDecrease: enabled
                    ? () => notifier.decreaseQuantity(item.product.id)
                    : null,
                onIncrease: atStockLimit || !enabled
                    ? null
                    : () => notifier.increaseQuantity(item.product.id),
              ),
              IconButton(
                tooltip: 'Remove ${item.product.name}',
                onPressed: enabled
                    ? () => notifier.removeProduct(item.product.id)
                    : null,
                color: AppColors.textMuted,
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
              ),
            ],
          ),
          if (preview.likelyRefused)
            Text(
              "The current discount can't be applied to this product, so "
              'the sale may be refused. Remove it or ask the shop owner.',
              style: textTheme.bodySmall?.copyWith(color: AppColors.danger),
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
    final enabled = !checkout.isProcessing && !checkout.locked;

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
        if (checkout.cart.isNotEmpty) ...[
          _DiscountBreakdown(pricing: checkout.pricing),
          const SizedBox(height: AppSpacing.sm),
        ],
        SummaryLine(
          label: 'Total',
          value: formatGhs(checkout.total),
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
      onPressed:
          checkout.cart.isEmpty || checkout.isProcessing || checkout.locked
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
