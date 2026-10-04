import '../../domain/entities/customer_credit_statement.dart';

class CustomerCreditStatementModel extends CustomerCreditStatement {
  const CustomerCreditStatementModel({
    required super.totalCreditSales,
    required super.totalPaid,
    required super.outstandingBalance,
    required super.outstandingSaleCount,
    required super.outstandingSales,
    required super.paymentHistory,
  });

  factory CustomerCreditStatementModel.fromRows({
    required List<Map<String, Object?>> creditSales,
    required List<Map<String, Object?>> payments,
  }) {
    var totalCreditSales = 0.0;
    var totalPaid = 0.0;
    var outstandingBalance = 0.0;
    final outstandingSales = <OutstandingCreditSale>[];

    for (final sale in creditSales) {
      final totalAmount = _number(sale, 'total_amount');
      final allocations = _rows(sale['customer_payment_allocations']);
      final paidAmount = allocations.fold<double>(
        0,
        (sum, allocation) => sum + _number(allocation, 'amount'),
      );
      final outstandingAmount = (totalAmount - paidAmount)
          .clamp(0.0, double.infinity)
          .toDouble();

      totalCreditSales += totalAmount;
      totalPaid += paidAmount;
      outstandingBalance += outstandingAmount;

      if (outstandingAmount > 0) {
        outstandingSales.add(
          OutstandingCreditSale(
            id: _string(sale, 'id'),
            saleNumber: _string(sale, 'sale_number'),
            createdAt: _date(sale, 'created_at'),
            totalAmount: totalAmount,
            paidAmount: paidAmount,
            outstandingAmount: outstandingAmount,
          ),
        );
      }
    }

    final paymentHistory = payments
        .map((payment) {
          final allocatedSaleNumbers = <String>[];

          for (final allocation in _rows(
            payment['customer_payment_allocations'],
          )) {
            final sale = _map(allocation['sales']);
            if (sale == null) continue;

            final saleNumber = sale['sale_number'];
            if (saleNumber is String && saleNumber.isNotEmpty) {
              allocatedSaleNumbers.add(saleNumber);
            }
          }

          return CustomerPaymentHistoryEntry(
            id: _string(payment, 'id'),
            paidAt: _date(payment, 'paid_at'),
            amount: _number(payment, 'amount'),
            paymentMethod: _string(payment, 'payment_method'),
            reference: _optionalString(payment, 'reference'),
            note: _optionalString(payment, 'note'),
            allocatedSaleNumbers: List.unmodifiable(allocatedSaleNumbers),
          );
        })
        .toList(growable: false);

    return CustomerCreditStatementModel(
      totalCreditSales: totalCreditSales,
      totalPaid: totalPaid,
      outstandingBalance: outstandingBalance,
      outstandingSaleCount: outstandingSales.length,
      outstandingSales: List.unmodifiable(outstandingSales),
      paymentHistory: List.unmodifiable(paymentHistory),
    );
  }

  static List<Map<String, Object?>> _rows(Object? value) {
    if (value == null) return const [];
    if (value is! List) {
      throw const FormatException('Invalid customer credit statement data.');
    }

    return value
        .map((row) {
          final result = _map(row);
          if (result == null) {
            throw const FormatException(
              'Invalid customer credit statement row.',
            );
          }
          return result;
        })
        .toList(growable: false);
  }

  static Map<String, Object?>? _map(Object? value) {
    if (value is! Map) return null;
    return Map<String, Object?>.from(value);
  }

  static String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid customer credit field: $field.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid customer credit field: $field.');
    }
    return value;
  }

  static double _number(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! num) {
      throw FormatException('Invalid customer credit amount: $field.');
    }
    return value.toDouble();
  }

  static DateTime _date(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid customer credit date: $field.');
    }
    return DateTime.parse(value);
  }
}
