import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/entities/sale.dart';
import '../../domain/entities/sale_item.dart';
import 'receipt_branding.dart';

class ReceiptPdfData {
  const ReceiptPdfData({
    required this.sale,
    required this.items,
    required this.paidAmount,
    required this.paymentMethod,
    required this.date,
    required this.time,
    this.branding = const ReceiptBranding(),
    this.customerName,
  });

  final Sale sale;
  final List<SaleItem> items;
  final double paidAmount;
  final String paymentMethod;
  final String date;
  final String time;
  final ReceiptBranding branding;
  final String? customerName;
}

class ReceiptOutputService {
  /// Bounds for the printed logo, in PDF points.
  static const logoMaxWidth = 140.0;
  static const logoMaxHeight = 56.0;

  /// Scales an image of [width] x [height] to fit within the logo bounds,
  /// preserving its aspect ratio and never enlarging it.
  static ({double width, double height}) fitLogo(int width, int height) {
    if (width <= 0 || height <= 0) {
      return (width: logoMaxWidth, height: logoMaxHeight);
    }
    final scale = math.min(
      1.0,
      math.min(logoMaxWidth / width, logoMaxHeight / height),
    );
    return (width: width * scale, height: height * scale);
  }

  /// Generates the receipt. A logo that cannot be decoded or rendered is
  /// dropped; the receipt itself never fails because of the logo.
  Future<Uint8List> generatePdf(ReceiptPdfData data) async {
    if (data.branding.logoBytes == null) {
      return _generate(data, logo: null);
    }

    try {
      return await _generate(data, logo: _logoImage(data.branding.logoBytes));
    } catch (_) {
      return _generate(data, logo: null);
    }
  }

  /// The decoded, size-bounded logo, or null when the bytes are unusable.
  static pw.Widget? _logoImage(Uint8List? bytes) {
    if (bytes == null) return null;

    final pw.MemoryImage image;
    try {
      image = pw.MemoryImage(bytes);
    } catch (_) {
      return null;
    }

    final size = fitLogo(image.width ?? 0, image.height ?? 0);
    return pw.Image(
      image,
      width: size.width,
      height: size.height,
      fit: pw.BoxFit.contain,
    );
  }

