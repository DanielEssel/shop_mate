import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_radius.dart';
import '../../../../app/theme/app_spacing.dart';
import '../../../../app/theme/app_typography.dart';
import '../../domain/entities/customer.dart';
import '../providers/customers_provider.dart';
import '../widgets/customer_card.dart';
import '../widgets/customer_search_bar.dart';
import '../widgets/customer_summary_card.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_handleSearchChanged);
  }

  void _handleSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text.trim().toLowerCase();
    });
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleSearchChanged)
      ..dispose();

    super.dispose();
  }

  Future<void> _refresh() {
    return ref.read(customersProvider.notifier).refresh();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          'Customers',
          style: AppTypography.textTheme.titleLarge!.copyWith(
            fontWeight: FontWeight.w800,
            color: AppColors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh customers',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_rounded),
          ),
          const SizedBox(width: AppSpacing.xs),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await context.push<bool>('/customers/add');

          if (result == true && mounted) {
            await _refresh();
          }
        },
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add Customer'),
      ),
      body: customersAsync.when(
        loading: () => const _CustomersLoading(),
        error: (error, stackTrace) {
          return _CustomersError(
            message: error.toString(),
            onRetry: _refresh,
          );
        },
        data: (customers) {
          final filteredCustomers = _filterCustomers(customers);

          return RefreshIndicator(
            onRefresh: _refresh,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isDesktop = constraints.maxWidth >= 1000;

                return SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: EdgeInsets.all(
                    isDesktop
                        ? AppSpacing.xl
                        : AppSpacing.md,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _PageHeader(
                        customerCount: customers.length,
                        onAddCustomer: () async {
                          final result =
                              await context.push<bool>(
                            '/customers/add',
                          );

                          if (result == true && mounted) {
                            await _refresh();
                          }
                        },
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      _SummarySection(
                        customers: customers,
                        isDesktop: isDesktop,
                      ),

                      const SizedBox(height: AppSpacing.xl),

                      CustomerSearchBar(
                        controller: _searchController,
                      ),

                      const SizedBox(height: AppSpacing.lg),

                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Customers',
                              style: AppTypography
                                  .textTheme
                                  .headlineMedium!
                                  .copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                            ),
                          ),
                          Text(
                            '${filteredCustomers.length} ${filteredCustomers.length == 1 ? 'customer' : 'customers'}',
                            style: AppTypography
                                .textTheme
                                .bodySmall!
                                .copyWith(
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ],
                      ),

                      const SizedBox(height: AppSpacing.md),

                      if (filteredCustomers.isEmpty)
                        const _EmptyCustomers()
                      else if (isDesktop)
                        _DesktopCustomerGrid(
                          customers: filteredCustomers,
                        )
                      else
                        _MobileCustomerList(
                          customers: filteredCustomers,
                        ),

                      const SizedBox(height: 80),
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

  List<Customer> _filterCustomers(List<Customer> customers) {
    if (_searchQuery.isEmpty) {
      return customers;
    }

    return customers.where((customer) {
      final name = customer.name.toLowerCase();
      final phone = customer.phone?.toLowerCase() ?? '';
      final email = customer.email?.toLowerCase() ?? '';
      final address = customer.address?.toLowerCase() ?? '';

      return name.contains(_searchQuery) ||
          phone.contains(_searchQuery) ||
          email.contains(_searchQuery) ||
          address.contains(_searchQuery);
    }).toList();
  }
}

class _PageHeader extends StatelessWidget {
  const _PageHeader({
    required this.customerCount,
    required this.onAddCustomer,
  });

  final int customerCount;
  final VoidCallback onAddCustomer;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Customer Management',
                style: AppTypography.textTheme.headlineLarge!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                '$customerCount active customers in your shop',
                style: AppTypography.textTheme.bodyMedium!.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: onAddCustomer,
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Add Customer'),
        ),
      ],
    );
  }
}

class _SummarySection extends StatelessWidget {
  const _SummarySection({
    required this.customers,
    required this.isDesktop,
  });

  final List<Customer> customers;
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    final active = customers.where((customer) => customer.isActive).length;

    final withPhone = customers.where((customer) {
      return customer.phone != null &&
          customer.phone!.trim().isNotEmpty;
    }).length;

