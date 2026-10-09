import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
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
    final confirmed = await showConfirmDialog(
      context,
      title: 'Archive ${category.name}?',
      message:
          "It won't be offered for new products. Products already in this "
          'category keep it, and you can restore it later.',
      confirmLabel: 'Archive',
    );
    if (!confirmed) return;
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
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final horizontal = Breakpoints.pagePadding(
              width,
              maxWidth: ContentWidth.standard,
            );

            SliverPadding boxed(Widget child, {double bottom = 0}) {
              return SliverPadding(
                padding: EdgeInsets.fromLTRB(horizontal, 0, horizontal, bottom),
                sliver: SliverToBoxAdapter(child: child),
              );
            }

            return RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(productCategoriesProvider);
                try {
                  await ref.read(productCategoriesProvider.future);
                } catch (_) {
                  // Shown inline by the error state.
                }
              },
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: EdgeInsets.fromLTRB(
                      horizontal,
                      Breakpoints.of(width).isCompact
                          ? AppSpacing.md
                          : AppSpacing.xxl,
                      horizontal,
                      AppSpacing.xl,
                    ),
                    sliver: SliverToBoxAdapter(
                      child: PageHeader(
                        title: 'Product Categories',
                        subtitle: isOwner
                            ? 'Organise your products into your own categories.'
                            : 'Only the shop owner can manage categories.',
                        leading: pageHeaderLeading(context),
                        actions: [
                          if (isOwner)
                            PrimaryButton(
                              label: 'New category',
                              icon: Icons.add_rounded,
                              onPressed: _isSaving ? null : _create,
                            ),
                        ],
                      ),
                    ),
                  ),
                  // A thin bar while a change is being saved.
                  boxed(
                    SizedBox(
                      height: 2,
                      child: _isSaving
                          ? const LinearProgressIndicator(minHeight: 2)
                          : null,
                    ),
                    bottom: AppSpacing.sm,
                  ),
                  boxed(
                    AppSearchField(
                      controller: _searchController,
                      hintText: 'Search categories',
                      onChanged: (_) {},
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: FilterChipBar(
                      padding: EdgeInsets.fromLTRB(
                        horizontal,
                        AppSpacing.md,
                        horizontal,
                        AppSpacing.lg,
                      ),
                      children: [
                        AppFilterChip(
                          label: 'Active',
                          selected: _view == _CategoryView.active,
                          onSelected: () =>
                              setState(() => _view = _CategoryView.active),
                        ),
                        AppFilterChip(
                          label: 'Archived',
                          selected: _view == _CategoryView.archived,
                          onSelected: () =>
                              setState(() => _view = _CategoryView.archived),
                        ),
                      ],
                    ),
                  ),
                  ...categoriesAsync.when(
                    loading: () => [
                      boxed(
                        Semantics(
                          container: true,
                          label: 'Loading categories',
                          child: const ExcludeSemantics(
                            child: SkeletonList(rows: 4),
                          ),
                        ),
                      ),
                    ],
                    error: (error, _) => [
                      boxed(
                        SurfaceCard(
                          child: ErrorState(
                            compact: true,
                            icon: Icons.error_outline_rounded,
                            title: 'Unable to load categories',
                            message: error is ProductCategoryException
                                ? error.message
                                : ProductCategoryErrorKind.loadFailed.message,
                            retryLabel: 'Retry',
                            onRetry: () =>
                                ref.invalidate(productCategoriesProvider),
                          ),
                        ),
                      ),
                    ],
                    data: (summaries) => _categorySlivers(
                      summaries,
                      horizontal: horizontal,
                      isOwner: isOwner,
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

  List<Widget> _categorySlivers(
    List<ProductCategorySummary> summaries, {
    required double horizontal,
    required bool isOwner,
  }) {
    final inView = summaries
        .where(
          (summary) =>
              summary.category.isActive == (_view == _CategoryView.active),
        )
        .toList(growable: false);
    final results = _query.isEmpty
        ? inView
        : inView
              .where(
                (summary) =>
                    summary.category.name.toLowerCase().contains(_query),
              )
              .toList(growable: false);

    SliverPadding message(Widget child) {
      return SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          0,
          horizontal,
          AppSpacing.xxxl,
        ),
        sliver: SliverToBoxAdapter(child: SurfaceCard(child: child)),
      );
    }

    if (inView.isEmpty) {
      return [
        message(
          _view == _CategoryView.active
              ? EmptyState(
                  icon: Icons.category_outlined,
                  title: 'No categories yet',
                  message:
                      'Categories help you organise and filter your products. '
                      'Products can also have no category.',
                  actions: isOwner
                      ? [
                          FilledButton.icon(
                            onPressed: _isSaving ? null : _create,
                            icon: const Icon(Icons.add_rounded),
                            label: const Text('New category'),
                          ),
                        ]
                      : null,
                )
              : const EmptyState(
                  icon: Icons.inventory_2_outlined,
                  title: 'No archived categories',
                  message: 'Categories you archive will appear here.',
                ),
        ),
      ];
    }

    if (results.isEmpty) {
      return [
        message(
          EmptyState(
            icon: Icons.search_off_rounded,
            title: 'No categories found',
            message: 'No categories match your search.',
            actions: [
              OutlinedButton(
                onPressed: _searchController.clear,
                child: const Text('Clear search'),
              ),
            ],
          ),
        ),
      ];
    }

    Widget? menu(ProductCategorySummary summary) {
      if (!isOwner) return null;
      return _CategoryMenu(
        category: summary.category,
        enabled: !_isSaving,
        onRename: () => _rename(summary.category),
        onArchive: () => _archive(summary),
        onRestore: () => _restore(summary.category),
      );
    }

    return [
      SliverPadding(
        padding: EdgeInsets.fromLTRB(
          horizontal,
          0,
          horizontal,
          AppSpacing.xxxl,
        ),
        sliver: SliverAdaptiveDataTable<ProductCategorySummary>(
          rows: results,
          compactRowBuilder: (context, summary) =>
              _CategoryRow(summary: summary, menu: menu(summary)),
          columns: [
            DataColumnSpec<ProductCategorySummary>(
              label: 'Category',
              flex: 5,
              compare: (a, b) => a.category.name.toLowerCase().compareTo(
                b.category.name.toLowerCase(),
              ),
              cell: (summary) => Row(
                children: [
                  const IconTile(icon: Icons.category_outlined, size: 32),
                  const SizedBox(width: AppSpacing.md),
                  Flexible(
                    child: Text(
                      summary.category.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
            DataColumnSpec<ProductCategorySummary>(
              label: 'Products',
              flex: 2,
              numeric: true,
              compare: (a, b) =>
                  a.activeProductCount.compareTo(b.activeProductCount),
              cell: (summary) => Text(
                _productCount(summary.activeProductCount),
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
            DataColumnSpec<ProductCategorySummary>(
              label: 'Status',
              flex: 2,
              cell: (summary) => Align(
                alignment: Alignment.centerLeft,
                child: _StatusBadge(isActive: summary.category.isActive),
              ),
            ),
            if (isOwner)
              DataColumnSpec<ProductCategorySummary>(
                label: '',
                flex: 1,
                numeric: true,
                cell: (summary) => menu(summary)!,
              ),
          ],
        ),
      ),
    ];
  }
}

String _productCount(int count) {
  return '$count ${count == 1 ? 'product' : 'products'}';
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.isActive});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return isActive
        ? const StatusBadge(
            label: 'Active',
            tone: StatusTone.success,
            icon: Icons.check_circle_outline_rounded,
          )
        : const StatusBadge(
            label: 'Archived',
            tone: StatusTone.neutral,
            icon: Icons.inventory_2_outlined,
          );
  }
}

/// A category on phones: name, product count and the owner's actions.
class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.summary, this.menu});

  final ProductCategorySummary summary;
  final Widget? menu;

  @override
  Widget build(BuildContext context) {
    final category = summary.category;
    final menu = this.menu;

    return ListRow(
      title: category.name,
      titleMaxLines: 2,
      details: [
        '${_productCount(summary.activeProductCount)}'
            '${category.isActive ? '' : ' · Archived'}',
      ],
      leading: const IconTile(icon: Icons.category_outlined),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        menu == null ? AppSpacing.lg : AppSpacing.xs,
        AppSpacing.md,
      ),
      trailing: menu,
    );
  }
}

