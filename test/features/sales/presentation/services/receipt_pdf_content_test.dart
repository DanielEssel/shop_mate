import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:shopmate/features/sales/domain/entities/sale.dart';
import 'package:shopmate/features/sales/domain/entities/sale_item.dart';
import 'package:shopmate/features/sales/presentation/services/receipt_output_service.dart';

/// The text drawn on each page of a generated receipt, in drawing order,
/// with the words joined by single spaces.
///
/// The receipt uses PDF's built-in Helvetica, so every word is a literal
/// string in a compressed content stream (`[(word)]TJ`). This reads the
/// page tree, inflates each page's content stream and decodes those strings:
/// it checks what is actually in the PDF, not what the app meant to draw.
List<String> _pdfPageTexts(Uint8List bytes) {
  final raw = latin1.decode(bytes);

  String objectBody(String number) {
    final start = RegExp('(^|\\n)$number 0 obj').firstMatch(raw);
    if (start == null) throw StateError('object $number not found');
    final end = raw.indexOf('endobj', start.end);
    return raw.substring(start.end, end);
  }

  String streamOf(String number) {
    final start = RegExp('(^|\\n)$number 0 obj').firstMatch(raw)!;
    final streamAt = raw.indexOf(RegExp(r'stream\r?\n'), start.end);
    final dataStart = raw.indexOf('\n', streamAt) + 1;
    final dataEnd = raw.indexOf('endstream', dataStart);
    final dictionary = raw.substring(start.end, streamAt);
    final data = bytes.sublist(dataStart, dataEnd);
    return latin1.decode(
      dictionary.contains('/FlateDecode') ? ZLibDecoder().convert(data) : data,
    );
  }

  String unescape(String literal) {
    return literal.replaceAllMapped(RegExp(r'\\([0-7]{1,3}|.)'), (match) {
      final escaped = match.group(1)!;
      if (RegExp(r'^[0-7]+$').hasMatch(escaped)) {
        return String.fromCharCode(int.parse(escaped, radix: 8));
      }
      return switch (escaped) {
        'n' => '\n',
        'r' => '\r',
        't' => '\t',
        _ => escaped,
      };
    });
  }

  final literal = RegExp(r'\(((?:\\.|[^\\)])*)\)');
  final textOperator = RegExp(
    r'(\[(?:\\.|[^\]\\])*\])\s*TJ|(\((?:\\.|[^\\)])*\))\s*Tj',
  );

  final catalogPages = RegExp(
    r'/Type\s*/Pages\b[^>]*?/Kids\s*\[([^\]]*)\]',
  ).firstMatch(raw)!;
  final pageNumbers = RegExp(
    r'(\d+)\s+0\s+R',
  ).allMatches(catalogPages.group(1)!).map((match) => match.group(1)!);

  return [
    for (final page in pageNumbers)
      () {
        final contents = RegExp(
          r'/Contents\s*(\[[^\]]*\]|\d+\s+0\s+R)',
        ).firstMatch(objectBody(page))!.group(1)!;
        final words = <String>[];
        for (final reference in RegExp(r'(\d+)\s+0\s+R').allMatches(contents)) {
          final stream = streamOf(reference.group(1)!);
          for (final operator in textOperator.allMatches(stream)) {
            final source = operator.group(1) ?? operator.group(2)!;
            words.add(
              literal
                  .allMatches(source)
                  .map((piece) => unescape(piece.group(1)!))
                  .join(),
            );
          }
        }
        return words.join(' ');
      }(),
  ];
}

Future<List<String>> _receiptPages(
  Sale sale,
  List<SaleItem> items, {
  double? paid,
}) async {
  final bytes = await ReceiptOutputService().generatePdf(
    ReceiptPdfData(
      sale: sale,
      items: items,
      paidAmount: paid ?? sale.amountPaid,
      paymentMethod: sale.paymentMethodLabel,
      date: 'Oct 15, 2026',
      time: '9:00 AM',
    ),
  );
  return _pdfPageTexts(bytes);
}

Future<String> _receiptText(Sale sale, List<SaleItem> items) async =>
    (await _receiptPages(sale, items)).join(' ');

SaleItem _item(
  String id,
  String name, {
  required int quantity,
  required double unit,
  required double subtotal,
  double? original,
  double percentage = 0,
  double discount = 0,
  String saleId = 'sale-d',
}) {
  return SaleItem(
    id: id,
    saleId: saleId,
    productId: 'p-$id',
    productName: name,
    quantity: quantity,
    unitPrice: unit,
    costPrice: 0,
    subtotal: subtotal,
    originalUnitPrice: original,
    discountPercentage: percentage,
    discountAmount: discount,
    createdAt: DateTime(2026, 10, 15, 9),
  );
}