  Future<Uint8List> _generate(ReceiptPdfData data, {pw.Widget? logo}) async {
    final shopName = data.branding.shopName;
    final phone = data.branding.phone;
    final document = pw.Document(
      title: 'Receipt ${data.sale.saleNumber}',
      author: 'ShopMate',
      creator: 'ShopMate',
    );
    final subtotal = data.items.fold<double>(
      0,
      (total, item) => total + item.subtotal,
    );
    final outstanding = (data.sale.totalAmount - data.paidAmount)
        .clamp(0.0, double.infinity)
        .toDouble();

    document.addPage(
      pw.MultiPage(
        pageFormat: pdf.PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(42, 48, 42, 48),
        build: (context) => [
          if (logo != null) ...[pw.Center(child: logo), pw.SizedBox(height: 8)],
          if (shopName != null) ...[
            pw.Center(
              child: pw.Text(
                shopName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  fontSize: 19,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
            ),
            pw.SizedBox(height: 5),
          ],
          if (phone != null) ...[
            pw.Center(
              child: pw.Text(
                phone,
                style: const pw.TextStyle(
                  fontSize: 10,
                  color: pdf.PdfColors.grey700,
                ),
              ),
            ),
            pw.SizedBox(height: 5),
          ],
          pw.Center(
            child: pw.Text(
              'SALES RECEIPT',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                letterSpacing: 1.2,
                color: pdf.PdfColors.grey700,
              ),
            ),
          ),
          pw.SizedBox(height: 18),
          pw.Center(
            child: pw.Text(
              data.sale.saleNumber,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.SizedBox(height: 12),
          _detailRow('Date', data.date),
          _detailRow('Time', data.time),
          if (data.customerName != null)
            _detailRow('Customer', data.customerName!),
          if (data.sale.isCredit) ...[
            pw.SizedBox(height: 8),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 5,
              ),
              decoration: pw.BoxDecoration(
                color: pdf.PdfColors.amber100,
                borderRadius: pw.BorderRadius.circular(3),
              ),
              child: pw.Text(
                'CREDIT SALE',
                style: pw.TextStyle(
                  fontSize: 9,
                  fontWeight: pw.FontWeight.bold,
                  color: pdf.PdfColors.brown800,
                ),
              ),
            ),
          ],
          pw.SizedBox(height: 20),
          pw.Table(
            border: pw.TableBorder(
              top: pw.BorderSide(color: pdf.PdfColors.grey400, width: 0.7),
              bottom: pw.BorderSide(color: pdf.PdfColors.grey400, width: 0.7),
              horizontalInside: pw.BorderSide(
                color: pdf.PdfColors.grey300,
                width: 0.4,
              ),
            ),
            columnWidths: const {
              0: pw.FlexColumnWidth(5),
              1: pw.FlexColumnWidth(1),
              2: pw.FlexColumnWidth(2.5),
              3: pw.FlexColumnWidth(2.5),
            },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(
                  color: pdf.PdfColors.grey200,
                ),
                children: [
                  _tableCell('Product', bold: true),
                  _tableCell('Qty', bold: true, alignRight: true),
                  _tableCell('Price', bold: true, alignRight: true),
                  _tableCell('Total', bold: true, alignRight: true),
                ],
              ),
              for (final item in data.items)
                pw.TableRow(
                  children: [
                    _tableCell(item.productName),
                    _tableCell(item.quantity.toString(), alignRight: true),
                    _tableCell(_money(item.unitPrice), alignRight: true),
                    _tableCell(_money(item.subtotal), alignRight: true),
                  ],
                ),
            ],
          ),
          pw.SizedBox(height: 18),
          _amountRow('Subtotal', subtotal),
          pw.SizedBox(height: 5),
          _amountRow('Total', data.sale.totalAmount, bold: true),
          pw.SizedBox(height: 5),
          _amountRow('Paid', data.paidAmount),
          if (data.sale.isCredit)
            _amountRow('Outstanding', outstanding, bold: outstanding > 0)
          else if (data.sale.changeAmount > 0)
            _amountRow('Change', data.sale.changeAmount),
          pw.SizedBox(height: 7),
          _detailRow(
            data.sale.isCredit ? 'Payment' : 'Payment method',
            data.paymentMethod,
          ),
          if (data.sale.isCredit) _detailRow('Sale type', 'Credit'),
          pw.SizedBox(height: 24),
          pw.Center(
            child: pw.Text(
              'Thank you for your business',
              style: const pw.TextStyle(
                fontSize: 9,
                color: pdf.PdfColors.grey700,
              ),
            ),
          ),
        ],
      ),
    );

    return document.save(enableEventLoopBalancing: true);
  }

  Future<PrintingInfo> capabilities() {
    return Printing.info();
  }

  Future<bool> sharePdf({required Uint8List bytes, required String filename}) {
    return Printing.sharePdf(
      bytes: bytes,
      filename: filename,
      subject: filename.replaceAll('.pdf', ''),
    );
  }

  Future<bool> printPdf({required Uint8List bytes, required String filename}) {
    return Printing.layoutPdf(
      name: filename,
      format: pdf.PdfPageFormat.a4,
      dynamicLayout: false,
      onLayout: (_) async => bytes,
    );
  }

  String filenameFor(String saleNumber) {
    final safeSaleNumber = saleNumber
        .replaceAll(RegExp(r'[^A-Za-z0-9_-]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final filenamePart = safeSaleNumber.isEmpty ? 'Sale' : safeSaleNumber;

    return 'ShopMate-Receipt-$filenamePart.pdf';
  }

  pw.Widget _detailRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 3),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            label,
            style: const pw.TextStyle(color: pdf.PdfColors.grey700),
          ),
          pw.SizedBox(width: 16),
          pw.Expanded(child: pw.Text(value, textAlign: pw.TextAlign.right)),
        ],
      ),
    );
  }

  pw.Widget _tableCell(
    String value, {
    bool bold = false,
    bool alignRight = false,
  }) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 8),
      child: pw.Text(
        value,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: pw.TextStyle(
          fontSize: 9,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );
  }

  pw.Widget _amountRow(String label, double amount, {bool bold = false}) {
    final style = pw.TextStyle(
      fontSize: bold ? 12 : 10,
      fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
    );

    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label, style: style),
          pw.Text(_money(amount), style: style),
        ],
      ),
    );
  }

  String _money(double amount) => 'GHS ${amount.toStringAsFixed(2)}';
}
