import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/more/presentation/screens/more_screen.dart';
import 'package:shopmate/features/suppliers/domain/entities/supplier.dart';
import 'package:shopmate/features/suppliers/domain/repositories/supplier_repository.dart';
import 'package:shopmate/features/suppliers/presentation/providers/supplier_providers.dart';
import 'package:shopmate/features/suppliers/presentation/screens/add_supplier_screen.dart';
import 'package:shopmate/features/suppliers/presentation/screens/edit_supplier_screen.dart';
import 'package:shopmate/features/suppliers/presentation/screens/supplier_details_screen.dart';
import 'package:shopmate/features/suppliers/presentation/screens/suppliers_screen.dart';

Supplier supplier({
  required String id,
  required String name,
  bool isActive = true,
  String? phone,
  String? email,
  String? address,
  String? notes,
}) {
  return Supplier(
    id: id,
    shopId: 'shop-1',
    name: name,
    isActive: isActive,
    phone: phone,
    email: email,
    address: address,
    notes: notes,
    createdBy: 'user-1',
    createdAt: DateTime.utc(2026, 10, 1, 9, 30),
    updatedAt: DateTime.utc(2026, 10, 2, 14, 5),
  );
}

/// The database error for a second active supplier with the same name.
PostgrestException duplicateNameError() {
  return const PostgrestException(
    message:
        'duplicate key value violates unique constraint '
        '"suppliers_shop_active_name_uidx"',
    code: '23505',
    details: 'Key (shop_id, lower(btrim(name)))=(…) already exists.',
  );
}

/// In-memory stand-in for the supplier repository. Mirrors the real
/// contract: active-only unless includeInactive, ordered by name.
class FakeSupplierRepository implements SupplierRepository {
  FakeSupplierRepository(List<Supplier> initial) : suppliers = [...initial];

  final List<Supplier> suppliers;
  final listRequests = <bool>[];

  /// Thrown by the next list read, then cleared.
  Object? nextListError;

  /// Returned by the next list read instead of data, then cleared.
  Completer<List<Supplier>>? pendingList;

  /// Thrown by every write while set.
  Object? writeError;

  final createdCalls = <Map<String, Object?>>[];
  final updateCalls = <Map<String, Object?>>[];
  int _nextId = 1;

  @override
  Future<List<Supplier>> getSuppliers({bool includeInactive = false}) async {
    listRequests.add(includeInactive);
    final pending = pendingList;
    if (pending != null) {
      pendingList = null;
      return pending.future;
    }
    final error = nextListError;
    if (error != null) {
      nextListError = null;
      throw error;
    }

    return (suppliers.where((s) => includeInactive || s.isActive).toList()
      ..sort((a, b) => a.name.compareTo(b.name)));
  }

  @override
  Future<Supplier> getSupplierById(String id) async {
    return suppliers.firstWhere((s) => s.id == id);
  }

  @override
  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    createdCalls.add({
      'name': name,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
    });
    final error = writeError;
    if (error != null) throw error;

    final created = supplier(
      id: 'new-${_nextId++}',
      name: name,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
    suppliers.add(created);
    return created;
  }

  @override
  Future<Supplier> updateSupplier({
    required String id,
    required String name,
    required bool isActive,
    String? phone,
    String? email,
    String? address,
    String? notes,
  }) async {
    updateCalls.add({
      'id': id,
      'name': name,
      'isActive': isActive,
      'phone': phone,
      'email': email,
      'address': address,
      'notes': notes,
    });
    final error = writeError;
    if (error != null) throw error;

    final index = suppliers.indexWhere((s) => s.id == id);
    final updated = supplier(
      id: id,
      name: name,
      isActive: isActive,
      phone: phone,
      email: email,
      address: address,
      notes: notes,
    );
    suppliers[index] = updated;
    return updated;
  }
}

/// Same supplier routes as the app router, plus More for navigation tests.
GoRouter supplierTestRouter(String initialLocation) {
  return GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/more', builder: (context, state) => const MoreScreen()),
      GoRoute(
        path: '/suppliers',
        builder: (context, state) => const SuppliersScreen(),
        routes: [
          GoRoute(
            path: 'new',
            builder: (context, state) => const AddSupplierScreen(),
          ),
          GoRoute(
            path: ':supplierId',
            builder: (context, state) => SupplierDetailsScreen(
              supplierId: state.pathParameters['supplierId']!,
            ),
            routes: [
              GoRoute(
                path: 'edit',
                builder: (context, state) => EditSupplierScreen(
                  supplierId: state.pathParameters['supplierId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

void disableFontFetching() {
  GoogleFonts.config.allowRuntimeFetching = false;
}

/// Pumps the app at [location] with [repository] behind the real providers.
Future<GoRouter> pumpSupplierApp(
  WidgetTester tester,
  FakeSupplierRepository repository, {
  String location = '/suppliers',
  Size size = const Size(420, 2400),
  bool settle = true,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  final router = supplierTestRouter(location);
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      // Riverpod retries failed providers by default; tests hold errors.
      retry: (_, _) => null,
      overrides: [supplierRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp.router(routerConfig: router),
    ),
  );
  if (settle) await tester.pumpAndSettle();

  return router;
}