/// Recorded with a discount: Rice 10.00 at 10% x2, Soap 2.50 at 12.5% x1,
/// and Sugar covered by an all-products discount but cost-protected.
final _discountedSale = Sale(
  id: 'sale-d',
  saleNumber: 'SL-DISC',
  totalAmount: 27.19,
  discountAmount: 2.31,
  paymentMethod: 'cash',
  amountPaid: 30,
  changeAmount: 2.81,
  createdAt: DateTime(2026, 10, 15, 9),
);

final _discountedItems = [
  _item(
    'i1',
    'Rice 1kg',
    quantity: 2,
    unit: 9.00,
    subtotal: 18.00,
    original: 10.00,
    percentage: 10,
    discount: 2.00,
  ),
  _item(
    'i2',
    'Soap',
    quantity: 1,
    unit: 2.19,
    subtotal: 2.19,
    original: 2.50,
    percentage: 12.5,
    discount: 0.31,
  ),
  _item('i3', 'Sugar', quantity: 1, unit: 7.00, subtotal: 7.00, original: 7.00),
];

Sale _plainSale({double discount = 0}) => Sale(
  id: 'sale-p',
  saleNumber: 'SL-PLAIN',
  totalAmount: 20.00,
  discountAmount: discount,
  paymentMethod: 'mobile_money',
  amountPaid: 20.00,
  changeAmount: 0,
  createdAt: DateTime(2026, 9, 1, 9),
);

