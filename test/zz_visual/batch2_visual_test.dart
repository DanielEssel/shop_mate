// TEMPORARY visual-review renders.
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/customers/domain/entities/customer.dart';
import 'package:shopmate/features/customers/presentation/providers/customers_provider.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding.dart';
import 'package:shopmate/features/shop/domain/entities/shop_branding_result.dart';
import 'package:shopmate/features/shop/presentation/providers/shop_branding_providers.dart';
import 'package:shopmate/features/suppliers/presentation/providers/supplier_providers.dart';

import '../features/suppliers/presentation/supplier_test_harness.dart';
import 'visual_harness.dart';

const _customers = [
  Customer(
    id: 'c1',
    name: 'Ama Mensah',
    phone: '0241234567',
    email: 'ama@mail.com',
    address: 'Adum, Kumasi',
  ),
  Customer(id: 'c2', name: 'Kwabena Owusu', phone: '0559876543'),
  Customer(
    id: 'c3',
    name: 'Efua Sarpong',
    email: 'efua.sarpong@example.com',
    address: 'Osu, Accra',
  ),
  Customer(id: 'c4', name: 'Yaw Boateng'),
  Customer(
    id: 'c5',
    name: 'Akosua Darko-Appiah Enterprises',
    phone: '0201112233',
    address: 'Kaneshie Market, Accra',
  ),
];

final _suppliers = [
  supplier(
    id: 's1',
    name: 'Kumasi Wholesale',
    phone: '0240000001',
    email: 'orders@kw.example',
    address: 'Kumasi Central Market',
  ),
  supplier(
    id: 's2',
    name: 'Accra Beverages Ltd',
    phone: '0302123456',
    address: 'Spintex Road',
  ),
  supplier(id: 's3', name: 'Tema Foods', email: 'sales@temafoods.example'),
  supplier(
    id: 's4',
    name: 'Makola Traders',
    isActive: false,
    phone: '0277000111',
  ),
];

class _Branding extends ShopBrandingNotifier {
  @override
  Future<ShopBrandingResult?> build() async => const ShopBrandingResult(
    branding: ShopBranding(
      shopId: 'shop-1',
      name: "Danny's Shop",
      phone: '0244000000',
    ),
  );
}

class _Customers extends CustomersNotifier {
  @override
  Future<List<Customer>> build() async => _customers;
}

void main() {
  setUpAll(loadFonts);

  final sizes = {
    'phone': phone,
    'small': smallPhone,
    'tablet': tablet,
    'desktop': desktop,
  };

  for (final entry in sizes.entries) {
    testWidgets('customers ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/customers',
        extra: [customersProvider.overrideWith(_Customers.new)],
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'customers_${entry.key}');
    });
    testWidgets('suppliers ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/suppliers',
        extra: [
          suppliersByStatusProvider.overrideWith(
            (ref, filter) async => [
              for (final s in _suppliers)
                if (filter == SupplierStatusFilter.all ||
                    s.isActive == (filter == SupplierStatusFilter.active))
                  s,
            ],
          ),
        ],
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'suppliers_${entry.key}');
    });
    testWidgets('settings ${entry.key}', (tester) async {
      await pumpVisualApp(
        tester,
        size: entry.value,
        location: '/settings',
        defaultBranding: false,
        extra: [shopBrandingProvider.overrideWith(_Branding.new)],
      );
      expect(tester.takeException(), isNull);
      await shoot(tester, 'settings_${entry.key}');
    });
  }
  testWidgets('settings staff phone', (tester) async {
    await pumpVisualApp(
      tester,
      size: phone,
      location: '/settings',
      role: 'staff',
      defaultBranding: false,
      extra: [shopBrandingProvider.overrideWith(_Branding.new)],
    );
    await shoot(tester, 'settings_staff_phone');
  });
}
