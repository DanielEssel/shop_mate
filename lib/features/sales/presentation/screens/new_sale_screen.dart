import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../products/domain/entities/product.dart';
import '../../domain/entities/cart_item.dart';
import '../providers/sales_provider.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../../../customers/presentation/providers/customers_provider.dart';
import '../../../customers/domain/entities/customer.dart';

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
  String? _customerId;
  bool _isProcessing = false;

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

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'New Sale',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              tooltip: 'Clear cart',
              onPressed: cartNotifier.clearCart,
              icon: const Icon(Icons.delete_sweep_rounded),
            ),
        ],
      ),
      body: productsAsync.when(
        loading: () {
          return const Center(child: CircularProgressIndicator());
        },
        error: (error, stackTrace) {
          return _ErrorState(
            message: 'Unable to load products.\n$error',
            onRetry: () {
              ref.invalidate(salesProductsProvider);
            },
          );
        },
        data: (products) {
          return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 1000;

              if (isDesktop) {
                return _DesktopSaleLayout(
                  products: products,
                  searchController: _searchController,
                  searchQuery: _searchQuery,
                  cart: cart,
                  subtotal: subtotal,
                  paymentMethod: _paymentMethod,
                  amountPaid: amountPaid,
                  change: change,
                  amountPaidController: _amountPaidController,
                  isProcessing: _isProcessing,
                  customers: customersAsync.value ?? const [],
                  customerId: _customerId,
                  onCustomerChanged: (value) {
                    setState(() {
                      _customerId = value;
                    });
                  },
                  onSearchChanged: (value) {
                    setState(() {
                      _searchQuery = value;
                    });
                  },
                  onAddProduct: cartNotifier.addProduct,
                  onPaymentChanged: _changePaymentMethod,
                  onAmountChanged: (_) {
                    setState(() {});
                  },
                  onCompleteSale: () {
                    _completeSale(
                      cart: cart,
                      subtotal: subtotal,
                      customerId: _customerId,
                    );
                  },
                );
              }

              return _MobileSaleLayout(
                products: products,
                searchController: _searchController,
                searchQuery: _searchQuery,
                cart: cart,
                subtotal: subtotal,
                paymentMethod: _paymentMethod,
                amountPaid: amountPaid,
                change: change,
                amountPaidController: _amountPaidController,
                isProcessing: _isProcessing,
                customers: customersAsync.value ?? const [],
                customerId: _customerId,
                onCustomerChanged: (value) {
                  setState(() {
                    _customerId = value;
                  });
                },
                onSearchChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                onAddProduct: cartNotifier.addProduct,
                onPaymentChanged: _changePaymentMethod,
                onAmountChanged: (_) {
                  setState(() {});
                },
                onCompleteSale: () {
                  _completeSale(
                    cart: cart,
                    subtotal: subtotal,
                    customerId: _customerId,
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  void _changePaymentMethod(String value) {
    setState(() {
      _paymentMethod = value;

      if (value == 'credit') {
        _amountPaidController.clear();
      }
    });
  }

  Future<void> _completeSale({
    required List<CartItem> cart,
    required double subtotal,
    String? customerId,
  }) async {
    if (cart.isEmpty) {
      _showMessage('Add at least one product.');
      return;
    }

    final amountPaid = double.tryParse(_amountPaidController.text) ?? 0;

    if (_paymentMethod != 'credit' && amountPaid < subtotal) {
      _showMessage('Amount paid cannot be less than the total.');
      return;
    }

    if (_paymentMethod == 'credit' && customerId == null) {
      _showMessage('Please select a customer for a credit sale.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final items = cart.map((item) {
        return {'product_id': item.product.id, 'quantity': item.quantity};
      }).toList();

      final sale = await ref
          .read(createSaleProvider)
          .call(
            customerId: customerId,
            items: items,
            paymentMethod: _paymentMethod,
            amountPaid: _paymentMethod == 'credit' ? 0 : amountPaid,
          );

      ref.read(saleCartProvider.notifier).clearCart();

      ref.invalidate(productsProvider);
      ref.invalidate(salesProductsProvider);
      ref.invalidate(salesProvider);

      if (!mounted) return;

      await showDialog<void>(
        context: context,
        builder: (dialogContext) {
          return AlertDialog(
            title: const Text('Sale Completed'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: Color(0xFF087F5B),
                ),
                const SizedBox(height: 16),
                Text(
                  sale.saleNumber,
                  style: Theme.of(
                    dialogContext,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 12),
                Text('Total: GHS ${sale.totalAmount.toStringAsFixed(2)}'),
                if (sale.changeAmount > 0)
                  Text('Change: GHS ${sale.changeAmount.toStringAsFixed(2)}'),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                },
                child: const Text('Done'),
              ),
            ],
          );
        },
      );

      if (mounted) {
        context.go('/sales');
      }
    } catch (error) {
      if (!mounted) return;

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }
}

// =============================================================
// MOBILE LAYOUT
// =============================================================

class _MobileSaleLayout extends StatelessWidget {
  const _MobileSaleLayout({
    required this.products,
    required this.searchController,
    required this.searchQuery,
    required this.cart,
    required this.subtotal,
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
    required this.amountPaidController,
    required this.isProcessing,
    required this.onSearchChanged,
    required this.onAddProduct,
    required this.onPaymentChanged,
    required this.onAmountChanged,
    required this.onCompleteSale,
    required this.customers,
    required this.customerId,
    required this.onCustomerChanged,
  });

  final List<Product> products;
  final TextEditingController searchController;
  final String searchQuery;
  final List<CartItem> cart;
  final double subtotal;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  final TextEditingController amountPaidController;
  final bool isProcessing;

  final List<Customer> customers;
  final String? customerId;
  final ValueChanged<String?> onCustomerChanged;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Product> onAddProduct;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCompleteSale;

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filterProducts();

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(
              title: 'Customer',
              subtitle: 'Optional — select a customer for this sale',
            ),
            const SizedBox(height: 12),
            _CustomerSelector(
              customers: customers,
              value: customerId,
              onChanged: onCustomerChanged,
            ),
            const SizedBox(height: 24),
            _SectionTitle(
              title: 'Products',
              subtitle: 'Select products to add to this sale',
            ),
            const SizedBox(height: 12),
            _SearchField(
              controller: searchController,
              query: searchQuery,
              onChanged: onSearchChanged,
            ),
            const SizedBox(height: 16),
            if (filteredProducts.isEmpty)
              const _EmptyProducts()
            else
              _MobileProductGrid(
                products: filteredProducts,
                onAddProduct: onAddProduct,
              ),
            const SizedBox(height: 24),
            _MobileCartSection(
              cart: cart,
              subtotal: subtotal,
              paymentMethod: paymentMethod,
              amountPaid: amountPaid,
              change: change,
              amountPaidController: amountPaidController,
              isProcessing: isProcessing,
              onPaymentChanged: onPaymentChanged,
              onAmountChanged: onAmountChanged,
              onCompleteSale: onCompleteSale,
            ),
          ],
        ),
      ),
    );
  }

  List<Product> _filterProducts() {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false) ||
          (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
}

