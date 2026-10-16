import 'package:flutter/foundation.dart';

import 'sale.dart';

/// A sale the database has recorded.
///
/// [saleId] is all the sale RPCs return. [sale] is the recorded row, read
/// back afterwards for the receipt; it is null when that read failed. The
/// sale exists either way and must never be submitted again.
@immutable
class RecordedSale {
  const RecordedSale({required this.saleId, this.sale});

  final String saleId;
  final Sale? sale;

  bool get hasDetails => sale != null;
}
