import 'package:flutter_riverpod/flutter_riverpod.dart';
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
    // Same root as lib/main.dart: the app reads its router from Riverpod.
    await tester.pumpWidget(
      const ProviderScope(
        child: ShopInventoryApp(),
      ),
    );

    await tester.pump();

    expect(find.byType(ShopInventoryApp), findsOneWidget);
  });
}
