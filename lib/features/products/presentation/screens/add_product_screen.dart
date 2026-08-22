import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';

class AddProductScreen extends ConsumerStatefulWidget {
  const AddProductScreen({super.key});

  @override
  ConsumerState<AddProductScreen> createState() =>
      _AddProductScreenState();
}

class _AddProductScreenState
    extends ConsumerState<AddProductScreen> {
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
  final _lowStockController =
      TextEditingController(text: '10');
  final _descriptionController = TextEditingController();

  String? _selectedCategory;

  final List<String> _categories = [
    'Groceries',
    'Beverages',
    'Dairy',
    'Grains',
    'Cooking',
    'Household',
    'Personal Care',
    'Other',
  ];

  @override
  void initState() {
    super.initState();

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

  // ---------------------------------------------------------------------------
  // CALCULATIONS
  // ---------------------------------------------------------------------------

  double get _costPrice =>
      double.tryParse(
        _costPriceController.text.trim(),
      ) ??
      0;

  double get _sellingPrice =>
      double.tryParse(
        _sellingPriceController.text.trim(),
      ) ??
      0;

  double get _profit =>
      _sellingPrice - _costPrice;

  double get _margin {
    if (_sellingPrice <= 0) {
      return 0;
    }

    return (_profit / _sellingPrice) * 100;
  }

  // ---------------------------------------------------------------------------
  // IMAGE PICKING
  // ---------------------------------------------------------------------------

  Future<void> _pickImage(
    ImageSource source,
  ) async {
    if (_isPickingImage || _isSaving) {
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

      final extension = _getImageExtension(
        image.name,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _selectedImageBytes = bytes;
        _selectedImageExtension = extension;
      });
    } catch (e, stackTrace) {
      debugPrint(
        'IMAGE PICK ERROR: $e',
      );

      debugPrint(
        'STACK TRACE: $stackTrace',
      );

      if (!mounted) {
        return;
      }

      _showMessage(
        'Unable to select image.',
      );
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

    final extension =
        parts.last.toLowerCase();

    const supported = [
      'jpg',
      'jpeg',
      'png',
      'webp',
    ];

    if (supported.contains(extension)) {
      return extension;
    }

    return 'jpg';
  }

  void _removeImage() {
    setState(() {
      _selectedImageBytes = null;
      _selectedImageExtension = null;
    });
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
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Add Product Image',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Choose how you want to add the product image.',
                  ),
                ),
                const SizedBox(height: 20),
                ListTile(
                  leading: const Icon(
                    Icons.photo_library_outlined,
                  ),
                  title: const Text(
                    'Choose from gallery',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(
                      ImageSource.gallery,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.camera_alt_outlined,
                  ),
                  title: const Text(
                    'Take a photo',
                  ),
                  onTap: () {
                    Navigator.pop(context);
                    _pickImage(
                      ImageSource.camera,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE
  // ---------------------------------------------------------------------------

  Future<void> _saveProduct() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_selectedCategory == null) {
      _showMessage(
        'Please select a category.',
      );
      return;
    }

    final costPrice = double.tryParse(
      _costPriceController.text.trim(),
    );

    final sellingPrice = double.tryParse(
      _sellingPriceController.text.trim(),
    );

    final stockQuantity = int.tryParse(
      _stockController.text.trim(),
    );

    final lowStockThreshold = int.tryParse(
          _lowStockController.text.trim(),
        ) ??
        10;

    if (costPrice == null ||
        sellingPrice == null) {
      _showMessage(
        'Please enter valid prices.',
      );
      return;
    }

    if (stockQuantity == null) {
      _showMessage(
        'Please enter a valid stock quantity.',
      );
      return;
    }

    if (sellingPrice < costPrice) {
      _showMessage(
        'Selling price cannot be lower than cost price.',
      );
      return;
    }

    if (lowStockThreshold < 0) {
      _showMessage(
        'Low stock alert cannot be negative.',
      );
      return;
    }

    setState(() {
  _isSaving = true;
});

try {
  final repository = ref.read(productRepositoryProvider);

  // -------------------------------------------------------------
  // 1. CREATE PRODUCT FIRST
  // -------------------------------------------------------------

  final product = Product(
    id: '',
    name: _nameController.text.trim(),
    category: _selectedCategory!,
    sku: _nullableValue(_skuController.text),
    barcode: _nullableValue(_barcodeController.text),
    description: _nullableValue(_descriptionController.text),
    costPrice: costPrice,
    sellingPrice: sellingPrice,
    stockQuantity: stockQuantity,
    lowStockThreshold: lowStockThreshold,
    isActive: true,
  );

  final createdProduct = await repository.createProduct(product);

  debugPrint(
    'PRODUCT CREATED: ${createdProduct.id}',
  );

  // -------------------------------------------------------------
  // 2. UPLOAD IMAGE IF SELECTED
  // -------------------------------------------------------------

  if (_selectedImageBytes != null) {
    _showMessage(
      'Uploading product image...',
      success: true,
    );

    final imageUrl = await repository.uploadProductImage(
      productId: createdProduct.id,
      bytes: _selectedImageBytes!,
      extension: _selectedImageExtension ?? 'jpg',
    );

    debugPrint(
      'PRODUCT IMAGE URL: $imageUrl',
    );

    // -----------------------------------------------------------
    // 3. SAVE IMAGE URL TO PRODUCT
    // -----------------------------------------------------------

    await repository.updateProductImageUrl(
      createdProduct.id,
      imageUrl,
    );
  }

  // -------------------------------------------------------------
  // 4. REFRESH PRODUCTS
  // -------------------------------------------------------------

  ref.invalidate(productsProvider);

  if (!mounted) {
    return;
  }

  _showMessage(
    'Product added successfully.',
    success: true,
  );

  await Future.delayed(
    const Duration(milliseconds: 500),
  );

  if (!mounted) {
    return;
  }

  context.pop();

} catch (e, stackTrace) {
  debugPrint(
    'CREATE PRODUCT ERROR: $e',
  );

  debugPrint(
    'STACK TRACE: $stackTrace',
  );

  if (!mounted) {
    return;
  }

  _showMessage(
    'Unable to save product: $e',
  );

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

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  void _showMessage(
    String message, {
    bool success = false,
  }) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          behavior: SnackBarBehavior.floating,
          backgroundColor: success
              ? AppColors.success
              : AppColors.error,
        ),
      );
  }

  // ---------------------------------------------------------------------------
  // BUILD
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Add Product'),
        leading: IconButton(
          tooltip: 'Back',
          onPressed: _isSaving
              ? null
              : () => context.pop(),
          icon: const Icon(
            Icons.arrow_back_rounded,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop =
                constraints.maxWidth >= 900;

            return SingleChildScrollView(
              padding: EdgeInsets.all(
                isDesktop
                    ? AppSpacing.xxxl
                    : AppSpacing.xl,
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
                      _buildPageHeader(context),

                      const SizedBox(
                        height: AppSpacing.xxl,
                      ),

                      _buildImageSection(),

                      const SizedBox(
                        height: AppSpacing.lg,
                      ),

                      if (isDesktop)
                        _buildDesktopLayout()
                      else
                        _buildMobileLayout(),

                      const SizedBox(
                        height: AppSpacing.xxxl,
                      ),

                      _buildSaveButton(),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildPageHeader(
    BuildContext context,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Create a new product',
          style: Theme.of(context)
              .textTheme
              .headlineMedium
              ?.copyWith(
                fontWeight: FontWeight.w700,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Add product information, pricing and inventory details.',
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color: AppColors.textSecondary,
              ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // IMAGE SECTION
  // ---------------------------------------------------------------------------

  Widget _buildImageSection() {
    final hasImage =
        _selectedImageBytes != null;

    return _SectionCard(
      title: 'Product Image',
      icon: Icons.image_outlined,
      child: Column(
        children: [
          if (hasImage)
            _buildImagePreview()
          else
            _buildImagePlaceholder(),

          const SizedBox(
            height: AppSpacing.lg,
          ),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed:
                      _isSaving || _isPickingImage
                          ? null
                          : _showImageSourceSheet,
                  icon: _isPickingImage
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child:
                              CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(
                          Icons
                              .add_photo_alternate_outlined,
                        ),
                  label: Text(
                    hasImage
                        ? 'Change Image'
                        : 'Add Image',
                  ),
                ),
              ),
              if (hasImage) ...[
                const SizedBox(
                  width: AppSpacing.md,
                ),
                IconButton(
                  tooltip: 'Remove image',
                  onPressed:
                      _isSaving
                          ? null
                          : _removeImage,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                  ),
                  color: AppColors.error,
                ),
              ],
            ],
          ),

          const SizedBox(height: 8),

          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recommended: square product image. JPG, PNG or WebP.',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textMuted,
                  ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildImagePlaceholder() {
    return Container(
      width: double.infinity,
      height: 220,
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _isSaving
            ? null
            : _showImageSourceSheet,
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius:
                    BorderRadius.circular(18),
              ),
              child: const Icon(
                Icons.image_outlined,
                size: 30,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Add product image',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              'Tap to choose an image',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImagePreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        height: 300,
        color: AppColors.background,
        child: Image.memory(
          _selectedImageBytes!,
          fit: BoxFit.contain,
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // LAYOUT
  // ---------------------------------------------------------------------------

  Widget _buildDesktopLayout() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            children: [
              _buildBasicInformation(),
              const SizedBox(
                height: AppSpacing.lg,
              ),
              _buildDescription(),
            ],
          ),
        ),
        const SizedBox(
          width: AppSpacing.lg,
        ),
        Expanded(
          child: Column(
            children: [
              _buildPricing(),
              const SizedBox(
                height: AppSpacing.lg,
              ),
              _buildInventory(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Column(
      children: [
        _buildBasicInformation(),
        const SizedBox(height: AppSpacing.lg),
        _buildPricing(),
        const SizedBox(height: AppSpacing.lg),
        _buildInventory(),
        const SizedBox(height: AppSpacing.lg),
        _buildDescription(),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // BASIC INFORMATION
  // ---------------------------------------------------------------------------

  Widget _buildBasicInformation() {
    return _SectionCard(
      title: 'Basic Information',
      icon: Icons.info_outline_rounded,
      child: Column(
        children: [
          _AppTextField(
            controller: _nameController,
            label: 'Product Name',
            hint: 'e.g. Peak Milk 400g',
            required: true,
            prefixIcon:
                Icons.inventory_2_outlined,
            validator: (value) {
              if (value == null ||
                  value.trim().isEmpty) {
                return 'Product name is required.';
              }

              return null;
            },
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          _AppDropdown(
            value: _selectedCategory,
            label: 'Category',
            hint: 'Select category',
            items: _categories,
            onChanged: _isSaving
                ? null
                : (value) {
                    setState(() {
                      _selectedCategory =
                          value;
                    });
                  },
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          Row(
            children: [
              Expanded(
                child: _AppTextField(
                  controller: _skuController,
                  label: 'SKU',
                  hint: 'Optional',
                  prefixIcon:
                      Icons.tag_rounded,
                ),
              ),
              const SizedBox(
                width: AppSpacing.md,
              ),
              Expanded(
                child: _AppTextField(
                  controller:
                      _barcodeController,
                  label: 'Barcode',
                  hint: 'Optional',
                  prefixIcon:
                      Icons.qr_code_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // PRICING
  // ---------------------------------------------------------------------------

  Widget _buildPricing() {
    return _SectionCard(
      title: 'Pricing',
      icon: Icons.payments_outlined,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _AppTextField(
                  controller:
                      _costPriceController,
                  label: 'Cost Price',
                  hint: '0.00',
                  required: true,
                  prefixText: 'GH₵ ',
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount =
                        double.tryParse(
                      value ?? '',
                    );

                    if (amount == null ||
                        amount < 0) {
                      return 'Enter a valid price.';
                    }

                    return null;
                  },
                ),
              ),
              const SizedBox(
                width: AppSpacing.md,
              ),
              Expanded(
                child: _AppTextField(
                  controller:
                      _sellingPriceController,
                  label: 'Selling Price',
                  hint: '0.00',
                  required: true,
                  prefixText: 'GH₵ ',
                  keyboardType:
                      const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (value) {
                    final amount =
                        double.tryParse(
                      value ?? '',
                    );

                    if (amount == null ||
                        amount <= 0) {
                      return 'Enter a valid price.';
                    }

                    return null;
                  },
                ),
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.lg,
          ),
          _ProfitPreview(
            profit: _profit,
            margin: _margin,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // INVENTORY
  // ---------------------------------------------------------------------------

  Widget _buildInventory() {
    return _SectionCard(
      title: 'Inventory',
      icon: Icons.inventory_2_outlined,
      child: Row(
        children: [
          Expanded(
            child: _AppTextField(
              controller: _stockController,
              label: 'Opening Stock',
              hint: '0',
              required: true,
              keyboardType:
                  TextInputType.number,
              prefixIcon:
                  Icons.numbers_rounded,
              validator: (value) {
                final quantity =
                    int.tryParse(
                  value ?? '',
                );

                if (quantity == null ||
                    quantity < 0) {
                  return 'Enter quantity.';
                }

                return null;
              },
            ),
          ),
          const SizedBox(
            width: AppSpacing.md,
          ),
          Expanded(
            child: _AppTextField(
              controller:
                  _lowStockController,
              label: 'Low Stock Alert',
              hint: '10',
              keyboardType:
                  TextInputType.number,
              prefixIcon:
                  Icons.warning_amber_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // DESCRIPTION
  // ---------------------------------------------------------------------------

  Widget _buildDescription() {
    return _SectionCard(
      title: 'Description',
      icon: Icons.notes_rounded,
      child: _AppTextField(
        controller:
            _descriptionController,
        label: 'Description',
        hint:
            'Optional product description...',
        maxLines: 5,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // SAVE BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildSaveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed:
            _isSaving ? null : _saveProduct,
        icon: _isSaving
            ? const SizedBox(
                width: 20,
                height: 20,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(
                Icons.check_rounded,
              ),
        label: Text(
          _isSaving
              ? 'Saving Product...'
              : 'Save Product',
        ),
        style: FilledButton.styleFrom(
          backgroundColor:
              AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor:
              AppColors.primary.withValues(
            alpha: 0.6,
          ),
          padding:
              const EdgeInsets.symmetric(
            vertical: 17,
          ),
          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// SECTION CARD
// =============================================================================

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius:
            BorderRadius.circular(18),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration:
                    BoxDecoration(
                  color:
                      AppColors.primaryLight,
                  borderRadius:
                      BorderRadius.circular(
                    10,
                  ),
                ),
                child: Icon(
                  icon,
                  size: 19,
                  color:
                      AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w700,
                    ),
              ),
            ],
          ),
          const SizedBox(
            height: AppSpacing.xl,
          ),
          child,
        ],
      ),
    );
  }
}

// =============================================================================
// TEXT FIELD
// =============================================================================

class _AppTextField
    extends StatelessWidget {
  const _AppTextField({
    required this.controller,
    required this.label,
    this.hint,
    this.required = false,
    this.prefixIcon,
    this.prefixText,
    this.keyboardType,
    this.validator,
    this.maxLines = 1,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool required;
  final IconData? prefixIcon;
  final String? prefixText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  @override
  Widget build(
    BuildContext context,
  ) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: required
            ? '$label *'
            : label,
        hintText: hint,
        prefixIcon:
            prefixIcon != null
                ? Icon(prefixIcon)
                : null,
        prefixText: prefixText,
      ),
    );
  }
}

// =============================================================================
// DROPDOWN
// =============================================================================

class _AppDropdown
    extends StatelessWidget {
  const _AppDropdown({
    required this.value,
    required this.label,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  final String? value;
  final String label;
  final String hint;
  final List<String> items;
  final ValueChanged<String?>? onChanged;

  @override
  Widget build(
    BuildContext context,
  ) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration:
          const InputDecoration(
        labelText: 'Category',
        prefixIcon: Icon(
          Icons.category_outlined,
        ),
      ),
      hint: Text(hint),
      items: items.map((item) {
        return DropdownMenuItem(
          value: item,
          child: Text(item),
        );
      }).toList(),
      onChanged: onChanged,
      validator: (value) {
        if (value == null ||
            value.isEmpty) {
          return 'Please select a category.';
        }

        return null;
      },
    );
  }
}

// =============================================================================
// PROFIT PREVIEW
// =============================================================================

class _ProfitPreview
    extends StatelessWidget {
  const _ProfitPreview({
    required this.profit,
    required this.margin,
  });

  final double profit;
  final double margin;

  @override
  Widget build(
    BuildContext context,
  ) {
    final isPositive = profit > 0;

    return Container(
      padding:
          const EdgeInsets.all(
        AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: isPositive
            ? AppColors.success
                .withValues(alpha: 0.08)
            : AppColors.error
                .withValues(alpha: 0.08),
        borderRadius:
            BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            isPositive
                ? Icons
                    .trending_up_rounded
                : Icons
                    .warning_amber_rounded,
            color: isPositive
                ? AppColors.success
                : AppColors.error,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment
                      .start,
              children: [
                Text(
                  'Expected Profit',
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color: AppColors
                            .textSecondary,
                      ),
                ),
                const SizedBox(
                  height: 3,
                ),
                Text(
                  'GH₵ ${profit.toStringAsFixed(2)}',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
                ),
              ],
            ),
          ),
          Text(
            '${margin.toStringAsFixed(1)}%',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w700,
                  color: isPositive
                      ? AppColors.success
                      : AppColors.error,
                ),
          ),
        ],
      ),
    );
  }
}