import 'package:flutter/foundation.dart';

/// Which database function records the request.
enum SaleRequestKind {
  /// Cash, mobile money, card or bank transfer: `create_sale_idempotent`.
  standard('standard'),

  /// Credit with an optional initial payment:
  /// `create_credit_sale_with_initial_payment`.
  credit('credit');

  const SaleRequestKind(this.value);

  final String value;

  static SaleRequestKind? fromValue(String value) {
    for (final kind in values) {
      if (kind.value == value) return kind;
    }
    return null;
  }
}

/// One line as sent to the database: a product and a quantity, nothing
/// else (prices are the database's).
@immutable
class SaleRequestItem {
  const SaleRequestItem({required this.productId, required this.quantity});

  final String productId;
  final int quantity;

  /// Exactly what the RPCs receive in `p_items`.
  Map<String, Object> toJson() => {
    'product_id': productId,
    'quantity': quantity,
  };

  @override
  bool operator ==(Object other) =>
      other is SaleRequestItem &&
      other.productId == productId &&
      other.quantity == quantity;

  @override
  int get hashCode => Object.hash(productId, quantity);
}

/// The sale the cashier is submitting, exactly as it will be sent.
///
/// [sameRequestAs] is the client's version of the database fingerprint:
/// customer, payment method, amount paid, initial payment method and the
/// items in their exact order. [estimatedTotal] is for display only.
@immutable
class SaleDraft {
  const SaleDraft({
    required this.kind,
    required this.paymentMethod,
    required this.amountPaid,
    required this.items,
    required this.estimatedTotal,
    this.customerId,
    this.initialPaymentMethod,
  });

  final SaleRequestKind kind;

  /// `cash`, `mobile_money`, `card`, `bank_transfer`, or `credit`.
  final String paymentMethod;
  final String? customerId;

  /// Amount paid (credit: the initial payment), as sent to the RPC.
  final double amountPaid;

  /// Credit only: how the initial payment was made (null when none).
  final String? initialPaymentMethod;

  /// In submission order: a different order is a different request.
  final List<SaleRequestItem> items;

  /// The checkout's estimate when submitted; never sent.
  final double estimatedTotal;

  bool sameRequestAs(SaleDraft other) {
    if (kind != other.kind ||
        paymentMethod != other.paymentMethod ||
        customerId != other.customerId ||
        amountPaid != other.amountPaid ||
        initialPaymentMethod != other.initialPaymentMethod ||
        items.length != other.items.length) {
      return false;
    }
    for (var i = 0; i < items.length; i++) {
      if (items[i] != other.items[i]) return false;
    }
    return true;
  }

  int get itemCount => items.fold<int>(0, (sum, item) => sum + item.quantity);
}

/// Whose request it is: a saved request is only ever recovered by the same
/// account in the same shop.
@immutable
class PendingSaleScope {
  const PendingSaleScope({required this.userId, required this.shopId});

  final String userId;
  final String shopId;

  @override
  bool operator ==(Object other) =>
      other is PendingSaleScope &&
      other.userId == userId &&
      other.shopId == shopId;

  @override
  int get hashCode => Object.hash(userId, shopId);
}

/// A submitted sale whose outcome is not yet confirmed, saved on the device
/// before the first request so that every retry, even after a restart,
/// sends the same key and the same payload.
@immutable
class PendingSaleRequest {
  const PendingSaleRequest({
    required this.idempotencyKey,
    required this.scope,
    required this.draft,
    required this.createdAt,
  });

  static const formatVersion = 1;

  final String idempotencyKey;
  final PendingSaleScope scope;
  final SaleDraft draft;
  final DateTime createdAt;

  Map<String, Object?> toJson() => {
    'version': formatVersion,
    'idempotency_key': idempotencyKey,
    'user_id': scope.userId,
    'shop_id': scope.shopId,
    'kind': draft.kind.value,
    'payment_method': draft.paymentMethod,
    'customer_id': draft.customerId,
    'amount_paid': draft.amountPaid,
    'initial_payment_method': draft.initialPaymentMethod,
    'items': [for (final item in draft.items) item.toJson()],
    'estimated_total': draft.estimatedTotal,
    'created_at': createdAt.toUtc().toIso8601String(),
  };

  /// Throws [FormatException] for anything that is not a complete request.
  factory PendingSaleRequest.fromJson(Map<String, Object?> json) {
    T field<T>(String name) {
      final value = json[name];
      if (value is! T) {
        throw FormatException('Invalid pending sale field: $name.');
      }
      return value;
    }

    if (json['version'] != formatVersion) {
      throw const FormatException('Unsupported pending sale version.');
    }
    final kind = SaleRequestKind.fromValue(field<String>('kind'));
    if (kind == null) throw const FormatException('Unknown sale kind.');
    final createdAt = DateTime.tryParse(field<String>('created_at'));
    if (createdAt == null) throw const FormatException('Invalid created_at.');

    final items = <SaleRequestItem>[];
    for (final Object? item in field<List<Object?>>('items')) {
      if (item is! Map) throw const FormatException('Invalid item.');
      final productId = item['product_id'];
      final quantity = item['quantity'];
      if (productId is! String || quantity is! int) {
        throw const FormatException('Invalid item.');
      }
      items.add(SaleRequestItem(productId: productId, quantity: quantity));
    }
    if (items.isEmpty) throw const FormatException('A sale has items.');

    return PendingSaleRequest(
      idempotencyKey: field<String>('idempotency_key'),
      scope: PendingSaleScope(
        userId: field<String>('user_id'),
        shopId: field<String>('shop_id'),
      ),
      draft: SaleDraft(
        kind: kind,
        paymentMethod: field<String>('payment_method'),
        customerId: field<String?>('customer_id'),
        amountPaid: field<num>('amount_paid').toDouble(),
        initialPaymentMethod: field<String?>('initial_payment_method'),
        items: List.unmodifiable(items),
        estimatedTotal: field<num>('estimated_total').toDouble(),
      ),
      createdAt: createdAt,
    );
  }
}

/// A request the cashier set aside before its outcome was confirmed (the
/// customer left or did not pay). Setting it aside cannot stop it: the
/// original request may still reach the database and be recorded. So it is
/// kept on the device, with its key and payload, and looked up again until
/// its outcome is known; it is never resent automatically.
@immutable
class AbandonedSaleRequest {
  const AbandonedSaleRequest({
    required this.request,
    required this.abandonedAt,
  });

  final PendingSaleRequest request;
  final DateTime abandonedAt;

  Map<String, Object?> toJson() => {
    'abandoned_at': abandonedAt.toUtc().toIso8601String(),
    'request': request.toJson(),
  };

  /// Throws [FormatException] for anything that is not a complete record.
  factory AbandonedSaleRequest.fromJson(Map<String, Object?> json) {
    final abandonedAt = json['abandoned_at'];
    final request = json['request'];
    final at = abandonedAt is String ? DateTime.tryParse(abandonedAt) : null;
    if (at == null || request is! Map) {
      throw const FormatException('Invalid abandoned sale.');
    }
    return AbandonedSaleRequest(
      request: PendingSaleRequest.fromJson(Map<String, Object?>.from(request)),
      abandonedAt: at,
    );
  }
}