    final withEmail = customers.where((customer) {
      return customer.email != null &&
          customer.email!.trim().isNotEmpty;
    }).length;

    final cards = [
      CustomerSummaryCard(
        title: 'Total Customers',
        value: '${customers.length}',
        subtitle: 'Registered customers',
        icon: Icons.people_alt_outlined,
      ),
      CustomerSummaryCard(
        title: 'Active Customers',
        value: '$active',
        subtitle: 'Currently active',
        icon: Icons.person_outline_rounded,
      ),
      CustomerSummaryCard(
        title: 'Phone Contacts',
        value: '$withPhone',
        subtitle: 'Customers with phone',
        icon: Icons.phone_outlined,
      ),
      CustomerSummaryCard(
        title: 'Email Contacts',
        value: '$withEmail',
        subtitle: 'Customers with email',
        icon: Icons.email_outlined,
      ),
    ];

    if (isDesktop) {
      return GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: cards.length,
        gridDelegate:
            const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 4,
          crossAxisSpacing: AppSpacing.md,
          mainAxisSpacing: AppSpacing.md,
          childAspectRatio: 1.65,
        ),
        itemBuilder: (_, index) => cards[index],
      );
    }

    return SizedBox(
      height: 138,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: cards.length,
        separatorBuilder: (_, _) =>
            const SizedBox(width: AppSpacing.sm),
        itemBuilder: (_, index) {
          return SizedBox(
            width: 230,
            child: cards[index],
          );
        },
      ),
    );
  }
}

class _DesktopCustomerGrid extends StatelessWidget {
  const _DesktopCustomerGrid({
    required this.customers,
  });

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      gridDelegate:
          const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 430,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
        childAspectRatio: 2.25,
      ),
      itemBuilder: (context, index) {
        final customer = customers[index];

        return CustomerCard(
          customer: customer,
          onTap: () {
            context.push('/customers/${customer.id}');
          },
          onEdit: () {
            context.push('/customers/${customer.id}');
          },
          onDelete: () {
            _confirmDelete(context, customer);
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    Customer customer,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate customer?'),
          content: Text(
            'This will deactivate ${customer.name}. '
            'The customer will no longer appear in the active customer list.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                context
                    .findAncestorStateOfType<
                        _CustomersScreenState>()
                    ?._deleteCustomer(customer.id);
              },
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
  }
}

class _MobileCustomerList extends StatelessWidget {
  const _MobileCustomerList({
    required this.customers,
  });

  final List<Customer> customers;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: customers.length,
      separatorBuilder: (_, _) =>
          const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final customer = customers[index];

        return CustomerCard(
          customer: customer,
          onTap: () {
            context.push('/customers/${customer.id}');
          },
          onEdit: () {
            context.push('/customers/${customer.id}');
          },
          onDelete: () {
            _confirmDelete(context, customer);
          },
        );
      },
    );
  }

  void _confirmDelete(
    BuildContext context,
    Customer customer,
  ) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Deactivate customer?'),
          content: Text(
            'This will deactivate ${customer.name}.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                final state = context.findAncestorStateOfType<
                    _CustomersScreenState>();

                state?._deleteCustomer(customer.id);
              },
              child: const Text('Deactivate'),
            ),
          ],
        );
      },
    );
  }
}

class _EmptyCustomers extends StatelessWidget {
  const _EmptyCustomers();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        vertical: AppSpacing.xxl,
        horizontal: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.border,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.people_outline_rounded,
            size: 54,
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            'No customers found',
            style: AppTypography.textTheme.titleMedium!.copyWith(
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Try changing your search or add a new customer.',
            textAlign: TextAlign.center,
            style: AppTypography.textTheme.bodyMedium!.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomersLoading extends StatelessWidget {
  const _CustomersLoading();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }
}

class _CustomersError extends StatelessWidget {
  const _CustomersError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Unable to load customers',
              style: AppTypography.textTheme.titleMedium!.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message,
              textAlign: TextAlign.center,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.textTheme.bodySmall!.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

extension on _CustomersScreenState {
  Future<void> _deleteCustomer(String id) async {
    try {
      await ref
          .read(customersProvider.notifier)
          .deleteCustomer(id);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Customer deactivated successfully.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Unable to deactivate customer: $error'),
        ),
      );
    }
  }
}
