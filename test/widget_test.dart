import 'package:flutter_test/flutter_test.dart';

import 'package:automatic_watering_mobile/main.dart';

void main() {
  testWidgets('shows app title', (tester) async {
    await tester.pumpWidget(const AutomaticWateringApp());

    expect(find.text('Automatic Watering'), findsOneWidget);
  });
}