/// Owner-only: rename, and archive or restore.
class _CategoryMenu extends StatelessWidget {
  const _CategoryMenu({
    required this.category,
    required this.enabled,
    required this.onRename,
    required this.onArchive,
    required this.onRestore,
  });

  final ProductCategory category;
  final bool enabled;
  final VoidCallback onRename;
  final VoidCallback onArchive;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Actions for ${category.name}',
      enabled: enabled,
      icon: const Icon(Icons.more_vert_rounded, color: AppColors.textSecondary),
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
        const PopupMenuItem(
          value: 'rename',
          child: ListTile(
            leading: Icon(Icons.edit_outlined),
            title: Text('Rename'),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        if (category.isActive)
          const PopupMenuItem(
            value: 'archive',
            child: ListTile(
              leading: Icon(Icons.inventory_2_outlined),
              title: Text('Archive'),
              contentPadding: EdgeInsets.zero,
            ),
          )
        else
          const PopupMenuItem(
            value: 'restore',
            child: ListTile(
              leading: Icon(Icons.unarchive_outlined),
              title: Text('Restore'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
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
      content: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: 320, maxWidth: 420),
        child: Form(
          key: _formKey,
          // The counter shows the length the validator checks (trimmed,
          // counted by character) without capping what can be typed.
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final length = _controller.text.trim().runes.length;
              final over = length > ProductCategoryName.maxLength;

              return TextFormField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: 'Category name',
                  prefixIcon: const Icon(Icons.category_outlined),
                  counterText: '$length / ${ProductCategoryName.maxLength}',
                  counterStyle: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: over ? AppColors.danger : AppColors.textMuted,
                  ),
                ),
                validator: (value) => ProductCategoryName.isValid(value ?? '')
                    ? null
                    : ProductCategoryErrorKind.invalidName.message,
              );
            },
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(
        AppSpacing.xxl,
        0,
        AppSpacing.xxl,
        AppSpacing.xl,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
