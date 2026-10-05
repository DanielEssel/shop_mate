import 'package:supabase_flutter/supabase_flutter.dart';

/// Unique index enforcing one active supplier per normalised name per shop.
const _activeNameIndex = 'suppliers_shop_active_name_uidx';

/// True only when the database rejected a write because another active
/// supplier in the shop already has the same name.
bool isDuplicateActiveSupplierName(Object error) {
  if (error is! PostgrestException) return false;
  if (error.code != '23505') return false;

  return error.message.contains(_activeNameIndex) ||
      (error.details?.toString().contains(_activeNameIndex) ?? false);
}

/// A short message for a failed supplier save. Raw database text is never
/// shown; only the duplicate-name case gets a specific explanation.
String supplierSaveErrorMessage(Object error) {
  if (isDuplicateActiveSupplierName(error)) {
    return 'A supplier with this name already exists.';
  }

  if (error is PostgrestException) {
    switch (error.code) {
      case '23514':
        return 'Some supplier details are too long or invalid.';
      case '42501':
        return 'You do not have permission to change suppliers.';
    }
  }

  return 'Unable to save supplier. Check your connection and try again.';
}
