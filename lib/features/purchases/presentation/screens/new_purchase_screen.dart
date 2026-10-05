import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/purchase_cart_item.dart';
import '../providers/purchases_provider.dart';
import '../../../products/domain/entities/product.dart';
import '../../../suppliers/domain/entities/supplier.dart';
import '../../../suppliers/presentation/providers/supplier_providers.dart';

class NewPurchaseScreen extends ConsumerStatefulWidget {
  const NewPurchaseScreen({super.key});

  @override
  ConsumerState<NewPurchaseScreen> createState() =>
      _NewPurchaseScreenState();
}

class _NewPurchaseScreenState
    extends ConsumerState<NewPurchaseScreen> {
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

  @override
  void dispose() {
    _supplierNameController.dispose();
    _supplierPhoneController.dispose();
    _amountPaidController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _amountPaid() {
    return double.tryParse(
          _amountPaidController.text.trim(),
        ) ??
        0;
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
    final cartNotifier =
        ref.read(purchaseCartProvider.notifier);

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (cart.isEmpty) {
      _showMessage(
        'Please add at least one product.',
        isError: true,
      );
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
            supplierName:
                supplierName.trim().isEmpty
                    ? null
                    : supplierName.trim(),
            supplierPhone:
                supplierPhone.trim().isEmpty
                    ? null
                    : supplierPhone.trim(),
            paymentMethod: _paymentMethod,
            amountPaid: amountPaid,
            purchaseDate: _purchaseDate,
            notes:
                _notesController.text.trim().isEmpty
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

      _showMessage(
        'Purchase ${purchase.purchaseNumber} created successfully.',
      );

      context.pushReplacement('/purchases/${purchase.id}');
    } catch (error) {
      if (!mounted) {
        return;
      }

      if (_selectedSupplier != null &&
          _isUnavailableSupplierError(error)) {
        _clearSupplier();
        ref.invalidate(suppliersProvider);
        _showMessage(
          'This supplier is no longer active. Please select another supplier.',
          isError: true,
        );
        return;
      }

      _showMessage(
        'Unable to create purchase: $error',
        isError: true,
      );
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

  void _showMessage(
    String message, {
    bool isError = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
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
    final productsAsync =
        ref.watch(purchaseProductsProvider);

    final cart = ref.watch(purchaseCartProvider);
    final cartNotifier =
        ref.read(purchaseCartProvider.notifier);

    final total = cartNotifier.total;
    final amountPaid = _amountPaid();
    final balance = _balance(total);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'New Purchase',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          if (cart.isNotEmpty)
            IconButton(
              tooltip: 'Clear cart',
              onPressed: _isSaving
                  ? null
                  : () {
                      _showClearCartDialog();
                    },
              icon: const Icon(
                Icons.delete_sweep_outlined,
              ),
            ),
        ],
      ),
      body: productsAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _ErrorState(
            error: error,
            onRetry: () {
              ref.invalidate(
                purchaseProductsProvider,
              );
            },
          );
        },
        data: (List<Product> products) {
          return Form(
            key: _formKey,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide =
                    constraints.maxWidth >= 900;

                if (isWide) {
                  return Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(
                            20,
                            20,
                            10,
                            120,
                          ),
                          child: _PurchaseForm(
                            products: products,
                            cart: cart,
                            supplierNameController:
                                _supplierNameController,
                            supplierPhoneController:
                                _supplierPhoneController,
                            supplierPicker: _supplierPicker(),
                            supplierLocked:
                                _selectedSupplier != null,
                            notesController:
                                _notesController,
                            purchaseDate: _purchaseDate,
                            onDateSelected:
                                _selectDate,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 4,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(
                            10,
                            20,
                            20,
                            20,
                          ),
                          child: _PurchaseSummary(
                            cart: cart,
                            total: total,
                            amountPaidController:
                                _amountPaidController,
                            amountPaid: amountPaid,
                            balance: balance,
                            paymentMethod:
                                _paymentMethod,
                            isSaving: _isSaving,
                            onPaymentChanged: (value) {
                              setState(() {
                                _paymentMethod = value;
                              });
                            },
                            onAmountChanged: (_) {
                              setState(() {});
                            },
                            onComplete:
                                _completePurchase,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                return SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    120,
                  ),
                  child: Column(
                    children: [
                      _PurchaseForm(
                        products: products,
                        cart: cart,
                        supplierNameController:
                            _supplierNameController,
                        supplierPhoneController:
                            _supplierPhoneController,
                        supplierPicker: _supplierPicker(),
                        supplierLocked:
                            _selectedSupplier != null,
                        notesController:
                            _notesController,
                        purchaseDate: _purchaseDate,
                        onDateSelected: _selectDate,
                      ),
                      const SizedBox(height: 16),
                      _PurchaseSummary(
                        cart: cart,
                        total: total,
                        amountPaidController:
                            _amountPaidController,
                        amountPaid: amountPaid,
                        balance: balance,
                        paymentMethod:
                            _paymentMethod,
                        isSaving: _isSaving,
                        onPaymentChanged: (value) {
                          setState(() {
                            _paymentMethod = value;
                          });
                        },
                        onAmountChanged: (_) {
                          setState(() {});
                        },
                        onComplete:
                            _completePurchase,
                      ),
                    ],
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Future<void> _showClearCartDialog() async {
    final shouldClear =
        await showDialog<bool>(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: const Text('Clear purchase?'),
              content: const Text(
                'All products currently added to this purchase will be removed.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context, false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context, true);
                  },
                  child: const Text('Clear'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (shouldClear) {
      ref
          .read(purchaseCartProvider.notifier)
          .clearCart();
    }
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

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SectionCard(
          title: 'Supplier Information',
          subtitle:
              'Add supplier details for this purchase',
          icon: Icons.business_outlined,
          child: Column(
            children: [
              supplierPicker,
              const SizedBox(height: 14),
              TextFormField(
                controller: supplierNameController,
                readOnly: supplierLocked,
                textCapitalization:
                    TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Supplier name',
                  hintText: supplierLocked
                      ? null
                      : 'e.g. ABC Distributors',
                  helperText: supplierLocked
                      ? 'From the selected saved supplier'
                      : null,
                  prefixIcon: const Icon(
                    Icons.storefront_outlined,
                  ),
                  suffixIcon: supplierLocked
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: supplierPhoneController,
                readOnly: supplierLocked,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: 'Supplier phone',
                  hintText: supplierLocked
                      ? 'No phone saved'
                      : 'e.g. 0240000000',
                  prefixIcon: const Icon(
                    Icons.phone_outlined,
                  ),
                  suffixIcon: supplierLocked
                      ? const Icon(
                          Icons.lock_outline_rounded,
                          size: 18,
                        )
                      : null,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Purchase Details',
          subtitle:
              'Select products and enter purchase costs',
          icon: Icons.inventory_2_outlined,
          child: Column(
            children: [
              _PurchaseProductSearch(
                products: products,
              ),
              const SizedBox(height: 16),
              if (cart.isEmpty)
                const _EmptyPurchaseCart()
              else
                Column(
                  children: [
                    for (final item in cart)
                      Padding(
                        padding:
                            const EdgeInsets.only(
                          bottom: 10,
                        ),
                        child: _PurchaseCartRow(
                          item: item,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _SectionCard(
          title: 'Purchase Date & Notes',
          subtitle:
              'Add any additional information',
          icon: Icons.calendar_today_outlined,
          child: Column(
            children: [
              InkWell(
                onTap: onDateSelected,
                borderRadius:
                    BorderRadius.circular(14),
                child: InputDecorator(
                  decoration:
                      const InputDecoration(
                    labelText: 'Purchase date',
                    prefixIcon: Icon(
                      Icons.calendar_month_outlined,
                    ),
                  ),
                  child: Text(
                    _formatDate(purchaseDate),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: notesController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Notes',
                  hintText:
                      'Optional purchase notes...',
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
  const _PurchaseProductSearch({
    required this.products,
  });

  final List<Product> products;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(purchaseCartProvider.notifier);

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

      fieldViewBuilder: (
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

      optionsViewBuilder: (
        BuildContext context,
        AutocompleteOnSelected<Product> onSelected,
        Iterable<Product> options,
      ) {
        return Align(
          alignment: Alignment.topLeft,
          child: Material(
            elevation: 8,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxHeight: 300,
                minWidth: 320,
              ),
              child: ListView.builder(
                padding: EdgeInsets.zero,
                shrinkWrap: true,
                itemCount: options.length,
                itemBuilder: (context, index) {
                  final Product product = options.elementAt(index);

                  return InkWell(
                    onTap: () => onSelected(product),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: const Color(0xFFE8F5F0),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.inventory_2_outlined,
                              color: Color(0xFF087F5B),
                            ),
                          ),
                          const SizedBox(width: 12),

                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  product.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Current stock: ${product.stockQuantity}',
                                  style: TextStyle(
                                    color: Colors.grey.shade600,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 8),

                          Text(
                            'GHS ${product.costPrice.toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

// =============================================================
// PURCHASE CART ROW
// =============================================================

class _PurchaseCartRow extends ConsumerWidget {
  const _PurchaseCartRow({
    required this.item,
  });

  final PurchaseCartItem item;

  @override
  Widget build(
    BuildContext context,
    WidgetRef ref,
  ) {
    final notifier =
        ref.read(purchaseCartProvider.notifier);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius:
            BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.product.name,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),
                    const SizedBox(
                      height: 4,
                    ),
                    Text(
                      'Subtotal: GHS ${item.subtotal.toStringAsFixed(2)}',
                      style: TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () {
                  notifier.removeProduct(
                    item.product.id,
                  );
                },
                icon: const Icon(
                  Icons.delete_outline_rounded,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue:
                      item.unitCost
                          .toStringAsFixed(2),
                  keyboardType:
                      const TextInputType
                          .numberWithOptions(
                    decimal: true,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText: 'Unit cost',
                    prefixText: 'GHS ',
                    isDense: true,
                  ),
                  onChanged: (value) {
                    final cost =
                        double.tryParse(
                          value.trim(),
                        );

                    if (cost != null) {
                      notifier.updateUnitCost(
                        item.product.id,
                        cost,
                      );
                    }
                  },
                ),
              ),
              const SizedBox(width: 10),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade300,
                  ),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    IconButton(
                      visualDensity:
                          VisualDensity.compact,
                      onPressed: () {
                        notifier.decreaseQuantity(
                          item.product.id,
                        );
                      },
                      icon: const Icon(
                        Icons.remove_rounded,
                      ),
                    ),
                    SizedBox(
                      width: 34,
                      child: Center(
                        child: Text(
                          '${item.quantity}',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      visualDensity:
                          VisualDensity.compact,
                      onPressed: () {
                        notifier.increaseQuantity(
                          item.product.id,
                        );
                      },
                      icon: const Icon(
                        Icons.add_rounded,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// =============================================================
// SUMMARY
// =============================================================

class _PurchaseSummary extends StatelessWidget {
  const _PurchaseSummary({
    required this.cart,
    required this.total,
    required this.amountPaidController,
    required this.amountPaid,
    required this.balance,
    required this.paymentMethod,
    required this.isSaving,
    required this.onPaymentChanged,
    required this.onAmountChanged,
    required this.onComplete,
  });

  final List<PurchaseCartItem> cart;
  final double total;

  final TextEditingController amountPaidController;

  final double amountPaid;
  final double balance;

  final String paymentMethod;
  final bool isSaving;

  final ValueChanged<String> onPaymentChanged;
  final ValueChanged<String> onAmountChanged;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      title: 'Purchase Summary',
      subtitle:
          'Review payment before completing',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _SummaryRow(
            label: 'Items',
            value: '${cart.length}',
          ),
          const SizedBox(height: 10),
          _SummaryRow(
            label: 'Total quantity',
            value: '${cart.fold<int>(
              0,
              (sum, item) => sum + item.quantity,
            )}',
          ),
          const Divider(height: 28),
          _SummaryRow(
            label: 'Total',
            value:
                'GHS ${total.toStringAsFixed(2)}',
            large: true,
          ),
          const SizedBox(height: 18),
          DropdownButtonFormField<String>(
            initialValue: paymentMethod,
            isExpanded: true,
            decoration:
                const InputDecoration(
              labelText: 'Payment method',
              prefixIcon: Icon(
                Icons.payments_outlined,
              ),
            ),
            items: const [
              DropdownMenuItem(
                value: 'cash',
                child: Text('Cash'),
              ),
              DropdownMenuItem(
                value: 'mobile_money',
                child: Text('Mobile Money'),
              ),
              DropdownMenuItem(
                value: 'card',
                child: Text('Card'),
              ),
              DropdownMenuItem(
                value: 'bank_transfer',
                child: Text('Bank Transfer'),
              ),
              DropdownMenuItem(
                value: 'credit',
                child: Text('Credit'),
              ),
            ],
            onChanged: (value) {
              if (value != null) {
                onPaymentChanged(value);
              }
            },
          ),
          const SizedBox(height: 14),
          TextField(
            controller: amountPaidController,
            keyboardType:
                const TextInputType
                    .numberWithOptions(
              decimal: true,
            ),
            onChanged: onAmountChanged,
            decoration:
                const InputDecoration(
              labelText: 'Amount paid',
              prefixText: 'GHS ',
              prefixIcon: Icon(
                Icons.account_balance_wallet_outlined,
              ),
            ),
          ),
          const SizedBox(height: 14),
          _SummaryRow(
            label: 'Balance',
            value:
                'GHS ${balance.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed:
                  isSaving ? null : onComplete,
              icon: isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.check_circle_outline_rounded,
                    ),
              label: Text(
                isSaving
                    ? 'Saving Purchase...'
                    : 'Complete Purchase',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// SECTION CARD
// =============================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(alpha: 0.035),
            blurRadius: 16,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color:
                      const Color(0xFFE8F5F0),
                  borderRadius:
                      BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color:
                      const Color(0xFF087F5B),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors
                            .grey
                            .shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

// =============================================================
// SUMMARY ROW
// =============================================================

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.large = false,
  });

  final String label;
  final String value;
  final bool large;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: large ? 15 : 13,
              fontWeight:
                  large
                      ? FontWeight.w700
                      : FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: large ? 20 : 14,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

// =============================================================
// EMPTY CART
// =============================================================

class _EmptyPurchaseCart extends StatelessWidget {
  const _EmptyPurchaseCart();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 28,
      ),
      child: Column(
        children: [
          Icon(
            Icons.shopping_cart_outlined,
            size: 42,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 10),
          const Text(
            'No products added',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Search above to add products.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================
// ERROR STATE
// =============================================================

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 50,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load products',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
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

// =============================================================
// DATE FORMATTER
// =============================================================

String _formatDate(DateTime date) {
  final day =
      date.day.toString().padLeft(2, '0');
  final month =
      date.month.toString().padLeft(2, '0');

  return '$day/$month/${date.year}';
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
          color: Colors.red,
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
            icon: Icon(Icons.info_outline_rounded, size: 18),
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
              onSelected(
                options.firstWhere((supplier) => supplier.id == id),
              );
            }
          : null,
    );
  }
}

class _PickerMessage extends StatelessWidget {
  const _PickerMessage({
    required this.icon,
    required this.text,
    this.action,
  });

  final Widget icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}
