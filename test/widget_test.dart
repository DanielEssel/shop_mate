import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:shopmate/app/app.dart';
import 'package:shopmate/app/config/supabase_config.dart';

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});

    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
  });

  testWidgets('ShopMate app starts successfully', (tester) async {
    await tester.pumpWidget(
      const ShopInventoryApp(),
    );

    await tester.pump();

    expect(find.byType(ShopInventoryApp), findsOneWidget);
  });
}
