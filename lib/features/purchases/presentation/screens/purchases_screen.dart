import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain/entities/purchase.dart';
import '../providers/purchases_provider.dart';
import '../widgets/purchase_card.dart';
import '../widgets/purchase_summary.dart';

class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  final TextEditingController _searchController = TextEditingController();

  String _searchQuery = '';

  @override
  void initState() {
    super.initState();

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Purchase> _filterPurchases(List<Purchase> purchases) {
    if (_searchQuery.isEmpty) {
      return purchases;
    }

    return purchases.where((purchase) {
      final purchaseNumber =
          purchase.purchaseNumber.toLowerCase();

      final supplier =
          purchase.supplierName?.toLowerCase() ?? '';

      final phone =
          purchase.supplierPhone?.toLowerCase() ?? '';

      return purchaseNumber.contains(_searchQuery) ||
          supplier.contains(_searchQuery) ||
          phone.contains(_searchQuery);
    }).toList();
  }

  Future<void> _refresh() async {
    ref.invalidate(purchasesProvider);
    await ref.read(purchasesProvider.future);
  }

  @override
  Widget build(BuildContext context) {
    final purchasesAsync = ref.watch(purchasesProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: AppBar(
        title: const Text(
          'Purchases',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refresh,
            icon: const Icon(
              Icons.refresh_rounded,
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          context.push('/purchases/new');
        },
        icon: const Icon(
          Icons.add_shopping_cart_rounded,
        ),
        label: const Text(
          'New Purchase',
        ),
      ),
      body: purchasesAsync.when(
        loading: () {
          return const Center(
            child: CircularProgressIndicator(),
          );
        },
        error: (error, stackTrace) {
          return _PurchaseErrorState(
            error: error,
            onRetry: _refresh,
          );
        },
        data: (purchases) {
          return _buildContent(
            context,
            purchases,
          );
        },
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<Purchase> purchases,
  ) {
    if (purchases.isEmpty) {
      return const _EmptyPurchasesState();
    }

    final filteredPurchases =
        _filterPurchases(purchases);

    final totalPurchases = purchases.fold<double>(
      0,
      (sum, purchase) =>
          sum + purchase.totalAmount,
    );

    final totalPaid = purchases.fold<double>(
      0,
      (sum, purchase) =>
          sum + purchase.amountPaid,
    );

    final outstanding = purchases.fold<double>(
      0,
      (sum, purchase) =>
          sum + purchase.balance,
    );

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(
          16,
          16,
          16,
          110,
        ),
        children: [
          PurchaseSummary(
            totalPurchases: totalPurchases,
            totalPaid: totalPaid,
            outstanding: outstanding,
            transactionCount: purchases.length,
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText:
                  'Search purchase or supplier...',
              prefixIcon: const Icon(
                Icons.search_rounded,
              ),
              suffixIcon:
                  _searchQuery.isNotEmpty
                      ? IconButton(
                          tooltip: 'Clear',
                          onPressed: () {
                            _searchController.clear();
                          },
                          icon: const Icon(
                            Icons.clear_rounded,
                          ),
                        )
                      : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius:
                    BorderRadius.circular(16),
                borderSide: BorderSide(
                  color: Theme.of(context)
                      .colorScheme
                      .primary,
                ),
              ),
            ),
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Recent Purchases',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (_searchQuery.isNotEmpty)
                Text(
                  '${filteredPurchases.length} found',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (filteredPurchases.isEmpty)
            const _NoSearchResults()
          else
            ...filteredPurchases.map(
              (purchase) => Padding(
                padding:
                    const EdgeInsets.only(bottom: 10),
                child: PurchaseCard(
                  purchase: purchase,
                  onTap: () {
                    context.push(
                      '/purchases/${purchase.id}',
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EmptyPurchasesState
    extends StatelessWidget {
  const _EmptyPurchasesState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5F0),
                borderRadius:
                    BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.shopping_bag_outlined,
                size: 40,
                color: Color(0xFF087F5B),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'No purchases yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Purchases you record will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () {
                context.push('/purchases/new');
              },
              icon: const Icon(
                Icons.add_shopping_cart_rounded,
              ),
              label: const Text(
                'Create First Purchase',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoSearchResults
    extends StatelessWidget {
  const _NoSearchResults();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        vertical: 40,
        horizontal: 20,
      ),
      child: Column(
        children: [
          Icon(
            Icons.search_off_rounded,
            size: 44,
            color: Colors.grey.shade500,
          ),
          const SizedBox(height: 12),
          const Text(
            'No purchases found',
            style: TextStyle(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            'Try a different purchase number or supplier.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _PurchaseErrorState
    extends StatelessWidget {
  const _PurchaseErrorState({
    required this.error,
    required this.onRetry,
  });

  final Object error;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.error_outline_rounded,
              size: 52,
              color: Colors.redAccent,
            ),
            const SizedBox(height: 12),
            const Text(
              'Unable to load purchases',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey.shade600,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
