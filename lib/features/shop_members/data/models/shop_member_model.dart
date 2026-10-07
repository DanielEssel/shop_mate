import '../../../shop/domain/entities/shop_access.dart';
import '../../domain/entities/shop_member.dart';

class ShopMemberModel extends ShopMember {
  const ShopMemberModel({
    required super.memberId,
    required super.userId,
    required super.role,
    required super.status,
    required super.createdAt,
    required super.updatedAt,
    super.email,
    super.displayName,
  });

  /// A row returned by the `list_shop_members` RPC.
  factory ShopMemberModel.fromRow(Map<String, Object?> row) {
    final statusValue = _string(row, 'status');
    final status = ShopMemberStatus.fromValue(statusValue);
    if (status == null) {
      throw FormatException('Unknown member status: $statusValue.');
    }

    return ShopMemberModel(
      memberId: _string(row, 'member_id'),
      userId: _string(row, 'user_id'),
      role: ShopRole.fromValue(_string(row, 'role')),
      status: status,
      email: _optionalText(row, 'email'),
      displayName: _optionalText(row, 'display_name'),
      createdAt: _timestamp(row, 'created_at'),
      updatedAt: _timestamp(row, 'updated_at'),
    );
  }

  static String _string(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value is! String) {
      throw FormatException('Invalid shop member field: $field.');
    }
    return value;
  }

  /// A nullable text field; blank counts as missing.
  static String? _optionalText(Map<String, Object?> row, String field) {
    final value = row[field];
    if (value == null) return null;
    if (value is! String) {
      throw FormatException('Invalid shop member field: $field.');
    }
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static DateTime _timestamp(Map<String, Object?> row, String field) {
    final parsed = DateTime.tryParse(_string(row, field));
    if (parsed == null) {
      throw FormatException('Invalid shop member timestamp: $field.');
    }
    return parsed;
  }
}