// =============================================================
// DESKTOP LAYOUT
// =============================================================

class _DesktopSaleLayout extends StatelessWidget {
  const _DesktopSaleLayout({
    required this.products,
    required this.searchController,
    required this.searchQuery,
    required this.cart,
    required this.subtotal,
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
    required this.amountPaidController,
    required this.isProcessing,
    required this.customers,
    required this.customerId,
    required this.onCustomerChanged,
    required this.onSearchChanged,
    required this.onAddProduct,
    required this.onPaymentChanged,
    required this.onAmountChanged,
    required this.onCompleteSale,
  });

  final List<Product> products;
  final TextEditingController searchController;
  final String searchQuery;
  final List<CartItem> cart;
  final double subtotal;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  final TextEditingController amountPaidController;
  final bool isProcessing;

  final List<Customer> customers;
  final String? customerId;
  final ValueChanged<String?> onCustomerChanged;

  final ValueChanged<String> onSearchChanged;
  final ValueChanged<Product> onAddProduct;
  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCompleteSale;

  @override
  Widget build(BuildContext context) {
    final filteredProducts = _filterProducts();

    return Row(
      children: [
        Expanded(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _SectionTitle(
                      title: 'Customer',
                      subtitle: 'Optional — select a customer for this sale',
                    ),
                    const SizedBox(height: 12),
                    _CustomerSelector(
                      customers: customers,
                      value: customerId,
                      onChanged: onCustomerChanged,
                    ),
                    const SizedBox(height: 12),
                    _SearchField(
                      controller: searchController,
                      query: searchQuery,
                      onChanged: onSearchChanged,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filteredProducts.isEmpty
                    ? const _EmptyProducts()
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        gridDelegate:
                            const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 220,
                              mainAxisExtent: 190,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                        itemCount: filteredProducts.length,
                        itemBuilder: (context, index) {
                          final product = filteredProducts[index];

                          return _ProductTile(
                            product: product,
                            onAdd: () {
                              onAddProduct(product);
                            },
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
        const VerticalDivider(width: 1),
        SizedBox(
          width: 390,
          child: _DesktopCartSection(
            cart: cart,
            subtotal: subtotal,
            paymentMethod: paymentMethod,
            amountPaid: amountPaid,
            change: change,
            amountPaidController: amountPaidController,
            isProcessing: isProcessing,
            onPaymentChanged: onPaymentChanged,
            onAmountChanged: onAmountChanged,
            onCompleteSale: onCompleteSale,
          ),
        ),
      ],
    );
  }

  List<Product> _filterProducts() {
    final query = searchQuery.trim().toLowerCase();

    if (query.isEmpty) {
      return products;
    }

    return products.where((product) {
      return product.name.toLowerCase().contains(query) ||
          product.category.toLowerCase().contains(query) ||
          (product.sku?.toLowerCase().contains(query) ?? false) ||
          (product.barcode?.toLowerCase().contains(query) ?? false);
    }).toList();
  }
}

// =============================================================
// SEARCH
// =============================================================

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.query,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String query;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'Search products...',
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: query.isNotEmpty
            ? IconButton(
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
                icon: const Icon(Icons.clear_rounded),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          vertical: 16,
          horizontal: 16,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

// =============================================================
// MOBILE PRODUCT GRID
// =============================================================

class _MobileProductGrid extends StatelessWidget {
  const _MobileProductGrid({
    required this.products,
    required this.onAddProduct,
  });

  final List<Product> products;
  final ValueChanged<Product> onAddProduct;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: products.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 190,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final product = products[index];

        return _ProductTile(
          product: product,
          onAdd: () {
            onAddProduct(product);
          },
        );
      },
    );
  }
}

// =============================================================
// PRODUCT TILE
// =============================================================

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product, required this.onAdd});

  final Product product;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final outOfStock = product.stockQuantity <= 0;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: outOfStock ? null : onAdd,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0F3F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: product.imageUrl != null
                      ? Image.network(
                          product.imageUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return const Icon(
                              Icons.inventory_2_rounded,
                              size: 36,
                            );
                          },
                        )
                      : const Center(
                          child: Icon(Icons.inventory_2_rounded, size: 36),
                        ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                product.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'GHS ${product.sellingPrice.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    outOfStock ? 'Out' : '${product.stockQuantity}',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: outOfStock ? Colors.red : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================
// MOBILE CART
// =============================================================

class _MobileCartSection extends StatelessWidget {
  const _MobileCartSection({
    required this.cart,
    required this.subtotal,
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
    required this.amountPaidController,
    required this.isProcessing,
    required this.onPaymentChanged,
    required this.onAmountChanged,
    required this.onCompleteSale,
  });

  final List<CartItem> cart;
  final double subtotal;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  final TextEditingController amountPaidController;
  final bool isProcessing;

  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCompleteSale;

  @override
  Widget build(BuildContext context) {
    return _SaleCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle(
            title: 'Current Sale',
            subtitle: 'Review your items and payment',
          ),
          const SizedBox(height: 16),
          if (cart.isEmpty)
            const _EmptyCart()
          else ...[
            for (final item in cart)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _CartRow(item: item),
              ),
          ],
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),
          _TotalRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 16),
          _PaymentSelector(value: paymentMethod, onChanged: onPaymentChanged),
          if (paymentMethod != 'credit') ...[
            const SizedBox(height: 12),
            TextField(
              controller: amountPaidController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: onAmountChanged,
              decoration: const InputDecoration(
                labelText: 'Amount paid',
                prefixText: 'GHS ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            _TotalRow(label: 'Change', value: change),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed: cart.isEmpty || isProcessing ? null : onCompleteSale,
              icon: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(isProcessing ? 'Processing...' : 'Complete Sale'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// DESKTOP CART
// =============================================================

class _DesktopCartSection extends StatelessWidget {
  const _DesktopCartSection({
    required this.cart,
    required this.subtotal,
    required this.paymentMethod,
    required this.amountPaid,
    required this.change,
    required this.amountPaidController,
    required this.isProcessing,
    required this.onPaymentChanged,
    required this.onAmountChanged,
    required this.onCompleteSale,
  });

  final List<CartItem> cart;
  final double subtotal;
  final String paymentMethod;
  final double amountPaid;
  final double change;
  final TextEditingController amountPaidController;
  final bool isProcessing;

  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onCompleteSale;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const _SectionTitle(
            title: 'Current Sale',
            subtitle: 'Review your items and payment',
          ),
          const SizedBox(height: 12),
          Expanded(
            child: cart.isEmpty
                ? const _EmptyCart()
                : ListView.separated(
                    itemCount: cart.length,
                    separatorBuilder: (_, index) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      return _CartRow(item: cart[index]);
                    },
                  ),
          ),
          const Divider(),
          _TotalRow(label: 'Subtotal', value: subtotal),
          const SizedBox(height: 12),
          _PaymentSelector(value: paymentMethod, onChanged: onPaymentChanged),
          if (paymentMethod != 'credit') ...[
            const SizedBox(height: 12),
            TextField(
              controller: amountPaidController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: onAmountChanged,
              decoration: const InputDecoration(
                labelText: 'Amount paid',
                prefixText: 'GHS ',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            _TotalRow(label: 'Change', value: change),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: cart.isEmpty || isProcessing ? null : onCompleteSale,
              icon: isProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check_circle_outline_rounded),
              label: Text(isProcessing ? 'Processing...' : 'Complete Sale'),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// CART ROW
// =============================================================

class _CartRow extends ConsumerWidget {
  const _CartRow({required this.item});

  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(saleCartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'GHS ${item.product.sellingPrice.toStringAsFixed(2)} each',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              notifier.decreaseQuantity(item.product.id);
            },
            icon: const Icon(Icons.remove_circle_outline, size: 21),
          ),
          Text(
            '${item.quantity}',
            style: const TextStyle(fontWeight: FontWeight.w800),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              notifier.increaseQuantity(item.product.id);
            },
            icon: const Icon(Icons.add_circle_outline, size: 21),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: () {
              notifier.removeProduct(item.product.id);
            },
            icon: const Icon(Icons.delete_outline_rounded, size: 21),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// PAYMENT SELECTOR
// =============================================================

class _PaymentSelector extends StatelessWidget {
  const _PaymentSelector({required this.value, required this.onChanged});

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Payment method',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'cash', child: Text('Cash')),
        DropdownMenuItem(value: 'mobile_money', child: Text('Mobile Money')),
        DropdownMenuItem(value: 'card', child: Text('Card')),
        DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
        DropdownMenuItem(value: 'credit', child: Text('Credit')),
      ],
      onChanged: (value) {
        if (value != null) {
          onChanged(value);
        }
      },
    );
  }
}

// =============================================================
// SECTION TITLE
// =============================================================

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 3),
        Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
        ),
      ],
    );
  }
}

