import 'package:flutter_test/flutter_test.dart';

import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/automatic_watering_app.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

void main() {
  testWidgets('shows no device state after startup', (tester) async {
    final appController = AppController(
      wateringHubStorage: InMemoryWateringHubStorage(),
      tokenStorage: InMemoryWateringHubTokenStorage(),
    );

    await tester.pumpWidget(AutomaticWateringApp(appController: appController));
    await tester.pumpAndSettle();

    expect(find.text('Automatic Watering'), findsOneWidget);
    expect(find.text('No device'), findsOneWidget);
    expect(find.text('WateringHubState: noDevice'), findsOneWidget);
  });
}
