import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../providers/inventory_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({
    super.key,
    this.product,
  });

  final Product? product;

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState(

        
      );
}



class _StockAdjustmentScreenState
    extends ConsumerState<StockAdjustmentScreen> {
  final _quantityController = TextEditingController();
  final _noteController = TextEditingController();

  String? _selectedProductId;
  String _direction = 'increase';
  bool _isProcessing = false;

Product? _getSelectedProduct(List<Product> products) {
  if (_selectedProductId == null) {
    return null;
  }

  for (final product in products) {
    if (product.id == _selectedProductId) {
      return product;
    }
  }

  return null;
}

  @override
void initState() {
  super.initState();
  _selectedProductId = widget.product?.id;
}

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  int get _quantity {
    return int.tryParse(
          _quantityController.text.trim(),
        ) ??
        0;
  }

  

  Future<void> _submit(List<Product> products) async {
  final product = _getSelectedProduct(products);

  if (product == null) {
    _showMessage('Please select a product.');
    return;
  }

  if (_quantity <= 0) {
    _showMessage(
      'Enter a valid quantity greater than zero.',
    );
    return;
  }

  if (_direction == 'decrease' &&
      _quantity > product.stockQuantity) {
    _showMessage(
      'You cannot remove more stock than currently available.',
    );
    return;
  }

  setState(() {
    _isProcessing = true;
  });

  try {
    await ref.read(adjustStockProvider).call(
          productId: product.id,
          quantity: _quantity,
          direction: _direction,
          note: _noteController.text.trim().isEmpty
              ? null
              : _noteController.text.trim(),
        );

    if (!mounted) return;

    // Stop the processing state before showing the dialog.
    setState(() {
      _isProcessing = false;
    });

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Stock Updated',
            style: TextStyle(
              fontWeight: FontWeight.w800,
            ),
          ),
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
                product.name,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
  '${product.stockQuantity} → ${_direction == 'increase'
      ? product.stockQuantity + _quantity
      : product.stockQuantity - _quantity} units',
  style: const TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
  ),
),
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

    if (!mounted) return;

    // Refresh inventory AFTER leaving the adjustment screen.
    ref.invalidate(lowStockProductsProvider);
    ref.invalidate(productsProvider);
    ref.invalidate(inventorySummaryProvider);
    ref.invalidate(stockMovementsProvider);
    ref.invalidate(
      productStockMovementsProvider(product.id),
    );

    Navigator.of(context).pop(true);
  } catch (error) {
    if (!mounted) return;

    setState(() {
      _isProcessing = false;
    });

    _showMessage(
      error.toString().replaceFirst(
            'Exception: ',
            '',
          ),
    );
  }
}

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Adjust Stock',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      body: productsAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Unable to load products.\n$error',
                textAlign: TextAlign.center,
              ),
            ),
          );
        },
        data: (products) {
  final selectedProduct =
      _getSelectedProduct(products);

  final newStock = selectedProduct == null
      ? 0
      : _direction == 'increase'
          ? selectedProduct.stockQuantity + _quantity
          : selectedProduct.stockQuantity - _quantity;

  return LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop =
                  constraints.maxWidth >= 900;

              return SingleChildScrollView(
                padding: EdgeInsets.all(
                  isDesktop ? 32 : 16,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 760,
                    ),
                    child: _AdjustmentCard(
                      products: products,
                      selectedProduct: selectedProduct,
                      direction: _direction,
                      quantityController:
                          _quantityController,
                      noteController: _noteController,
                      quantity: _quantity,
                      newStock: newStock,
                      isProcessing: _isProcessing,
                      onProductChanged: (productId) {
  setState(() {
    _selectedProductId = productId;
  });
},
                      onDirectionChanged: (direction) {
                        setState(() {
                          _direction = direction;
                        });
                      },
                      onChanged: () {
                        setState(() {});
                      },
                      onSubmit: () => _submit(products),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _AdjustmentCard extends StatelessWidget {
  const _AdjustmentCard({
    required this.products,
    required this.selectedProduct,
    required this.direction,
    required this.quantityController,
    required this.noteController,
    required this.quantity,
    required this.newStock,
    required this.isProcessing,
    required this.onProductChanged,
    required this.onDirectionChanged,
    required this.onChanged,
    required this.onSubmit,
  });

  final List<Product> products;
  final Product? selectedProduct;
  final String direction;
  final TextEditingController quantityController;
  final TextEditingController noteController;
  final int quantity;
  final int newStock;
  final bool isProcessing;
  final ValueChanged<String?> onProductChanged;
  final ValueChanged<String> onDirectionChanged;
  final VoidCallback onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final isIncrease = direction == 'increase';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.035),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          const Text(
            'Update Inventory',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Manually increase or decrease the available stock.',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),

          const SizedBox(height: 26),

          const _FieldLabel(
            label: 'Product',
          ),
          const SizedBox(height: 8),

          DropdownButtonFormField<String>(
  initialValue: selectedProduct?.id,
  isExpanded: true,
  decoration: InputDecoration(
    hintText: 'Select a product',
    prefixIcon: const Icon(
      Icons.inventory_2_outlined,
    ),
    filled: true,
    fillColor: const Color(0xFFF7F8FA),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
  ),
  items: products.map((product) {
    return DropdownMenuItem<String>(
      value: product.id,
      child: Text(
        '${product.name} • ${product.stockQuantity} units',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }).toList(),
  onChanged: onProductChanged,
),

          const SizedBox(height: 22),

          if (selectedProduct != null)
            _CurrentStockCard(
              product: selectedProduct!,
            ),

          const SizedBox(height: 22),

          const _FieldLabel(
            label: 'Adjustment Type',
          ),
          const SizedBox(height: 8),

          Row(
            children: [
              Expanded(
                child: _DirectionButton(
                  label: 'Add Stock',
                  icon: Icons.add_circle_outline_rounded,
                  selected: isIncrease,
                  onTap: () {
                    onDirectionChanged(
                      'increase',
                    );
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DirectionButton(
                  label: 'Remove Stock',
                  icon: Icons.remove_circle_outline_rounded,
                  selected: !isIncrease,
                  onTap: () {
                    onDirectionChanged(
                      'decrease',
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          const _FieldLabel(
            label: 'Quantity',
          ),
          const SizedBox(height: 8),

          TextField(
            controller: quantityController,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              hintText: 'Enter quantity',
              prefixIcon: Icon(
                isIncrease
                    ? Icons.add_rounded
                    : Icons.remove_rounded,
              ),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 22),

          const _FieldLabel(
            label: 'Note',
          ),
          const SizedBox(height: 8),

          TextField(
            controller: noteController,
            maxLines: 3,
            decoration: InputDecoration(
              hintText:
                  'e.g. Damaged goods, physical count, opening stock...',
              prefixIcon: const Padding(
                padding: EdgeInsets.only(
                  bottom: 42,
                ),
                child: Icon(
                  Icons.notes_rounded,
                ),
              ),
              filled: true,
              fillColor: const Color(0xFFF7F8FA),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
            ),
          ),

          const SizedBox(height: 22),

          if (selectedProduct != null)
            _NewStockPreview(
              currentStock:
                  selectedProduct!.stockQuantity,
              newStock: newStock,
              increase: isIncrease,
            ),

          const SizedBox(height: 26),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed:
                  isProcessing ? null : onSubmit,
              icon: isProcessing
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(
                      Icons.check_rounded,
                    ),
              label: Text(
                isProcessing
                    ? 'Updating Stock...'
                    : 'Update Stock',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                ),
              ),
              style: FilledButton.styleFrom(
                backgroundColor:
                    const Color(0xFF087F5B),
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CurrentStockCard extends StatelessWidget {
  const _CurrentStockCard({
    required this.product,
  });

  final Product product;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5F1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: Color(0xFF087F5B),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Stock',
                  style: TextStyle(
                    color: Color(0xFF087F5B),
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  product.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '${product.stockQuantity}',
            style: const TextStyle(
              color: Color(0xFF087F5B),
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'units',
            style: TextStyle(
              color: Color(0xFF087F5B),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

class _NewStockPreview extends StatelessWidget {
  const _NewStockPreview({
    required this.currentStock,
    required this.newStock,
    required this.increase,
  });

  final int currentStock;
  final int newStock;
  final bool increase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFE9ECEF),
        ),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'New Stock Level',
              style: TextStyle(
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            '$currentStock',
            style: TextStyle(
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(
              horizontal: 10,
            ),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
            ),
          ),
          Text(
            '$newStock',
            style: TextStyle(
              color: increase
                  ? const Color(0xFF087F5B)
                  : Colors.red.shade700,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DirectionButton extends StatelessWidget {
  const _DirectionButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? const Color(0xFFE8F5F1)
          : const Color(0xFFF7F8FA),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 52,
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected
                  ? const Color(0xFF087F5B)
                  : const Color(0xFFE9ECEF),
            ),
          ),
          child: Row(
            mainAxisAlignment:
                MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: selected
                    ? const Color(0xFF087F5B)
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? const Color(0xFF087F5B)
                        : Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel({
    required this.label,
  });

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}