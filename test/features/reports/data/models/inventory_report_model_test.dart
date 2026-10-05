import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/reports/data/models/inventory_report_model.dart';

Map<String, Object?> _numberRow() {
  return {
    'total_products': 5,
    'total_units': 19,
    'inventory_cost_value': 29.96,
    'potential_selling_value': 46.5,
    'expected_gross_profit': 16.54,
    'low_stock_count': 3,
    'out_of_stock_count': 1,
    'units_purchased': 20,
    'units_sold': 6,
  };
}

Map<String, Object?> _stringRow() {
  return {
    'total_products': '5',
    'total_units': '19',
    'inventory_cost_value': '29.96',
    'potential_selling_value': '46.50',
    'expected_gross_profit': '16.54',
    'low_stock_count': '3',
    'out_of_stock_count': '1',
    'units_purchased': '20',
    'units_sold': '6',
  };
}

void main() {
  test('parses a valid RPC row with numeric values as numbers', () {
    final report = InventoryReportModel.fromRow(_numberRow());

    expect(report.totalProducts, 5);
    expect(report.totalUnits, 19);
    expect(report.inventoryCostValue, 29.96);
    expect(report.potentialSellingValue, 46.5);
    expect(report.expectedGrossProfit, 16.54);
    expect(report.lowStockCount, 3);
    expect(report.outOfStockCount, 1);
    expect(report.unitsPurchased, 20);
    expect(report.unitsSold, 6);
  });

  test('parses numeric values returned as strings', () {
    final report = InventoryReportModel.fromRow(_stringRow());

    expect(report.totalProducts, 5);
    expect(report.totalUnits, 19);
    expect(report.inventoryCostValue, 29.96);
    expect(report.potentialSellingValue, 46.5);
    expect(report.expectedGrossProfit, 16.54);
    expect(report.lowStockCount, 3);
    expect(report.outOfStockCount, 1);
    expect(report.unitsPurchased, 20);
    expect(report.unitsSold, 6);
  });

  test('passes database values through unchanged', () {
    final report = InventoryReportModel.fromRow({
      ..._numberRow(),
      // Deliberately inconsistent: the model must not recalculate profit.
      'expected_gross_profit': 99.99,
    });

    expect(report.expectedGrossProfit, 99.99);
  });

  test('parses an empty-shop row of zeros', () {
    final report = InventoryReportModel.fromRow({
      for (final field in _numberRow().keys) field: 0,
    });

    expect(report.totalProducts, 0);
    expect(report.inventoryCostValue, 0);
    expect(report.unitsSold, 0);
  });

  for (final field in _numberRow().keys) {
    test('rejects a missing $field', () {
      final row = _numberRow()..remove(field);

      expect(
        () => InventoryReportModel.fromRow(row),
        throwsA(isA<FormatException>()),
      );
    });

    test('rejects a null $field', () {
      final row = _numberRow()..[field] = null;

      expect(
        () => InventoryReportModel.fromRow(row),
        throwsA(isA<FormatException>()),
      );
    });
  }

  group('rejects malformed money values', () {
    for (final value in <Object>['abc', '', 'NaN', 'Infinity', true]) {
      test('inventory_cost_value = $value', () {
        final row = _numberRow()..['inventory_cost_value'] = value;

        expect(
          () => InventoryReportModel.fromRow(row),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('non-finite number', () {
      final row = _numberRow()..['expected_gross_profit'] = double.nan;

      expect(
        () => InventoryReportModel.fromRow(row),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('rejects malformed counts and unit totals', () {
    for (final value in <Object>['abc', '', '1.5', 1.5, true]) {
      test('total_units = $value', () {
        final row = _numberRow()..['total_units'] = value;

        expect(
          () => InventoryReportModel.fromRow(row),
          throwsA(isA<FormatException>()),
        );
      });
    }

    test('low_stock_count as fractional string', () {
      final row = _numberRow()..['low_stock_count'] = '2.5';

      expect(
        () => InventoryReportModel.fromRow(row),
        throwsA(isA<FormatException>()),
      );
    });
  });
}
