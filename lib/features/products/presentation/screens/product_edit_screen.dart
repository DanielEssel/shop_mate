import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../../core/ui/ui.dart';
import '../../../../core/utils/money_format.dart';
import '../../../product_categories/presentation/widgets/product_category_field.dart';
import '../../domain/entities/product.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_visuals.dart';

class EditProductScreen extends ConsumerStatefulWidget {
  const EditProductScreen({required this.product, super.key});

  final Product product;

  @override
  ConsumerState<EditProductScreen> createState() => _EditProductScreenState();
}

class _EditProductScreenState extends ConsumerState<EditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  bool _isSaving = false;
  bool _isPickingImage = false;

  Uint8List? _selectedImageBytes;
  String? _selectedImageExtension;

  final _nameController = TextEditingController();
  final _skuController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _costPriceController = TextEditingController();
  final _sellingPriceController = TextEditingController();
  final _stockController = TextEditingController();
  final _lowStockController = TextEditingController();
  final _descriptionController = TextEditingController();

  /// Optional; null clears the product's category.
  String? _selectedCategoryId;

  /// Forms read best at a moderate width, even on large windows.
  static const double _formWidth = 880;

  @override
  void initState() {
    super.initState();

    final product = widget.product;

    _nameController.text = product.name;
    _skuController.text = product.sku ?? '';
    _barcodeController.text = product.barcode ?? '';
    _costPriceController.text = product.costPrice.toStringAsFixed(2);
    _sellingPriceController.text = product.sellingPrice.toStringAsFixed(2);
    _stockController.text = product.stockQuantity.toString();
    _lowStockController.text = product.lowStockThreshold.toString();
    _descriptionController.text = product.description ?? '';

    _selectedCategoryId = product.categoryId;

    _costPriceController.addListener(_refresh);
    _sellingPriceController.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _skuController.dispose();
    _barcodeController.dispose();
    _costPriceController.dispose();
    _sellingPriceController.dispose();
    _stockController.dispose();
    _lowStockController.dispose();
    _descriptionController.dispose();

    super.dispose();
  }

  double get _costPrice =>
      double.tryParse(_costPriceController.text.trim()) ?? 0;

  double get _sellingPrice =>
      double.tryParse(_sellingPriceController.text.trim()) ?? 0;

  double get _profit => _sellingPrice - _costPrice;

  double get _margin {
    if (_sellingPrice <= 0) {
      return 0;
    }

    return (_profit / _sellingPrice) * 100;
  }

  Future<void> _pickImage(ImageSource source) async {
    if (_isSaving || _isPickingImage) {
      return;
    }

    setState(() {
      _isPickingImage = true;
    });

    try {
      final image = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1600,
        maxHeight: 1600,
      );

      if (image == null) {
        return;
      }

      final bytes = await image.readAsBytes();

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageExtension = _getImageExtension(image.name);
      });
    } catch (e) {
      if (!mounted) {
        return;
      }

      _showMessage('Unable to select image.');
    } finally {
      if (mounted) {
        setState(() {
          _isPickingImage = false;
        });
      }
    }
  }

  String _getImageExtension(String fileName) {
    final parts = fileName.split('.');

    if (parts.length < 2) {
      return 'jpg';
    }

    final extension = parts.last.toLowerCase();

    const supported = ['jpg', 'jpeg', 'png', 'webp'];

    if (supported.contains(extension)) {
      return extension;
    }

    return 'jpg';
  }

  Future<void> _showImageSourceSheet() async {
    if (_isSaving || _isPickingImage) {
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.sm,
              AppSpacing.xl,
              AppSpacing.xxl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Change Product Image',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AppSpacing.lg),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose from gallery'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_outlined),
                  title: const Text('Take a photo'),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(ImageSource.camera);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Prices and stock are owner-only on an existing product; for anyone
    // else the stored values are sent back unchanged (the database refuses
    // a change anyway).
    final isOwner = selectIsShopOwner(ref.read(shopAccessProvider));

    final costPrice = isOwner
        ? double.tryParse(_costPriceController.text.trim())
        : widget.product.costPrice;

    final sellingPrice = isOwner
        ? double.tryParse(_sellingPriceController.text.trim())
        : widget.product.sellingPrice;

    final stockQuantity = isOwner
        ? int.tryParse(_stockController.text.trim())
        : widget.product.stockQuantity;

    final lowStockThreshold =
        int.tryParse(_lowStockController.text.trim()) ?? 10;

    if (costPrice == null || sellingPrice == null) {
      _showMessage('Please enter valid prices.');
      return;
    }

    if (stockQuantity == null || stockQuantity < 0) {
      _showMessage('Please enter a valid stock quantity.');
      return;
    }

    if (sellingPrice < costPrice) {
      _showMessage('Selling price cannot be lower than cost price.');
      return;
    }

    if (lowStockThreshold < 0) {
      _showMessage('Low stock alert cannot be negative.');
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      final product = Product(
        id: widget.product.id,
        name: _nameController.text.trim(),
        categoryId: _selectedCategoryId,
        sku: _nullableValue(_skuController.text),
        barcode: _nullableValue(_barcodeController.text),
        description: _nullableValue(_descriptionController.text),
        costPrice: costPrice,
        sellingPrice: sellingPrice,
        stockQuantity: stockQuantity,
        lowStockThreshold: lowStockThreshold,
        isActive: widget.product.isActive,
        imageUrl: widget.product.imageUrl,
        createdAt: widget.product.createdAt,
        updatedAt: DateTime.now(),
      );

      final repository = ref.read(productRepositoryProvider);

      await ref.read(updateProductProvider).call(product);

      if (_selectedImageBytes != null) {
        _showMessage('Uploading product image...', success: true);

        final imageUrl = await repository.uploadProductImage(
          productId: product.id,
          bytes: _selectedImageBytes!,
          extension: _selectedImageExtension ?? 'jpg',
        );

        await repository.updateProductImageUrl(product.id, imageUrl);
      }

      ref.invalidate(productsProvider);
      ref.invalidate(productByIdProvider(product.id));
      ref.invalidate(lowStockProductsProvider);

      if (!mounted) {
        return;
      }

      _showMessage('Product updated successfully.', success: true);

      context.pop(true);
    } catch (error) {
      if (!mounted) {
        return;
      }

      _showMessage(error.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  String? _nullableValue(String value) {
    final trimmed = value.trim();

    return trimmed.isEmpty ? null : trimmed;
  }

  /// Floats above the Save bar so it never covers the action.
  void _showMessage(String message, {bool success = false}) {
    showFloatingMessage(
      context,
      message,
      clearance: FormActionBar.messageClearance,
      backgroundColor: success ? AppColors.success : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(shopAccessProvider.select(selectIsShopOwner));
    const gap = SizedBox(height: AppSpacing.xxl);
    const fieldGap = SizedBox(height: AppSpacing.lg);

    final basics = FormSection(
      title: 'Basic Information',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _textField(
            controller: _nameController,
            label: 'Product Name',
            icon: Icons.inventory_2_outlined,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Product name is required.';
              }

              return null;
            },
          ),
          fieldGap,
          ProductCategoryField(
            selectedCategoryId: _selectedCategoryId,
            currentCategoryName: widget.product.categoryName,
            currentCategoryIsActive: widget.product.categoryIsActive,
            decoration: _inputDecoration(
              label: 'Category',
              icon: Icons.category_outlined,
            ),
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
          ),
          fieldGap,
          FieldRow(
            children: [
              _textField(
                controller: _skuController,
                label: 'SKU',
                icon: Icons.qr_code_2_outlined,
              ),
              _textField(
                controller: _barcodeController,
                label: 'Barcode',
                icon: Icons.barcode_reader,
              ),
            ],
          ),
          fieldGap,
          _textField(
            controller: _descriptionController,
            label: 'Description',
            icon: Icons.notes_outlined,
            maxLines: 4,
          ),
        ],
      ),
    );

    final pricing = FormSection(
      title: 'Pricing',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FieldRow(
            children: [
              _textField(
                controller: _costPriceController,
                label: 'Cost Price',
                icon: Icons.shopping_cart_outlined,
                locked: !isOwner,
                lockedHint: _ownerOnlyPriceHint,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _priceValidator('Enter a valid cost price.'),
              ),
              _textField(
                controller: _sellingPriceController,
                label: 'Selling Price',
                icon: Icons.sell_outlined,
                locked: !isOwner,
                lockedHint: _ownerOnlyPriceHint,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: _priceValidator('Enter a valid selling price.'),
              ),
            ],
          ),
          fieldGap,
          _ProfitPreview(profit: _profit, margin: _margin),
        ],
      ),
    );

    final inventory = FormSection(
      title: 'Inventory',
      child: FieldRow(
        children: [
          _textField(
            controller: _stockController,
            label: 'Stock Quantity',
            icon: Icons.numbers_outlined,
            locked: !isOwner,
            lockedHint: 'Stock changes through sales and purchases.',
            keyboardType: TextInputType.number,
            validator: _countValidator('Enter a valid stock quantity.'),
          ),
          _textField(
            controller: _lowStockController,
            label: 'Low Stock Threshold',
            icon: Icons.warning_amber_outlined,
            keyboardType: TextInputType.number,
            validator: _countValidator('Enter a valid threshold.'),
          ),
        ],
      ),
    );

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
                      maxWidth: _formWidth,
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
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            PageHeader(
                              title: 'Edit Product',
                              subtitle: widget.product.name,
                              leading: pageHeaderLeading(context),
                            ),
                            const SizedBox(height: AppSpacing.xxl),
                            _ImagePickerCard(
                              product: widget.product,
                              selectedImageBytes: _selectedImageBytes,
                              isPicking: _isPickingImage,
                              onTap: _showImageSourceSheet,
                            ),
                            gap,
                            basics,
                            gap,
                            pricing,
                            gap,
                            inventory,
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              FormActionBar(
                primaryLabel: 'Save Changes',
                busyLabel: 'Saving Changes...',
                primaryIcon: Icons.save_outlined,
                isBusy: _isSaving,
                onPrimary: _saveProduct,
                onSecondary: () => context.pop(),
                maxContentWidth: _formWidth,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String? Function(String?) _priceValidator(String message) {
    return (value) {
      final number = double.tryParse(value?.trim() ?? '');

      if (number == null || number < 0) {
        return message;
      }

      return null;
    };
  }

  static String? Function(String?) _countValidator(String message) {
    return (value) {
      final number = int.tryParse(value?.trim() ?? '');

      if (number == null || number < 0) {
        return message;
      }

      return null;
    };
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(labelText: label, prefixIcon: Icon(icon));
  }

  static const _ownerOnlyPriceHint = 'Only the shop owner can change prices.';

  /// [locked] shows the value without allowing edits (owner-only fields for
  /// an attendant), with [lockedHint] explaining why.
  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
    bool locked = false,
    String? lockedHint,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: locked ? null : validator,
      maxLines: maxLines,
      enabled: !_isSaving && !locked,
      decoration: _inputDecoration(label: label, icon: icon).copyWith(
        helperText: locked ? lockedHint : null,
        helperMaxLines: 2,
        suffixIcon: locked
            ? const Icon(Icons.lock_outline_rounded, size: 18)
            : null,
      ),
    );
  }
}

