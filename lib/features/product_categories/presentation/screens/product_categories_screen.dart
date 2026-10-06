import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/product_category.dart';
import '../../domain/entities/product_category_exception.dart';
import '../../domain/entities/product_category_name.dart';
import '../../domain/entities/product_category_summary.dart';
import '../providers/product_category_providers.dart';

enum _CategoryView { active, archived }

/// Lists the shop's product categories. The owner can create, rename,
/// archive and restore them; other members see a read-only list. The
/// database enforces the owner-only rule.
class ProductCategoriesScreen extends ConsumerStatefulWidget {
  const ProductCategoriesScreen({super.key});

  @override
  ConsumerState<ProductCategoriesScreen> createState() =>
      _ProductCategoriesScreenState();
}

class _ProductCategoriesScreenState
    extends ConsumerState<ProductCategoriesScreen> {
  final _searchController = TextEditingController();

  _CategoryView _view = _CategoryView.active;
  String _query = '';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _query = _searchController.text.trim().toLowerCase());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
      );
  }

  /// Runs a category write with a busy state and refreshes dependent data.
  Future<void> _run(
    Future<void> Function() action, {
    required String success,
  }) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await action();
      if (!mounted) return;
      invalidateProductCategoryData(ref);
      _showMessage(success);
    } on ProductCategoryException catch (error) {
      if (mounted) _showMessage(error.message);
    } catch (_) {
      if (mounted) _showMessage(ProductCategoryErrorKind.saveFailed.message);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _create() async {
    final name = await _askName(title: 'New category', initialValue: '');
    if (name == null) return;
    await _run(
      () => ref.read(createProductCategoryProvider).call(name),
      success: 'Category created.',
    );
  }

  Future<void> _rename(ProductCategory category) async {
    final name = await _askName(
      title: 'Rename category',
      initialValue: category.name,
    );
    if (name == null || name.value == category.name) return;
    await _run(
      () => ref.read(renameProductCategoryProvider).call(category.id, name),
      success: 'Category renamed.',
    );
  }

  Future<void> _archive(ProductCategorySummary summary) async {
    final category = summary.category;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Archive ${category.name}?'),
        content: const Text(
          "It won't be offered for new products. Products already in this "
          'category keep it, and you can restore it later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(
      () => ref
          .read(setProductCategoryActiveProvider)
          .call(category.id, isActive: false),
      success: 'Category archived.',
    );
  }

  Future<void> _restore(ProductCategory category) {
    return _run(
      () => ref
          .read(setProductCategoryActiveProvider)
          .call(category.id, isActive: true),
      success: 'Category restored.',
    );
  }

  Future<ProductCategoryName?> _askName({
    required String title,
    required String initialValue,
  }) {
    return showDialog<ProductCategoryName>(
      context: context,
      builder: (_) =>
          _CategoryNameDialog(title: title, initialValue: initialValue),
    );
  }

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(productCategoriesProvider);
    final isOwner = ref.watch(
      shopAccessProvider.select((access) => access.value?.isOwner ?? false),
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(
          'Product Categories',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(2),
          child: _isSaving
              ? const LinearProgressIndicator(minHeight: 2)
              : const SizedBox(height: 2),
        ),
      ),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= 900;

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(productCategoriesProvider);
                try {
                  await ref.read(productCategoriesProvider.future);
                } catch (_) {
                  // Shown inline by the error state.
                }
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  isDesktop ? AppSpacing.xl : AppSpacing.md,
                  isDesktop ? AppSpacing.lg : AppSpacing.sm,
                  isDesktop ? AppSpacing.xl : AppSpacing.md,
                  AppSpacing.xxxl,
                ),
                children: [
                  Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _Header(
                            isOwner: isOwner,
                            onCreate: _isSaving ? null : _create,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search categories',
                              prefixIcon: const Icon(Icons.search_rounded),
                              suffixIcon: _query.isEmpty
                                  ? null
                                  : IconButton(
                                      tooltip: 'Clear search',
                                      onPressed: _searchController.clear,
                                      icon: const Icon(Icons.clear_rounded),
                                    ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Wrap(
                            spacing: AppSpacing.sm,
                            children: [
                              ChoiceChip(
                                label: const Text('Active'),
                                selected: _view == _CategoryView.active,
                                onSelected: (_) => setState(
                                  () => _view = _CategoryView.active,
                                ),
                              ),
                              ChoiceChip(
                                label: const Text('Archived'),
                                selected: _view == _CategoryView.archived,
                                onSelected: (_) => setState(
                                  () => _view = _CategoryView.archived,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          categoriesAsync.when(
                            loading: () => const Padding(
                              padding: EdgeInsets.symmetric(
                                vertical: AppSpacing.section,
                              ),
                              child: Center(
                                child: CircularProgressIndicator(
                                  semanticsLabel: 'Loading categories',
                                ),
                              ),
                            ),
                            error: (error, _) => _StateCard(
                              icon: Icons.error_outline_rounded,
                              title: 'Unable to load categories',
                              message: error is ProductCategoryException
                                  ? error.message
                                  : ProductCategoryErrorKind.loadFailed.message,
                              action: OutlinedButton.icon(
                                onPressed: () =>
                                    ref.invalidate(productCategoriesProvider),
                                icon: const Icon(Icons.refresh_rounded),
                                label: const Text('Retry'),
                              ),
                            ),
                            data: (summaries) => _CategoryList(
                              summaries: summaries,
                              view: _view,
                              query: _query,
                              isOwner: isOwner,
                              isSaving: _isSaving,
                              onCreate: _create,
                              onClearSearch: _searchController.clear,
                              onRename: (summary) => _rename(summary.category),
                              onArchive: _archive,
                              onRestore: (summary) =>
                                  _restore(summary.category),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.isOwner, required this.onCreate});

  final bool isOwner;
  final VoidCallback? onCreate;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: AppSpacing.md,
      runSpacing: AppSpacing.md,
      children: [
        Text(
          isOwner
              ? 'Organise your products into your own categories.'
              : 'Only the shop owner can manage categories.',
          style: AppTypography.textTheme.bodyMedium!.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
        if (isOwner)
          FilledButton.icon(
            onPressed: onCreate,
            icon: const Icon(Icons.add_rounded),
            label: const Text('New category'),
          ),
      ],
    );
  }
}

class _CategoryList extends StatelessWidget {
  const _CategoryList({
    required this.summaries,
    required this.view,
    required this.query,
    required this.isOwner,
    required this.isSaving,
    required this.onCreate,
    required this.onClearSearch,
    required this.onRename,
    required this.onArchive,
    required this.onRestore,
  });

  final List<ProductCategorySummary> summaries;
  final _CategoryView view;
  final String query;
  final bool isOwner;
  final bool isSaving;
  final VoidCallback onCreate;
  final VoidCallback onClearSearch;
  final ValueChanged<ProductCategorySummary> onRename;
  final ValueChanged<ProductCategorySummary> onArchive;
  final ValueChanged<ProductCategorySummary> onRestore;

  @override
  Widget build(BuildContext context) {
    final inView = summaries
        .where(
          (summary) =>
              summary.category.isActive == (view == _CategoryView.active),
        )
        .toList(growable: false);
    final results = query.isEmpty
        ? inView
        : inView
              .where(
                (summary) =>
                    summary.category.name.toLowerCase().contains(query),
              )
              .toList(growable: false);

    if (inView.isEmpty) {
      return view == _CategoryView.active
          ? _StateCard(
              icon: Icons.category_outlined,
              title: 'No categories yet',
              message:
                  'Categories help you organise and filter your products. '
                  'Products can also have no category.',
              action: isOwner
                  ? FilledButton.icon(
                      onPressed: isSaving ? null : onCreate,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('New category'),
                    )
                  : null,
            )
          : const _StateCard(
              icon: Icons.inventory_2_outlined,
              title: 'No archived categories',
              message: 'Categories you archive will appear here.',
            );
    }

    if (results.isEmpty) {
      return _StateCard(
        icon: Icons.search_off_rounded,
        title: 'No categories found',
        message: 'No categories match your search.',
        action: OutlinedButton(
          onPressed: onClearSearch,
          child: const Text('Clear search'),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final summary in results) ...[
          _CategoryTile(
            summary: summary,
            isOwner: isOwner,
            enabled: !isSaving,
            onRename: () => onRename(summary),
            onArchive: () => onArchive(summary),
            onRestore: () => onRestore(summary),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ],
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.summary,
    required this.isOwner,
    required this.enabled,
    required this.onRename,
    required this.onArchive,
    required this.onRestore,
  });

  final ProductCategorySummary summary;
  final bool isOwner;
  final bool enabled;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final category = summary.category;
    final count = summary.activeProductCount;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.category_outlined, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  category.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.textTheme.titleSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count ${count == 1 ? 'product' : 'products'}'
                  '${category.isActive ? '' : ' · Archived'}',
                  style: AppTypography.textTheme.bodySmall!.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (isOwner)
            PopupMenuButton<String>(
              tooltip: 'Actions for ${category.name}',
              enabled: enabled,
              onSelected: (action) {
                switch (action) {
                  case 'rename':
                    onRename();
                  case 'archive':
                    onArchive();
                  case 'restore':
                    onRestore();
                }
              },
              itemBuilder: (_) => [
                const PopupMenuItem(value: 'rename', child: Text('Rename')),
                if (category.isActive)
                  const PopupMenuItem(value: 'archive', child: Text('Archive'))
                else
                  const PopupMenuItem(value: 'restore', child: Text('Restore')),
              ],
            ),
        ],
      ),
    );
  }
}

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 44, color: AppColors.textSecondary),
          const SizedBox(height: AppSpacing.md),
          Text(
            title,
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          if (action case final action?) ...[
            const SizedBox(height: AppSpacing.lg),
            action,
          ],
        ],
      ),
    );
  }
}

/// Asks for a category name; returns it validated, or null on Cancel.
class _CategoryNameDialog extends StatefulWidget {
  const _CategoryNameDialog({required this.title, required this.initialValue});

  final String title;
  final String initialValue;

  @override
  State<_CategoryNameDialog> createState() => _CategoryNameDialogState();
}

class _CategoryNameDialogState extends State<_CategoryNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(ProductCategoryName(_controller.text));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _save(),
          decoration: const InputDecoration(labelText: 'Category name'),
          validator: (value) => ProductCategoryName.isValid(value ?? '')
              ? null
              : ProductCategoryErrorKind.invalidName.message,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
