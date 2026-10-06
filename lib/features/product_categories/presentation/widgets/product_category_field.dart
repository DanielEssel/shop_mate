import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/product_category_providers.dart';

/// Optional category selector for product forms. Offers "No category" and
/// the shop's active categories. A product's current archived category is
/// kept as an option so editing does not silently drop it.
class ProductCategoryField extends ConsumerWidget {
  const ProductCategoryField({
    super.key,
    required this.selectedCategoryId,
    required this.onChanged,
    this.currentCategoryName,
    this.currentCategoryIsActive = true,
    this.decoration,
  });

  final String? selectedCategoryId;

  /// Null disables the field (e.g. while saving).
  final ValueChanged<String?>? onChanged;

  /// Name of the product's existing category, used when it is archived or
  /// not yet loaded.
  final String? currentCategoryName;
  final bool currentCategoryIsActive;
  final InputDecoration? decoration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoriesAsync = ref.watch(activeProductCategoriesProvider);
    final categories = categoriesAsync.value ?? const [];
    final selectedId = selectedCategoryId;

    final items = <DropdownMenuItem<String?>>[
      const DropdownMenuItem<String?>(value: null, child: Text('No category')),
      for (final category in categories)
        DropdownMenuItem<String?>(
          value: category.id,
          child: Text(
            category.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      // Keep the current selection listed when it is archived or the list
      // has not loaded yet.
      if (selectedId != null &&
          categories.every((category) => category.id != selectedId))
        DropdownMenuItem<String?>(
          value: selectedId,
          child: Text(
            currentCategoryIsActive
                ? (currentCategoryName ?? 'Current category')
                : '${currentCategoryName ?? 'Current category'} (archived)',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
    ];

    final baseDecoration =
        decoration ??
        const InputDecoration(
          labelText: 'Category',
          prefixIcon: Icon(Icons.category_outlined),
        );

    return DropdownButtonFormField<String?>(
      key: ValueKey<String?>('category-$selectedId-${categories.length}'),
      initialValue: selectedId,
      isExpanded: true,
      decoration: baseDecoration.copyWith(
        helperText: categoriesAsync.isLoading && !categoriesAsync.hasValue
            ? 'Loading categories...'
            : null,
        errorText: categoriesAsync.hasError
            ? 'Categories could not be loaded. You can save without one.'
            : null,
        suffixIcon: categoriesAsync.hasError
            ? IconButton(
                tooltip: 'Retry loading categories',
                onPressed: () =>
                    ref.invalidate(activeProductCategoriesProvider),
                icon: const Icon(Icons.refresh_rounded),
              )
            : null,
      ),
      items: items,
      onChanged: onChanged,
    );
  }
}
