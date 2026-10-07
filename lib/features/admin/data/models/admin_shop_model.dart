import '../../domain/entities/admin_shop.dart';

class AdminShopModel extends AdminShop {
  const AdminShopModel({
    required super.id,
    required super.name,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.phone,
    super.ownerEmail,
    super.approvedAt,
  });

  /// A row returned by the `admin_list_shops` RPC.
  factory AdminShopModel.fromRow(Map<String, Object?> row) {
    final statusValue = _string(row, 'shop_status');
    final status = AdminShopStatus.fromValue(statusValue);
    if (status == null) {
      throw FormatException('Unknown shop status: $statusValue.');
    }

    return AdminShopModel(
      id: _string(row, 'shop_id'),
      name: _string(row, 'shop_name'),
      phone: _optionalString(row, 'shop_phone'),
      status: status,
      ownerEmail: _optionalString(row, 'owner_email'),
      createdAt: _timestamp(row, 'created_at'),
      approvedAt: _optionalTimestamp(row, 'approved_at'),
      updatedAt: _timestamp(row, 'updated_at'),
    );
  }

  static String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid admin shop field: $field.');
    }
    return value;
  }

  static String? _optionalString(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid admin shop field: $field.');
    }
    return value;
  }

  static DateTime _timestamp(Map<String, Object?> row, String field) {
    final parsed = DateTime.tryParse(_string(row, field));
    if (parsed == null) {
      throw FormatException('Invalid admin shop timestamp: $field.');
    }
    return parsed;
  }

  static DateTime? _optionalTimestamp(Map<String, Object?> row, String field) {
    if (row[field] == null) return null;
    return _timestamp(row, field);
  }
}
