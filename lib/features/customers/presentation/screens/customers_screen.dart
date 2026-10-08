import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../core/ui/ui.dart';
import '../../../shop/presentation/providers/shop_provider.dart';
import '../../domain/entities/customer.dart';
import '../providers/customers_provider.dart';
import '../widgets/customer_card.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() {
    return ref.read(customersProvider.notifier).refresh();
  }

  Future<void> _addCustomer() async {
    final result = await context.push<bool>('/customers/add');

    if (result == true && mounted) {
      await _refresh();
    }
  }

  void _open(Customer customer) => context.push('/customers/${customer.id}');

  Future<void> _confirmDeactivate(Customer customer) async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Deactivate customer?',
      message:
          'This will deactivate ${customer.name}. The customer will no '
          'longer appear in the active customer list.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(customersProvider.notifier).deleteCustomer(customer.id);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Customer deactivated successfully.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to deactivate customer: $error')),
      );
    }
  }

  List<Customer> _filterCustomers(List<Customer> customers) {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return customers;

    return customers.where((customer) {
      final name = customer.name.toLowerCase();
      final phone = customer.phone?.toLowerCase() ?? '';
      final email = customer.email?.toLowerCase() ?? '';
      final address = customer.address?.toLowerCase() ?? '';

      return name.contains(query) ||
          phone.contains(query) ||
          email.contains(query) ||
          address.contains(query);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);
    // Deactivating a customer is deleting it: owner-only.
    final canDeactivate = ref.watch(
      shopAccessProvider.select(selectIsShopOwner),
    );
    final isCompact = Breakpoints.ofWindow(context).isCompact;

    return Scaffold(
      backgroundColor: AppColors.background,
      // Phones get the thumb-reachable button; wider layouts put it in the
      // page header.
      floatingActionButton: isCompact
          ? FloatingActionButton.extended(
              heroTag: 'customers_fab',
              onPressed: _addCustomer,
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Add Customer'),
            )
          : null,
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final horizontal = Breakpoints.pagePadding(
              constraints.maxWidth,
              maxWidth: ContentWidth.wide,
            );

            final header = Padding(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                isCompact ? AppSpacing.md : AppSpacing.xxl,
                horizontal,
                AppSpacing.xl,
              ),
              child: PageHeader(
                title: 'Customers',
                subtitle: 'People you sell to, and how to reach them',
                leading: pageHeaderLeading(context),
                actions: [
                  // Pull-to-refresh needs touch; mouse users get a button.
                  if (!isCompact)
                    IconButton(
                      tooltip: 'Refresh customers',
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  if (!isCompact)
                    PrimaryButton(
                      label: 'Add Customer',
                      icon: Icons.person_add_alt_1_rounded,
                      onPressed: _addCustomer,
                    ),
                ],
              ),
            );

            return customersAsync.when(
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: PageSkeleton(
                      padding: EdgeInsets.symmetric(horizontal: horizontal),
                    ),
                  ),
                ],
              ),
              error: (error, stackTrace) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  header,
                  Expanded(
                    child: ErrorState(
                      title: 'Unable to load customers.',
                      message: 'Check your connection and try again.',
                      onRetry: _refresh,
                    ),
                  ),
                ],
              ),
              data: (customers) => RefreshIndicator(
                onRefresh: _refresh,
                child: _buildContent(
                  customers,
                  header: header,
                  horizontal: horizontal,
                  isCompact: isCompact,
                  canDeactivate: canDeactivate,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildContent(
    List<Customer> customers, {
    required Widget header,
    required double horizontal,
    required bool isCompact,
    required bool canDeactivate,
  }) {
    final filtered = _filterCustomers(customers);

    final withPhone = customers
        .where((customer) => customer.phone?.trim().isNotEmpty ?? false)
        .length;
    final withEmail = customers
        .where((customer) => customer.email?.trim().isNotEmpty ?? false)
        .length;
    final noContact = customers
        .where((customer) => customerContactLabel(customer) == null)
        .length;

    ValueChanged<Customer>? onDeactivate = canDeactivate
        ? _confirmDeactivate
        : null;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(child: header),
        if (customers.isNotEmpty) ...[
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              0,
              horizontal,
              AppSpacing.xxl,
            ),
            sliver: SliverToBoxAdapter(
              child: MetricGrid(
                cards: [
                  MetricCard(
                    label: 'Customers',
                    value: '${customers.length}',
                    caption: 'Active customers',
                    icon: Icons.people_alt_outlined,
                    emphasized: true,
                  ),
                  MetricCard(
                    label: 'With Phone',
                    value: '$withPhone',
                    caption: 'Reachable by phone',
                    icon: Icons.phone_outlined,
                    tone: StatusTone.brand,
                  ),
                  MetricCard(
                    label: 'With Email',
                    value: '$withEmail',
                    caption: noContact == 0
                        ? 'Everyone has contact details'
                        : '$noContact without contact details',
                    captionTone: noContact == 0 ? null : StatusTone.warning,
                    icon: Icons.email_outlined,
                    tone: StatusTone.info,
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              horizontal,
              0,
              horizontal,
              AppSpacing.lg,
            ),
            sliver: SliverToBoxAdapter(
              child: AppSearchField(
                controller: _searchController,
                hintText: 'Search name, phone, email or address...',
                onChanged: (value) => setState(() => _searchQuery = value),
              ),
            ),
          ),
        ],
        SliverPadding(
          padding: EdgeInsets.fromLTRB(
            horizontal,
            0,
            horizontal,
            // Room for the floating button on phones.
            isCompact ? 96 : AppSpacing.xxxl,
          ),
          sliver: filtered.isEmpty
              ? SliverToBoxAdapter(
                  child: SurfaceCard(
                    child: customers.isEmpty
                        ? EmptyState(
                            icon: Icons.people_outline_rounded,
                            title: 'No customers yet',
                            message:
                                'Add customers to record credit sales and '
                                'keep their contacts at hand.',
                            actionLabel: 'Add Customer',
                            actionIcon: Icons.person_add_alt_1_rounded,
                            onAction: _addCustomer,
                          )
                        : const EmptyState(
                            icon: Icons.search_off_rounded,
                            title: 'No customers found',
                            message: 'Try a different name, phone or email.',
                          ),
                  ),
                )
              : SliverAdaptiveDataTable<Customer>(
                  rows: filtered,
                  onRowTap: _open,
                  compactRowBuilder: (context, customer) => CustomerCard(
                    customer: customer,
                    onTap: () => _open(customer),
                    onEdit: () => _open(customer),
                    onDelete: onDeactivate == null
                        ? null
                        : () => onDeactivate(customer),
                  ),
                  columns: _columns(onEdit: _open, onDeactivate: onDeactivate),
                ),
        ),
      ],
    );
  }

  static List<DataColumnSpec<Customer>> _columns({
    required ValueChanged<Customer> onEdit,
    required ValueChanged<Customer>? onDeactivate,
  }) {
    return [
      DataColumnSpec<Customer>(
        label: 'Customer',
        flex: 4,
        compare: (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        cell: (customer) => Row(
          children: [
            InitialAvatar(name: customer.name, size: 32),
            const SizedBox(width: AppSpacing.md),
            Flexible(
              child: Text(
                customer.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
            ),
            if (!customer.isActive) ...[
              const SizedBox(width: AppSpacing.sm),
              const StatusBadge(label: 'Inactive', tone: StatusTone.neutral),
            ],
          ],
        ),
      ),
      DataColumnSpec<Customer>(
        label: 'Phone',
        flex: 2,
        cell: (customer) => _muted(customer.phone),
      ),
      DataColumnSpec<Customer>(
        label: 'Email',
        flex: 3,
        cell: (customer) => _muted(customer.email),
      ),
      DataColumnSpec<Customer>(
        label: 'Address',
        flex: 3,
        visibleFrom: WindowSize.expanded,
        cell: (customer) => _muted(customer.address),
      ),
      DataColumnSpec<Customer>(
        label: '',
        flex: 1,
        numeric: true,
        cell: (customer) => CustomerActionsMenu(
          onEdit: () => onEdit(customer),
          onDelete: onDeactivate == null ? null : () => onDeactivate(customer),
        ),
      ),
    ];
  }

  static Widget _muted(String? value) {
    final trimmed = value?.trim();
    final missing = trimmed == null || trimmed.isEmpty;
    return Text(
      missing ? '—' : trimmed,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: missing ? AppColors.textMuted : AppColors.textSecondary,
      ),
    );
  }
}
