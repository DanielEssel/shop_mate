import 'package:flutter/foundation.dart';

import 'discount_percentage.dart';
import 'discount_scope.dart';

/// The shop's saved discount configuration. The server applies it to every
/// sale; nothing here decides what a sale is charged.
@immutable
class DiscountSettings {
  const DiscountSettings({
    required this.shopId,
    required this.isEnabled,
    required this.scope,
    required this.percentage,
    required this.selectedProductIds,
    this.endsAt,
    this.updatedAt,
  });

  final String shopId;
  final bool isEnabled;
  final DiscountScope scope;
  final DiscountPercentage percentage;

  /// The discount stops applying at this moment, if set.
  final DateTime? endsAt;

  /// Products chosen for [DiscountScope.selectedProducts]. Kept (and
  /// ignored) while the scope is [DiscountScope.allProducts].
  final Set<String> selectedProductIds;

  final DateTime? updatedAt;

  bool isExpiredAt(DateTime now) {
    final endsAt = this.endsAt;
    return endsAt != null && !endsAt.isAfter(now);
  }

  /// Whether sales get this discount at [now].
  bool isActiveAt(DateTime now) => isEnabled && !isExpiredAt(now);
}

/// What the owner wants to save. Validated by `SaveDiscountSettings`.
@immutable
class DiscountSettingsDraft {
  const DiscountSettingsDraft({
    required this.isEnabled,
    required this.scope,
    required this.percentage,
    required this.selectedProductIds,
    this.endsAt,
  });

  final bool isEnabled;
  final DiscountScope scope;
  final DiscountPercentage percentage;
  final DateTime? endsAt;
  final Set<String> selectedProductIds;
}