void main() {
  group('discounted sale', () {
    late String text;

    setUpAll(() async {
      text = await _receiptText(_discountedSale, _discountedItems);
    });

    test('each discounted line shows original price, percentage, discount '
        'and the final unit price and line total', () {
      // Product | Qty | Price | Total, the discount note under the name.
      expect(
        text,
        contains(
          'Rice 1kg Was GHS 10.00 · 10% off (-GHS 2.00) 2 GHS 9.00 GHS 18.00',
        ),
      );
      expect(
        text,
        contains(
          'Soap Was GHS 2.50 · 12.5% off (-GHS 0.31) 1 GHS 2.19 GHS 2.19',
        ),
      );
    });

    test('a cost-protected line shows no discount', () {
      expect(text, contains('Sugar 1 GHS 7.00 GHS 7.00'));
      expect(text, isNot(contains('Was GHS 7.00')));
    });

    test('subtotal before discount, total discount, final total, paid and '
        'change: the recorded values', () {
      // 18.00 + 2.19 + 7.00 charged + 2.31 discount = 29.50 before.
      expect(
        text,
        contains(
          'Subtotal GHS 29.50 Discount -GHS 2.31 Total GHS 27.19 '
          'Paid GHS 30.00 Change GHS 2.81',
        ),
      );
    });

    test('the receipt identifies the sale and payment', () {
      expect(text, startsWith('SALES RECEIPT SL-DISC'));
      expect(text, contains('Payment method Cash'));
    });
  });

  group('sales without a discount', () {
    test('a new sale with zero discount: no discount row or notes', () async {
      final text = await _receiptText(_plainSale(), [
        _item(
          'n1',
          'Rice 1kg',
          quantity: 2,
          unit: 10.00,
          subtotal: 20.00,
          original: 10.00,
          saleId: 'sale-p',
        ),
      ]);

      expect(text, contains('Rice 1kg 2 GHS 10.00 GHS 20.00'));
      expect(
        text,
        contains('Subtotal GHS 20.00 Total GHS 20.00 Paid GHS 20.00'),
      );
      expect(text, isNot(contains('Discount')));
      expect(text, isNot(contains('Was GHS')));
      expect(text, contains('Payment method Mobile Money'));
    });

    test('a sale recorded before discounts existed prints exactly like a '
        'zero-discount sale, from its stored amounts', () async {
      // No snapshot values at all, as rows from before the migration read.
      final historical = await _receiptText(_plainSale(), [
        _item(
          'h1',
          'Rice 1kg',
          quantity: 2,
          unit: 10.00,
          subtotal: 20.00,
          saleId: 'sale-p',
        ),
      ]);
      final zeroSnapshots = await _receiptText(_plainSale(), [
        _item(
          'h1',
          'Rice 1kg',
          quantity: 2,
          unit: 10.00,
          subtotal: 20.00,
          original: 10.00,
          saleId: 'sale-p',
        ),
      ]);

      expect(historical, zeroSnapshots);
      expect(historical, contains('Total GHS 20.00'));
      expect(historical, isNot(contains('Discount')));
    });

    test('stored amounts are printed as recorded, never recomputed', () async {
      // A legacy line whose stored subtotal is not unit x quantity (e.g. a
      // historical rounding): the receipt must show the stored figure.
      final text = await _receiptText(
        Sale(
          id: 'sale-x',
          saleNumber: 'SL-X',
          totalAmount: 10.01,
          paymentMethod: 'cash',
          amountPaid: 10.01,
          changeAmount: 0,
          createdAt: DateTime(2026, 9, 1),
        ),
        [
          _item(
            'x1',
            'Odd',
            quantity: 3,
            unit: 3.33,
            subtotal: 10.01,
            saleId: 'sale-x',
          ),
        ],
      );
      expect(text, contains('Odd 3 GHS 3.33 GHS 10.01'));
      expect(text, contains('Total GHS 10.01'));
    });
  });

  group('formatting and layout', () {
    test('two decimals, larger amounts, and deductions as -GHS', () async {
      final text = await _receiptText(
        Sale(
          id: 'sale-big',
          saleNumber: 'SL-BIG',
          totalAmount: 1215.0,
          discountAmount: 135.0,
          paymentMethod: 'card',
          amountPaid: 1215.0,
          changeAmount: 0,
          createdAt: DateTime(2026, 10, 15),
        ),
        [
          _item(
            'b1',
            'Fridge',
            quantity: 1,
            unit: 1215.0,
            subtotal: 1215.0,
            original: 1350.0,
            percentage: 10,
            discount: 135.0,
            saleId: 'sale-big',
          ),
        ],
      );

      // The PDF has never used thousands separators (unlike the app).
      expect(
        text,
        contains(
          'Fridge Was GHS 1350.00 · 10% off (-GHS 135.00) 1 '
          'GHS 1215.00 GHS 1215.00',
        ),
      );
      expect(
        text,
        contains('Subtotal GHS 1350.00 Discount -GHS 135.00 Total GHS 1215.00'),
      );
      expect(text, isNot(contains('GHS -')));
    });

    test('a very long product name wraps without losing the line', () async {
      const name =
          'Premium Long Grain Fragrant Jasmine Rice Imported Family Value '
          'Bag Five Kilogram Extra Long Description For Testing Wrapping';
      final text = await _receiptText(_plainSale(), [
        _item(
          'l1',
          name,
          quantity: 2,
          unit: 10.00,
          subtotal: 20.00,
          original: 10.00,
          saleId: 'sale-p',
        ),
      ]);

      expect(text, contains('$name 2 GHS 10.00 GHS 20.00'));
    });

    test(
      'many lines flow onto further pages, totals once at the end',
      () async {
        final items = [
          for (var i = 1; i <= 70; i++)
            _item(
              'm$i',
              'Item $i',
              quantity: 1,
              unit: 1.00,
              subtotal: 1.00,
              original: 1.00,
              saleId: 'sale-m',
            ),
        ];
        final pages = await _receiptPages(
          Sale(
            id: 'sale-m',
            saleNumber: 'SL-MANY',
            totalAmount: 70,
            paymentMethod: 'cash',
            amountPaid: 70,
            changeAmount: 0,
            createdAt: DateTime(2026, 10, 15),
          ),
          items,
        );
        final all = pages.join(' ');

        expect(pages.length, greaterThan(1));
        for (var i = 1; i <= 70; i++) {
          expect(
            RegExp('Item $i 1 GHS 1.00 GHS 1.00(?![0-9])').allMatches(all),
            hasLength(1),
            reason: 'Item $i',
          );
        }
        expect(pages.last, contains('Subtotal GHS 70.00 Total GHS 70.00'));
        expect('Subtotal'.allMatches(all), hasLength(1));
      },
    );

    test('KNOWN LIMITATION: letters outside Latin-1 are dropped by the '
        'built-in PDF font', () async {
      // Twi product names (ɛ, ɔ) lose those letters; the amounts survive.
      // This predates discounts; fixing it needs an embedded Unicode font.
      final text = await _receiptText(_plainSale(), [
        _item(
          't1',
          'Ɛmo Pɔnkɔ',
          quantity: 2,
          unit: 10.00,
          subtotal: 20.00,
          saleId: 'sale-p',
        ),
      ]);

      expect(text, isNot(contains('Ɛmo')));
      expect(text, contains('2 GHS 10.00 GHS 20.00'));
    });
  });
}
