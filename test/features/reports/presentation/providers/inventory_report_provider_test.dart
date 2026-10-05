import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/reports/data/models/inventory_report_model.dart';
import 'package:shopmate/features/reports/domain/entities/business_performance.dart';
import 'package:shopmate/features/reports/domain/entities/inventory_report.dart';
import 'package:shopmate/features/reports/domain/entities/report_date_range.dart';
import 'package:shopmate/features/reports/domain/repositories/report_repository.dart';
import 'package:shopmate/features/reports/presentation/providers/reports_provider.dart';

class _FakeReportRepository implements ReportRepository {
  int inventoryReads = 0;
  int stockUnits = 19;

  @override
  Future<InventoryReport> getInventoryReport() async {
    inventoryReads++;
    return InventoryReportModel(
      totalProducts: 5,
      totalUnits: stockUnits,
      inventoryCostValue: 29.96,
      potentialSellingValue: 46.5,
      expectedGrossProfit: 16.54,
      lowStockCount: 3,
      outOfStockCount: 1,
      unitsPurchased: 20,
      unitsSold: 6,
    );
  }

  @override
  Future<BusinessPerformance> getBusinessPerformance(ReportDateRange range) =>
      throw UnimplementedError();
}

void main() {
  test(
    'provider resolves the report through the use case and repository',
    () async {
      final repository = _FakeReportRepository();
      final container = ProviderContainer(
        overrides: [reportRepositoryProvider.overrideWithValue(repository)],
      );
      addTearDown(container.dispose);

      final subscription = container.listen(inventoryReportProvider, (_, _) {});
      addTearDown(subscription.close);
      final report = await container.read(inventoryReportProvider.future);

      expect(repository.inventoryReads, 1);
      expect(report.totalProducts, 5);
      expect(report.inventoryCostValue, 29.96);
      expect(report.expectedGrossProfit, 16.54);
      expect(report.unitsSold, 6);
    },
  );

  test('provider re-reads live stock after it is disposed', () async {
    final repository = _FakeReportRepository();
    final container = ProviderContainer(
      overrides: [reportRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    final firstVisit = container.listen(inventoryReportProvider, (_, _) {});
    expect(
      (await container.read(inventoryReportProvider.future)).totalUnits,
      19,
    );
    firstVisit.close();
    await container.pump();

    repository.stockUnits = 25;

    final secondVisit = container.listen(inventoryReportProvider, (_, _) {});
    addTearDown(secondVisit.close);
    expect(
      (await container.read(inventoryReportProvider.future)).totalUnits,
      25,
    );
    expect(repository.inventoryReads, 2);
  });
}