// =============================================================
// SALE CARD
// =============================================================

class _SaleCard extends StatelessWidget {
  const _SaleCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: child,
    );
  }
}

// =============================================================
// TOTAL ROW
// =============================================================

class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.label, required this.value});

  final String label;
  final double value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Text(
          'GHS ${value.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

// =============================================================
// EMPTY CART
// =============================================================

class _EmptyCart extends StatelessWidget {
  const _EmptyCart();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      child: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 42),
          SizedBox(height: 10),
          Text(
            'Your cart is empty',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('Add products to start a sale.', textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

// =============================================================
// EMPTY PRODUCTS
// =============================================================

class _EmptyProducts extends StatelessWidget {
  const _EmptyProducts();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: const Column(
        children: [
          Icon(Icons.inventory_2_outlined, size: 48),
          SizedBox(height: 12),
          Text(
            'No products found',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          SizedBox(height: 4),
          Text('Try another search term.'),
        ],
      ),
    );
  }
}

// =============================================================
// ERROR STATE
// =============================================================

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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

class _CustomerSelector extends StatelessWidget {
  const _CustomerSelector({
    required this.customers,
    required this.value,
    required this.onChanged,
  });

  final List<Customer> customers;
  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String?>(
      initialValue: value,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Customer',
        hintText: 'Select customer',
        border: OutlineInputBorder(),
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
              overflow: TextOverflow.ellipsis,
            ),
          );
        }),
      ],
      onChanged: onChanged,
    );
  }
}
