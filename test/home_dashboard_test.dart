import 'dart:async';

import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/device_objects.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/home/home_dashboard.dart';
import 'package:automatic_watering_mobile/features/home/home_dashboard_controller.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'controller_settings_sync_test.dart' show settingsResponseDataJson;
import 'home_dashboard_controller_test.dart' show RecordingDashboardApiClient;

void main() {
  testWidgets('close button runs independently of opening on a narrow phone',
      (tester) async {
    final api = RecordingDashboardApiClient()
      ..closeCompletion = Completer<void>();
    await _pumpDashboard(tester, api);
    final closeButton =
        find.widgetWithText(OutlinedButton, 'Закрити всі клапани');
    expect(closeButton, findsOneWidget);
    expect(tester.getSize(closeButton).width, 288);
    expect(tester.getTopLeft(closeButton).dy,
        lessThan(tester.getTopLeft(find.text('Клапани')).dy));
    expect(find.text('Автоматичний полив може знову відкрити клапани'),
        findsOneWidget);

    await tester.tap(closeButton);
    await tester.pump();

    expect(api.closeAllCalls, 1);
    expect(find.byType(AlertDialog), findsNothing);
    final closingButton =
        find.widgetWithText(OutlinedButton, 'Закриваємо клапани…');
    expect(tester.widget<OutlinedButton>(closingButton).onPressed, isNull);
    expect(
        find.descendant(
            of: closingButton,
            matching: find.byType(CircularProgressIndicator)),
        findsOneWidget);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Відкрити клапан'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);

    await tester.tap(closingButton);
    expect(api.closeAllCalls, 1);

    await tester.tap(find.widgetWithText(FilledButton, 'Відкрити клапан'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.widgetWithText(FilledButton, 'Відкрити'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(api.openValveCalls, 1);
    expect(api.closeAllCalls, 1);
    expect(find.text('Закриваємо клапани…'), findsOneWidget);

    api.closeCompletion!.complete();
    await tester.pumpAndSettle();

    expect(
        find.text('Команду закриття всіх клапанів виконано'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(closeButton).onPressed, isNotNull);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Відкрити клапан'))
            .onPressed,
        isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('close failure displays feedback and permits retry',
      (tester) async {
    final api = RecordingDashboardApiClient()
      ..closeException = const LocalControllerApiException();
    await _pumpDashboard(tester, api);
    final button = find.widgetWithText(OutlinedButton, 'Закрити всі клапани');

    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(
        find.text(
            'Не вдалося закрити клапани. Перевірте з’єднання з контролером і спробуйте ще раз'),
        findsOneWidget);
    expect(tester.widget<OutlinedButton>(button).onPressed, isNotNull);
    expect(
        tester
            .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Відкрити клапан'))
            .onPressed,
        isNotNull);

    api.closeException = null;
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(api.closeAllCalls, 2);
    expect(
        find.text('Команду закриття всіх клапанів виконано'), findsOneWidget);
  });

  testWidgets(
      'close remains available with no cached valves and failed metrics refresh',
      (tester) async {
    final api = RecordingDashboardApiClient(
        metricsException: const LocalControllerApiException());
    await _pumpDashboard(tester, api, emptyValves: true);
    expect(find.text('Клапани не налаштовані.'), findsOneWidget);
    expect(find.text('Помилка комунікації з контролером.'), findsOneWidget);

    await tester
        .tap(find.widgetWithText(OutlinedButton, 'Закрити всі клапани'));
    await tester.pumpAndSettle();
    expect(api.closeAllCalls, 1);
    expect(
        find.text('Команду закриття всіх клапанів виконано'), findsOneWidget);
  });
}

Future<void> _pumpDashboard(
    WidgetTester tester, RecordingDashboardApiClient api,
    {bool emptyValves = false}) async {
  tester.view.physicalSize = const Size(320, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final createdAt = DateTime.utc(2026);
  final hub = WateringHub(
    id: 'hub-aa-bb-cc',
    displayName: 'Контролер поливу',
    bleDeviceId: 'AA:BB:CC',
    lastKnownHostname: 'watering-hub-a1b2c3.local',
    apiAccessToken: 'token',
    serverDeviceId: null,
    onboardingCompletedAt: createdAt,
    createdAt: createdAt,
    updatedAt: createdAt,
  );
  final settings = SettingsResponseData.fromJson(settingsResponseDataJson);
  final state = AppState.readyWithHub(
    activeWateringHub: hub,
    activePlanSchema: null,
    settings: settings,
    deviceObjects:
        buildDeviceObjects(wateringHubId: hub.id, settings: settings.settings)
            .where((object) => !emptyValves || object is! ValveObject)
            .toList(),
  );
  final stateStore = AppStateStore()..setState(state);
  final controller = HomeDashboardController(
    stateStore: stateStore,
    settingsRepository: ControllerSettingsRepository(apiClient: api),
    apiClient: api,
  );
  addTearDown(controller.dispose);
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: HomeDashboard(
    state: state,
    controller: controller,
  ))));
  await tester.pumpAndSettle();
}
