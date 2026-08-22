import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../domain/entities/product.dart';
import '../providers/products_provider.dart';

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

    final product = widget.product;

    _nameController.text = product.name;
    _skuController.text = product.sku ?? '';
    _barcodeController.text = product.barcode ?? '';
    _costPriceController.text = product.costPrice.toStringAsFixed(2);
    _sellingPriceController.text = product.sellingPrice.toStringAsFixed(2);
    _stockController.text = product.stockQuantity.toString();
    _lowStockController.text = product.lowStockThreshold.toString();
    _descriptionController.text = product.description ?? '';

    _selectedCategory = product.category;

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
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Change Product Image',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 20),
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

    if (_selectedCategory == null) {
      _showMessage('Please select a category.');
      return;
    }

    final costPrice = double.tryParse(_costPriceController.text.trim());

    final sellingPrice = double.tryParse(_sellingPriceController.text.trim());

    final stockQuantity = int.tryParse(_stockController.text.trim());

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
        category: _selectedCategory!,
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

  void _showMessage(String message, {bool success = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: success ? AppColors.success : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Edit Product',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _ImagePickerCard(
                    product: widget.product,
                    selectedImageBytes: _selectedImageBytes,
                    isPicking: _isPickingImage,
                    onTap: _showImageSourceSheet,
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  _SectionCard(
                    title: 'Basic Information',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
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
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _selectedCategory,
                          decoration: _inputDecoration(
                            label: 'Category',
                            icon: Icons.category_outlined,
                          ),
                          items: _categories
                              .map(
                                (category) => DropdownMenuItem(
                                  value: category,
                                  child: Text(category),
                                ),
                              )
                              .toList(),
                          onChanged: _isSaving
                              ? null
                              : (value) {
                                  setState(() {
                                    _selectedCategory = value;
                                  });
                                },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a category.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _skuController,
                          label: 'SKU',
                          icon: Icons.qr_code_2_outlined,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _barcodeController,
                          label: 'Barcode',
                          icon: Icons.barcode_reader,
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _descriptionController,
                          label: 'Description',
                          icon: Icons.notes_outlined,
                          maxLines: 4,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _SectionCard(
                    title: 'Pricing',
                    icon: Icons.payments_outlined,
                    child: Column(
                      children: [
                        _textField(
                          controller: _costPriceController,
                          label: 'Cost Price',
                          icon: Icons.shopping_cart_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final number = double.tryParse(value?.trim() ?? '');

                            if (number == null || number < 0) {
                              return 'Enter a valid cost price.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _sellingPriceController,
                          label: 'Selling Price',
                          icon: Icons.sell_outlined,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          validator: (value) {
                            final number = double.tryParse(value?.trim() ?? '');

                            if (number == null || number < 0) {
                              return 'Enter a valid selling price.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primaryLight,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  'Profit / Unit',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              Text(
                                'GH₵ ${_profit.toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  color: _profit >= 0
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              ),
                              const SizedBox(width: 18),
                              Text(
                                '${_margin.toStringAsFixed(1)}%',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.lg),

                  _SectionCard(
                    title: 'Inventory',
                    icon: Icons.inventory_2_outlined,
                    child: Column(
                      children: [
                        _textField(
                          controller: _stockController,
                          label: 'Stock Quantity',
                          icon: Icons.numbers_outlined,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final number = int.tryParse(value?.trim() ?? '');

                            if (number == null || number < 0) {
                              return 'Enter a valid stock quantity.';
                            }

                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        _textField(
                          controller: _lowStockController,
                          label: 'Low Stock Threshold',
                          icon: Icons.warning_amber_outlined,
                          keyboardType: TextInputType.number,
                          validator: (value) {
                            final number = int.tryParse(value?.trim() ?? '');

                            if (number == null || number < 0) {
                              return 'Enter a valid threshold.';
                            }

                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: AppSpacing.xl),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveProduct,
                      icon: _isSaving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_outlined),
                      label: Text(
                        _isSaving ? 'Saving Changes...' : 'Save Changes',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration({
    required String label,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon),
      filled: true,
      fillColor: AppColors.background,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide.none,
      ),
    );
  }

  Widget _textField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator,
      maxLines: maxLines,
      enabled: !_isSaving,
      decoration: _inputDecoration(label: label, icon: icon),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    Widget image;

    if (selectedImageBytes != null) {
      image = Image.memory(selectedImageBytes!, fit: BoxFit.cover);
    } else if (product.imageUrl != null &&
        product.imageUrl!.trim().isNotEmpty) {
      image = Image.network(
        product.imageUrl!,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => const Icon(
          Icons.inventory_2_rounded,
          size: 42,
          color: AppColors.primary,
        ),
      );
    } else {
      image = const Icon(
        Icons.inventory_2_rounded,
        size: 42,
        color: AppColors.primary,
      );
    }

    return InkWell(
      onTap: isPicking ? null : onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 92,
              height: 92,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(16),
              ),
              child: isPicking
                  ? const Center(child: CircularProgressIndicator())
                  : image,
            ),
            const SizedBox(width: 18),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Product Image',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  SizedBox(height: 5),
                  Text('Tap to change the product image.'),
                ],
              ),
            ),
            const Icon(Icons.camera_alt_outlined),
          ],
        ),
      ),
    );
  }
}

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
      padding: const EdgeInsets.all(AppSpacing.xl),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          child,
        ],
      ),
    );
  }
}
