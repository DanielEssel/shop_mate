import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/features/suppliers/presentation/utils/supplier_error_message.dart';

void main() {
  test('recognises the active supplier name unique violation', () {
    const error = PostgrestException(
      message:
          'duplicate key value violates unique constraint '
          '"suppliers_shop_active_name_uidx"',
      code: '23505',
    );

    expect(isDuplicateActiveSupplierName(error), isTrue);
    expect(
      supplierSaveErrorMessage(error),
      'A supplier with this name already exists.',
    );
  });

  test('does not treat other unique violations as a duplicate name', () {
    const error = PostgrestException(
      message:
          'duplicate key value violates unique constraint "suppliers_pkey"',
      code: '23505',
    );

    expect(isDuplicateActiveSupplierName(error), isFalse);
    expect(
      supplierSaveErrorMessage(error),
      'Unable to save supplier. Check your connection and try again.',
    );
  });

  test('does not match the index name under a different error code', () {
    const error = PostgrestException(
      message: 'suppliers_shop_active_name_uidx is being rebuilt',
      code: '55000',
    );

    expect(isDuplicateActiveSupplierName(error), isFalse);
  });

  test('maps check and permission errors without raw database text', () {
    expect(
      supplierSaveErrorMessage(
        const PostgrestException(
          message: 'violates check constraint "suppliers_name_check"',
          code: '23514',
        ),
      ),
      'Some supplier details are too long or invalid.',
    );
    expect(
      supplierSaveErrorMessage(
        const PostgrestException(message: 'rls', code: '42501'),
      ),
      'You do not have permission to change suppliers.',
    );
  });

  test('non-database errors get the generic message', () {
    expect(
      supplierSaveErrorMessage(Exception('SocketException: host lookup')),
      'Unable to save supplier. Check your connection and try again.',
    );
  });
}
