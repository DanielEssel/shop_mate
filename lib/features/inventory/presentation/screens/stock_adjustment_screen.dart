import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../products/domain/entities/product.dart';
import '../../../products/presentation/providers/products_provider.dart';
import '../providers/inventory_provider.dart';

class StockAdjustmentScreen extends ConsumerStatefulWidget {
  const StockAdjustmentScreen({super.key, this.product});

  final Product? product;

  @override
  ConsumerState<StockAdjustmentScreen> createState() =>
      _StockAdjustmentScreenState();
}

class _StockAdjustmentScreenState extends ConsumerState<StockAdjustmentScreen> {
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
    return int.tryParse(_quantityController.text.trim()) ?? 0;
  }

  Future<void> _submit(List<Product> products) async {
    final product = _getSelectedProduct(products);

    if (product == null) {
      _showMessage('Please select a product.');
      return;
    }

    if (_quantity <= 0) {
      _showMessage('Enter a valid quantity greater than zero.');
      return;
    }

    if (_direction == 'decrease' && _quantity > product.stockQuantity) {
      _showMessage('You cannot remove more stock than currently available.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      await ref
          .read(adjustStockProvider)
          .call(
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
            title: const Text('Stock Updated'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_rounded,
                  size: 64,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  style: AppTypography.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                // An arrow icon, not the arrow character: the app font has
                // no glyph for it.
                Builder(
                  builder: (context) {
                    final style = AppTypography.metricMedium.copyWith(
                      color: AppColors.textPrimary,
                    );
                    final before = '${product.stockQuantity}';
                    final after =
                        '${_direction == 'increase' ? product.stockQuantity + _quantity : product.stockQuantity - _quantity} units';

                    return Semantics(
                      label: '$before to $after',
                      excludeSemantics: true,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(before, style: style),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 6),
                            child: Icon(Icons.arrow_forward_rounded, size: 18),
                          ),
                          Text(after, style: style),
                        ],
                      ),
                    );
                  },
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
      ref.invalidate(productStockMovementsProvider(product.id));

      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    }
  }

  /// Floats above the action bar so it never covers Update Stock.
  void _showMessage(String message) {
    showFloatingMessage(
      context,
      message,
      clearance: FormActionBar.messageClearance,
    );
  }

  @override
  Widget build(BuildContext context) {
    final productsAsync = ref.watch(productsProvider);
    final products = productsAsync.value;

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
                          title: 'Adjust Stock',
                          subtitle:
                              'Manually increase or decrease the available '
                              'stock.',
                          leading: pageHeaderLeading(context),
                        ),
                        const SizedBox(height: AppSpacing.xxl),
                        productsAsync.when(
                          loading: () => Semantics(
                            container: true,
                            label: 'Loading products',
                            child: const ExcludeSemantics(
                              child: SkeletonList(rows: 3),
                            ),
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
                          data: (products) {
                            final selectedProduct = _getSelectedProduct(
                              products,
                            );

                            final newStock = selectedProduct == null
                                ? 0
                                : _direction == 'increase'
                                ? selectedProduct.stockQuantity + _quantity
                                : selectedProduct.stockQuantity - _quantity;

                            return _AdjustmentForm(
                              products: products,
                              selectedProduct: selectedProduct,
                              direction: _direction,
                              quantityController: _quantityController,
                              noteController: _noteController,
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
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            FormActionBar(
              primaryLabel: 'Update Stock',
              busyLabel: 'Updating Stock...',
              isBusy: _isProcessing,
              onPrimary: products == null ? null : () => _submit(products),
              onSecondary: () => Navigator.of(context).maybePop(),
              maxContentWidth: ContentWidth.form,
            ),
          ],
        ),
      ),
    );
  }
}

class _AdjustmentForm extends StatelessWidget {
  const _AdjustmentForm({
    required this.products,
    required this.selectedProduct,
    required this.direction,
    required this.quantityController,
    required this.noteController,
    required this.newStock,
    required this.isProcessing,
    required this.onProductChanged,
    required this.onDirectionChanged,
    required this.onChanged,
  });

  final List<Product> products;
  final Product? selectedProduct;
  final String direction;
  final TextEditingController quantityController;
  final TextEditingController noteController;
  final int newStock;
  final bool isProcessing;
  final ValueChanged<String?> onProductChanged;
  final ValueChanged<String> onDirectionChanged;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final isIncrease = direction == 'increase';
    final selectedProduct = this.selectedProduct;
    const fieldGap = SizedBox(height: AppSpacing.lg);

    return FormSection(
      title: 'Adjustment',
      subtitle: 'Choose a product, the change and how many units.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            initialValue: selectedProduct?.id,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Product',
              hintText: 'Select a product',
              prefixIcon: Icon(Icons.inventory_2_outlined),
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
            onChanged: isProcessing ? null : onProductChanged,
          ),
          if (selectedProduct != null) ...[
            const SizedBox(height: AppSpacing.md),
            _CurrentStockCard(product: selectedProduct),
          ],
          fieldGap,
          OptionChipGroup(
            label: 'Adjustment type',
            options: const [
              ('increase', 'Add Stock'),
              ('decrease', 'Remove Stock'),
            ],
            selected: direction,
            onSelected: isProcessing ? null : onDirectionChanged,
          ),
          fieldGap,
          TextField(
            controller: quantityController,
            enabled: !isProcessing,
            keyboardType: TextInputType.number,
            onChanged: (_) => onChanged(),
            decoration: InputDecoration(
              labelText: 'Quantity',
              hintText: 'Enter quantity',
              prefixIcon: Icon(
                isIncrease ? Icons.add_rounded : Icons.remove_rounded,
              ),
            ),
          ),
          fieldGap,
          TextField(
            controller: noteController,
            enabled: !isProcessing,
            minLines: 2,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Note (optional)',
              hintText: 'e.g. Damaged goods, physical count, opening stock...',
            ),
          ),
          if (selectedProduct != null) ...[
            fieldGap,
            _NewStockPreview(
              currentStock: selectedProduct.stockQuantity,
              newStock: newStock,
              increase: isIncrease,
            ),
          ],
        ],
      ),
    );
  }
}

class _CurrentStockCard extends StatelessWidget {
  const _CurrentStockCard({required this.product});

  final Product product;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.primarySurface,
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.inventory_2_outlined, color: AppColors.primary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current stock',
                  style: textTheme.labelSmall?.copyWith(
                    color: AppColors.primaryDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            '${product.stockQuantity}',
            style: AppTypography.metricMedium.copyWith(
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(width: AppSpacing.xs),
          Text(
            'units',
            style: textTheme.bodySmall?.copyWith(color: AppColors.primaryDark),
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
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'New stock level',
              style: textTheme.titleSmall?.copyWith(
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            '$currentStock',
            style: AppTypography.amount.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            child: Icon(
              Icons.arrow_forward_rounded,
              size: 18,
              color: AppColors.textMuted,
            ),
          ),
          Text(
            '$newStock',
            style: AppTypography.metricMedium.copyWith(
              color: increase ? AppColors.primary : AppColors.danger,
            ),
          ),
        ],
      ),
    );
  }
}
