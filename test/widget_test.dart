import 'package:flutter_test/flutter_test.dart';
import 'package:shopmate/app/app.dart';

void main() {
  testWidgets('ShopMate app loads', (tester) async {
    await tester.pumpWidget(
      const ShopInventoryApp(),
    );

    expect(find.text('ShopMate'), findsOneWidget);
  });
}