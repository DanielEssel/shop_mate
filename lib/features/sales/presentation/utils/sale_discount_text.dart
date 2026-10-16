import 'package:flutter/foundation.dart';

import '../../../../core/utils/money_format.dart';
import '../../../discounts/domain/entities/discount_percentage.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';

/// Amounts for a receipt, from what the sale recorded: never recomputed
/// from current prices or the current discount.
@immutable
class ReceiptTotals {
  const ReceiptTotals({
    required this.subtotal,
    required this.discount,
    required this.total,
  });

  /// [sale] and its [items] as recorded. Before discounts existed every
  /// line recorded no discount, so the subtotal equals the total.
  factory ReceiptTotals.of(Sale sale, List<SaleItem> items) {
    var lineTotalsCents = 0;
    var lineDiscountsCents = 0;
    for (final item in items) {
      lineTotalsCents += _cents(item.subtotal);
      lineDiscountsCents += _cents(item.discountAmount);
    }
    return ReceiptTotals(
      subtotal: (lineTotalsCents + lineDiscountsCents) / 100,
      discount: sale.discountAmount,
      total: sale.totalAmount,
    );
  }

  /// Before any discount.
  final double subtotal;

  /// The sale's recorded discount (0 for none).
  final double discount;

  /// The recorded amount charged.
  final double total;

  bool get hasDiscount => discount > 0;

  static int _cents(double amount) => (amount * 100).round();
}

/// Amounts as receipts have always printed them: two decimals, no
/// thousands separators (`GHS 1350.00`); a deduction reads `-GHS 2.31`.
String formatReceiptMoney(double amount) => amount < 0
    ? '-GHS ${(-amount).toStringAsFixed(2)}'
    : 'GHS ${amount.toStringAsFixed(2)}';

/// e.g. "Was GHS 10.00 · 10% off (-GHS 2.00)", or null for a line that got
/// no money off (including lines a running discount skipped).
///
/// [formatMoney] matches the surrounding amounts: the app's [formatGhs] by
/// default, [formatReceiptMoney] on receipts.
String? saleItemDiscountNote(
  SaleItem item, {
  String Function(double amount) formatMoney = formatGhs,
}) {
  if (!item.isDiscounted) return null;
  final percentage = _percentageLabel(item.discountPercentage);
  return 'Was ${formatMoney(item.listUnitPrice)}'
      '${percentage == null ? '' : ' · $percentage off'}'
      ' (-${formatMoney(item.discountAmount)})';
}

String? _percentageLabel(double percentage) {
  final basisPoints = (percentage * 100).round();
  if (basisPoints < DiscountPercentage.minBasisPoints ||
      basisPoints > DiscountPercentage.maxBasisPoints) {
    return null;
  }
  return DiscountPercentage.fromBasisPoints(basisPoints).label;
}