/// Live profit per unit and margin from the entered prices.
class _ProfitPreview extends StatelessWidget {
  const _ProfitPreview({required this.profit, required this.margin});

  final double profit;
  final double margin;

  @override
  Widget build(BuildContext context) {
    final positive = profit >= 0;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Profit / Unit',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
          Text(
            formatGhs(profit),
            style: AppTypography.amount.copyWith(
              color: positive ? AppColors.success : AppColors.danger,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          StatusBadge(
            label: '${margin.toStringAsFixed(1)}%',
            tone: positive ? StatusTone.success : StatusTone.danger,
            showDot: false,
          ),
        ],
      ),
    );
  }
}

/// The product photo and how to change it.
class _ImagePickerCard extends StatelessWidget {
  const _ImagePickerCard({
    required this.product,
    required this.selectedImageBytes,
    required this.isPicking,
    required this.onTap,
  });

  final Product product;
  final Uint8List? selectedImageBytes;
  final bool isPicking;
  final VoidCallback onTap;

  static const double _size = 72;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final Widget image;

    if (selectedImageBytes != null) {
      image = Image.memory(selectedImageBytes!, fit: BoxFit.cover);
    } else if (product.imageUrl != null &&
        product.imageUrl!.trim().isNotEmpty) {
      image = Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) =>
            InitialAvatar(name: product.name, size: _size),
      );
    } else {
      image = ProductThumb(product: product, size: _size);
    }

    return SurfaceCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      onTap: isPicking ? null : onTap,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: SizedBox(
              width: _size,
              height: _size,
              child: isPicking
                  ? const Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : image,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Product Image',
                  style: textTheme.titleSmall?.copyWith(
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  selectedImageBytes != null
                      ? 'New image selected. It uploads when you save.'
                      : 'Tap to change the product image.',
                  style: textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          const Icon(
            Icons.photo_camera_outlined,
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
