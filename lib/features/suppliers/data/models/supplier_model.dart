import '../../domain/entities/supplier.dart';

class SupplierModel extends Supplier {
  const SupplierModel({
    required super.id,
    required super.shopId,
    required super.name,
    required super.isActive,
    required super.createdAt,
    required super.updatedAt,
    super.phone,
    super.email,
    super.address,
    super.notes,
    super.createdBy,
  });

  /// Columns read from `public.suppliers`.
  static const selectColumns =
      'id, shop_id, name, phone, email, address, notes, is_active, '
      'created_by, created_at, updated_at';

  factory SupplierModel.fromRow(Map<String, Object?> row) {
    return SupplierModel(
      id: _string(row, 'id'),
      shopId: _string(row, 'shop_id'),
      name: _string(row, 'name'),
      phone: _optionalString(row, 'phone'),
      email: _optionalString(row, 'email'),
      address: _optionalString(row, 'address'),
      notes: _optionalString(row, 'notes'),
      isActive: _bool(row, 'is_active'),
      createdBy: _optionalString(row, 'created_by'),
      createdAt: _timestamp(row, 'created_at'),
      updatedAt: _timestamp(row, 'updated_at'),
    );
  }

  static String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid supplier field: $field.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid supplier field: $field.');
    }
    return value;
  }

  static bool _bool(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! bool) {
      throw FormatException('Invalid supplier field: $field.');
    }
    return value;
  }

  static DateTime _timestamp(Map<String, Object?> row, String field) {
    final parsed = DateTime.tryParse(_string(row, field));
    if (parsed == null) {
      throw FormatException('Invalid supplier timestamp: $field.');
    }
    return parsed;
  }
}
