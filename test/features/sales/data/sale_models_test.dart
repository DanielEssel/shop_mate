import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/sales/data/models/sale_item_model.dart';
import 'package:shopmate/features/sales/data/models/sale_model.dart';
import 'package:shopmate/features/sales/domain/entities/sale_item.dart';
import 'package:shopmate/features/sales/presentation/utils/sale_discount_text.dart';

Map<String, Object?> _itemRow({
  Object? original = 10.0,
  Object? percentage = 10.0,
  Object? discount = 2.0,
}) => {
  'id': 'i1',
  'sale_id': 's1',
  'product_id': 'p1',
  'product_name': 'Rice 1kg',
  'quantity': 2,
  'unit_price': 9.0,
  'cost_price': 6.0,
  'subtotal': 18.0,
  'created_at': '2026-10-15T09:00:00+00:00',
  'original_unit_price': original,
  'discount_percentage': percentage,
  'discount_amount': discount,
};

Map<String, Object?> _saleRow({Object? discount = 2.0}) => {
  'id': 's1',
  'sale_number': 'SL-1',
  'total_amount': 18.0,
  'payment_method': 'cash',
  'amount_paid': 20.0,
  'change_amount': 2.0,
  'created_by': 'u1',
  'customer_id': null,
  'created_at': '2026-10-15T09:00:00+00:00',
  'discount_amount': discount,
};

void main() {
  test('reads the stored discount snapshots of a line', () {
    final item = SaleItemModel.fromJson(_itemRow());

    expect(item.unitPrice, 9.0);
    expect(item.subtotal, 18.0);
    expect(item.listUnitPrice, 10.0);
    expect(item.discountPercentage, 10.0);
    expect(item.discountAmount, 2.0);
    expect(item.isDiscounted, isTrue);
    // Profit uses the price actually charged.
    expect(item.profit, 6.0);
  });

  test('a line from before discounts reads as no discount', () {
    final item = SaleItemModel.fromJson(
      {..._itemRow()}
        ..remove('original_unit_price')
        ..remove('discount_percentage')
        ..remove('discount_amount'),
    );

    expect(item.listUnitPrice, 9.0);
    expect(item.discountAmount, 0);
    expect(item.isDiscounted, isFalse);
    expect(saleItemDiscountNote(item), isNull);
  });

  test('a line skipped by a running discount shows no discount', () {
    final item = SaleItemModel.fromJson(
      _itemRow(original: 9.0, percentage: 0, discount: 0),
    );
    expect(item.isDiscounted, isFalse);
    expect(saleItemDiscountNote(item), isNull);
  });

  test('reads the sale discount, and 0 when absent', () {
    expect(SaleModel.fromJson(_saleRow()).discountAmount, 2.0);
    expect(
      SaleModel.fromJson(
        {..._saleRow()}..remove('discount_amount'),
      ).discountAmount,
      0,
    );
  });

  group('receipt text and totals (stored values only)', () {
    test('a discounted line', () {
      expect(
        saleItemDiscountNote(SaleItemModel.fromJson(_itemRow())),
        'Was GHS 10.00 · 10% off (-GHS 2.00)',
      );
      expect(
        saleItemDiscountNote(
          SaleItemModel.fromJson(
            _itemRow(original: 2.5, percentage: 12.5, discount: 0.31),
          ),
        ),
        'Was GHS 2.50 · 12.5% off (-GHS 0.31)',
      );
    });

    test('subtotal before discount, discount and total add up', () {
      final sale = SaleModel.fromJson(_saleRow(discount: 2.31));
      final items = <SaleItem>[
        SaleItemModel.fromJson(_itemRow()),
        SaleItemModel.fromJson({
          ..._itemRow(original: 2.5, percentage: 12.5, discount: 0.31),
          'id': 'i2',
          'quantity': 1,
          'unit_price': 2.19,
          'subtotal': 2.19,
        }),
      ];
      final totals = ReceiptTotals.of(sale, items);

      expect(totals.subtotal, 22.50); // 18.00 + 2.19 + 2.00 + 0.31
      expect(totals.discount, 2.31);
      expect(totals.total, 18.0); // the sale's recorded total
      expect(totals.hasDiscount, isTrue);
    });

    test('a sale from before discounts: subtotal equals the total', () {
      final sale = SaleModel.fromJson(
        {..._saleRow()}
          ..remove('discount_amount')
          ..['total_amount'] = 18.0,
      );
      final item = SaleItemModel.fromJson(
        {..._itemRow()}
          ..remove('original_unit_price')
          ..remove('discount_percentage')
          ..remove('discount_amount'),
      );
      final totals = ReceiptTotals.of(sale, [item]);

      expect(totals.subtotal, 18.0);
      expect(totals.hasDiscount, isFalse);
    });
  });
}
