import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/mdns_controller_resolver.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('method channel resolver logs successful mDNS resolve', () async {
    const channel = MethodChannel('test/mdns_success_resolver');
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final resolver = MethodChannelMdnsControllerResolver(
      channel: channel,
      diagnosticsLog: diagnosticsLog,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => '192.168.1.77');

    final resolvedIpAddress = await resolver.resolve(
      hostname: 'watering-hub-a1b2c3',
      localHostname: 'watering-hub-a1b2c3.local',
    );

    expect(resolvedIpAddress, '192.168.1.77');
    expect(
      diagnosticsLog.entries.single.message,
      'mDNS host контролера зарезолвлено.',
    );
    expect(diagnosticsLog.entries.single.details, contains('192.168.1.77'));

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('method channel resolver logs missing mDNS address', () async {
    const channel = MethodChannel('test/mdns_missing_resolver');
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final resolver = MethodChannelMdnsControllerResolver(
      channel: channel,
      diagnosticsLog: diagnosticsLog,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    final resolvedIpAddress = await resolver.resolve(
      hostname: 'watering-hub-a1b2c3',
      localHostname: 'watering-hub-a1b2c3.local',
    );

    expect(resolvedIpAddress, isNull);
    expect(
      diagnosticsLog.entries.single.message,
      'Не вдалося зарезолвити mDNS host контролера.',
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('method channel resolver logs platform failures', () async {
    const channel = MethodChannel('test/mdns_resolver');
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final resolver = MethodChannelMdnsControllerResolver(
      channel: channel,
      diagnosticsLog: diagnosticsLog,
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      throw PlatformException(
        code: 'resolve_failed',
        message: 'mDNS unavailable',
      );
    });

    final resolvedIpAddress = await resolver.resolve(
      hostname: 'watering-hub-a1b2c3',
      localHostname: 'watering-hub-a1b2c3.local',
    );

    expect(resolvedIpAddress, isNull);
    expect(diagnosticsLog.entries, hasLength(1));
    expect(
      diagnosticsLog.entries.single.message,
      'Не вдалося виконати mDNS discovery через platform channel.',
    );
    expect(diagnosticsLog.entries.single.exceptionType, 'PlatformException');

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });
}
