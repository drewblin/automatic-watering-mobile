import 'package:automatic_watering_mobile/features/local_controller/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/service_console/service_console_dependencies.dart';
import 'package:automatic_watering_mobile/features/service_console/service_console_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows diagnostics empty state', (tester) async {
    await tester.pumpWidget(
      _TestApp(diagnosticsLog: InMemoryDiagnosticsLog()),
    );

    expect(find.text('Сервісна консоль'), findsOneWidget);
    expect(find.text('Діагностика'), findsOneWidget);
    expect(find.text('Діагностичних записів немає.'), findsOneWidget);
  });

  testWidgets('renders diagnostics entries newest first with technical fields',
      (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog()
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 9),
          message: 'Старіша помилка',
          method: 'GET',
          host: '192.168.1.42',
          path: '/api/settings',
          statusCode: 500,
          responseBody: '{"success":false}',
          exceptionType: 'FormatException',
          details: 'Settings envelope failed',
        ),
      )
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 10),
          message: 'Новіша помилка',
          method: 'POST',
          host: 'controller.local',
          path: '/api/valves/open-for-time',
          statusCode: 400,
        ),
      );

    await tester.pumpWidget(_TestApp(diagnosticsLog: diagnosticsLog));

    final newerTop = tester.getTopLeft(find.text('Новіша помилка')).dy;
    final olderTop = tester.getTopLeft(find.text('Старіша помилка')).dy;
    expect(newerTop, lessThan(olderTop));
    expect(find.textContaining('Метод: POST'), findsOneWidget);
    expect(find.textContaining('Хост: controller.local'), findsOneWidget);
    expect(
      find.textContaining('Шлях: /api/valves/open-for-time'),
      findsOneWidget,
    );
    expect(find.textContaining('HTTP статус: 400'), findsOneWidget);
    expect(find.text('Тіло відповіді'), findsOneWidget);
    expect(find.text('Деталі'), findsOneWidget);
  });

  testWidgets('shows diagnostics details without masking local memory data',
      (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog()
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 10),
          message: 'Authorization: Bearer 0123456789abcdef0123456789abcdef',
          responseBody: '{"remoteLogSettings":{"token":"log-token"}}',
          details: 'apiAccessToken=controller-token&next=true',
        ),
      );

    expect(diagnosticsLog.entries.single.message, contains('0123456789abcdef'));

    await tester.pumpWidget(_TestApp(diagnosticsLog: diagnosticsLog));

    await tester.tap(find.text('Тіло відповіді'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Деталі'));
    await tester.pumpAndSettle();

    expect(find.textContaining('0123456789abcdef'), findsOneWidget);
    expect(find.textContaining('log-token'), findsOneWidget);
    expect(find.textContaining('controller-token'), findsOneWidget);
  });

  testWidgets('clears diagnostics entries after confirmation', (tester) async {
    final diagnosticsLog = InMemoryDiagnosticsLog()
      ..record(
        DiagnosticsLogEntry(
          occurredAt: DateTime.utc(2026, 8, 16, 10),
          message: 'Помилка комунікації',
        ),
      );

    await tester.pumpWidget(_TestApp(diagnosticsLog: diagnosticsLog));

    await tester.tap(find.byTooltip('Очистити'));
    await tester.pumpAndSettle();

    expect(find.text('Очистити діагностичний лог?'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Очистити'));
    await tester.pumpAndSettle();

    expect(diagnosticsLog.entries, isEmpty);
    expect(find.text('Помилка комунікації'), findsNothing);
    expect(find.text('Діагностичних записів немає.'), findsOneWidget);
  });
}

class _TestApp extends StatelessWidget {
  const _TestApp({required this.diagnosticsLog});

  final DiagnosticsLog diagnosticsLog;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: ServiceConsoleScreen(
        dependencies: ServiceConsoleDependencies(
          diagnosticsLog: diagnosticsLog,
        ),
      ),
    );
  }
}
