import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:automatic_watering_mobile/app/app_startup_service.dart';
import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/controller_address_service.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/mdns_controller_resolver.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_address_change_models.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/storage/in_memory_watering_hub_storage.dart';

import 'controller_settings_sync_test.dart'
    show settingsJson, settingsResponseDataJson;

const oldIp = '192.168.1.42';
const newIp = '192.168.1.77';
const hostname = 'watering-hub.local';
const token = 'controller-token';

void main() {
  late _Resolver resolver;
  late ControllerAddressService addresses;
  late _HttpClient transport;
  late HttpLocalControllerApiClient client;
  late InMemoryDiagnosticsLog diagnosticsLog;

  Future<void> read() =>
      client.getSensorMetrics(hostname: hostname, apiAccessToken: token);

  setUp(() {
    resolver = _Resolver();
    addresses = ControllerAddressService(mdnsControllerResolver: resolver);
    transport = _HttpClient();
    diagnosticsLog = InMemoryDiagnosticsLog();
    client = HttpLocalControllerApiClient(
      httpClient: transport,
      diagnosticsLog: diagnosticsLog,
      addressService: addresses,
    );
  });

  test('first request resolves hostname and subsequent requests use cached IP',
      () async {
    await read();
    resolver.address = newIp;
    await read();
    expect(transport.hosts, [oldIp, oldIp]);
    expect(resolver.calls, 1);
    expect(transport.authorizations, everyElement('Bearer $token'));
  });

  test('network failure refreshes only the service cache', () async {
    await addresses.resolve(hostname: hostname);
    resolver.address = newIp;
    transport.respond = (_, uri) async {
      if (uri.host == oldIp) throw const SocketException('Address changed');
      return _HttpResponse();
    };
    await read();
    await read();
    expect(transport.hosts, [oldIp, newIp, newIp]);
    expect(resolver.calls, 2);
  });

  for (final command in ['openValve', 'closeAll', 'modbus', 'settings']) {
    test('$command retries once with the same payload at the refreshed IP',
        () async {
      await addresses.resolve(hostname: hostname);
      resolver.address = newIp;
      transport.respond = (_, uri) async {
        if (uri.host == oldIp) throw TimeoutException('Response lost');
        return _HttpResponse(
            data: command == 'modbus'
                ? const {
                    'status': 0,
                    'slaveAddress': 1,
                    'registerAddress': 256,
                    'value': 2
                  }
                : const {'sensors': []});
      };
      switch (command) {
        case 'openValve':
          await client.openValveForTime(
              hostname: hostname, apiAccessToken: token, pin: 17, seconds: 30);
        case 'closeAll':
          await client.closeAllValves(
              hostname: hostname, apiAccessToken: token);
        case 'modbus':
          await client.writeModbusRegister(
              hostname: hostname,
              apiAccessToken: token,
              request: const ModbusRegisterWriteRequest(
                  slaveAddress: 1, value: 2, registerAddress: 256));
        case 'settings':
          await client.putSettings(
              hostname: hostname,
              apiAccessToken: token,
              settings: ControllerSettings.fromJson(settingsJson));
      }
      expect(transport.hosts, [oldIp, newIp]);
      expect(transport.bodies, hasLength(2));
      expect(transport.bodies.first, transport.bodies.last);
      if (command == 'openValve') {
        expect(transport.bodies.last, {'pin': 17, 'seconds': 30});
      }
      if (command == 'settings') {
        expect(transport.bodies.last,
            ControllerSettings.fromJson(settingsJson).toJson());
      }
      expect(transport.authorizations, everyElement('Bearer $token'));
      expect(resolver.calls, 2);
    });
  }

  test('retry is allowed even when mDNS returns the same IP', () async {
    var attempts = 0;
    transport.respond = (_, __) async {
      if (++attempts == 1) throw const SocketException('Temporary outage');
      return _HttpResponse();
    };
    await read();
    expect(transport.hosts, [oldIp, oldIp]);
    expect(resolver.calls, 2);
  });

  test('second network failure is final', () async {
    transport.respond = (_, __) => throw const SocketException('Offline');
    await expectLater(
        read(), throwsA(isA<LocalControllerConnectionException>()));
    expect(transport.hosts, [oldIp, oldIp]);
    expect(resolver.calls, 2);
  });

  test('command with two lost responses records both failures in diagnostics',
      () async {
    transport.respond = (_, __) => throw TimeoutException('Response lost');
    await expectLater(
        client.closeAllValves(hostname: hostname, apiAccessToken: token),
        throwsA(isA<LocalControllerConnectionException>()));
    expect(transport.hosts, [oldIp, oldIp]);
    expect(resolver.calls, 2);
    expect(diagnosticsLog.entries, hasLength(2));
    for (final entry in diagnosticsLog.entries) {
      expect(entry.method, 'POST');
      expect(entry.host, oldIp);
      expect(entry.path, '/api/valves/close-all');
      expect(entry.exceptionType, 'TimeoutException');
      expect(entry.details, contains('Response lost'));
    }
  });

  test('missing initial mDNS address fails without sending HTTP', () async {
    resolver.address = null;
    await expectLater(
        read(), throwsA(isA<LocalControllerConnectionException>()));
    expect(transport.hosts, isEmpty);
    expect(resolver.calls, 1);
  });

  test('missing refreshed address does not send another HTTP request',
      () async {
    await addresses.resolve(hostname: hostname);
    resolver.address = null;
    transport.respond = (_, __) => throw const SocketException('Offline');
    await expectLater(
        read(), throwsA(isA<LocalControllerConnectionException>()));
    expect(transport.hosts, [oldIp]);
    expect(resolver.calls, 2);
  });

  for (final error in [
    const HandshakeException('Bad certificate'),
    const FormatException('Malformed response')
  ]) {
    test('${error.runtimeType} does not refresh mDNS', () async {
      transport.respond = (_, __) => throw error;
      await expectLater(read(), throwsA(isA<LocalControllerApiException>()));
      expect(resolver.calls, 1);
      expect(transport.hosts, [oldIp]);
    });
  }

  for (final bodyError in [
    null,
    const SocketException('Body connection lost'),
    TimeoutException('Body timed out')
  ]) {
    test('HTTP rejection with body error $bodyError does not retry', () async {
      transport.respond =
          (_, __) async => _HttpResponse(statusCode: 401, bodyError: bodyError);
      await expectLater(read(), throwsA(isA<LocalControllerApiException>()));
      expect(resolver.calls, 1);
      expect(transport.hosts, [oldIp]);
    });
  }

  test('different hostnames never share a cached address', () async {
    expect(await addresses.resolve(hostname: hostname), oldIp);
    resolver.address = newIp;
    expect(await addresses.resolve(hostname: 'other-controller.local'), newIp);
    expect(await addresses.resolve(hostname: hostname), oldIp);
    expect(resolver.calls, 2);
  });

  test('new address service has no persisted IP fallback', () async {
    await addresses.resolve(hostname: hostname);
    resolver.address = null;
    final restarted =
        ControllerAddressService(mdnsControllerResolver: resolver);
    expect(await restarted.resolve(hostname: hostname), isNull);
  });

  test(
      'startup resolves through the HTTP client without updating the saved hub',
      () async {
    final hub = WateringHub(
      id: 'hub',
      displayName: 'Controller',
      bleDeviceId: 'ble',
      lastKnownHostname: hostname,
      apiAccessToken: null,
      serverDeviceId: null,
      onboardingCompletedAt: DateTime.utc(2026),
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    final storage = InMemoryWateringHubStorage()..activeHub = hub;
    final state = AppStateStore();
    addTearDown(state.dispose);
    transport.respond =
        (_, __) async => _HttpResponse(data: settingsResponseDataJson);
    await AppStartupService(
      stateStore: state,
      wateringHubStorage: storage,
      tokenStorage: InMemoryWateringHubTokenStorage()..tokens[hub.id] = token,
      controllerSettingsRepository:
          ControllerSettingsRepository(apiClient: client),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    ).initialize();
    expect(state.state.startupStatus, AppStartupStatus.ready);
    expect(storage.activeHub, same(hub));
    expect(transport.hosts, [oldIp]);
    expect(resolver.calls, 1);
  });

  test('hub access uses hostname and ignores legacy persisted IP', () {
    final json = <String, Object?>{
      'id': 'hub',
      'displayName': 'Controller',
      'bleDeviceId': 'ble',
      'lastKnownHostname': hostname,
      'lastKnownIpAddress': oldIp,
      'serverDeviceId': null,
      'onboardingCompletedAt': '2026-01-01T00:00:00Z',
      'createdAt': '2026-01-01T00:00:00Z',
      'updatedAt': '2026-01-01T00:00:00Z',
    };
    final hub = WateringHub.fromJson(json).copyWith(apiAccessToken: token);
    expect(hub.readyAccess?.hostname, hostname);
    expect(hub.toJson(), isNot(contains('lastKnownIpAddress')));
  });
}

class _Resolver implements MdnsControllerResolver {
  int calls = 0;
  String? address = oldIp;
  @override
  Future<String?> resolve(
      {required String hostname, required String localHostname}) async {
    calls++;
    expect(localHostname, hostname);
    return address;
  }
}

class _HttpClient implements HttpClient {
  final hosts = <String>[];
  final authorizations = <Object?>[];
  final bodies = <Object?>[];
  Object? Function(Uri uri)? openError;
  Future<_HttpResponse> Function(String method, Uri uri) respond =
      (_, uri) async {
    return _HttpResponse();
  };

  Future<HttpClientRequest> _open(String method, Uri uri) async {
    hosts.add(uri.host);
    final error = openError?.call(uri);
    if (error != null) throw error;
    return _HttpRequest(this, method, uri);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) => _open('GET', url);
  @override
  Future<HttpClientRequest> putUrl(Uri url) => _open('PUT', url);
  @override
  Future<HttpClientRequest> postUrl(Uri url) => _open('POST', url);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HttpRequest implements HttpClientRequest {
  _HttpRequest(this.client, this.method, this.uri);
  final _HttpClient client;
  @override
  final String method;
  @override
  final Uri uri;
  @override
  final _Headers headers = _Headers();
  @override
  bool persistentConnection = false;
  @override
  int contentLength = -1;
  final _body = <int>[];
  @override
  void add(List<int> data) {
    _body.addAll(data);
  }

  @override
  Future<HttpClientResponse> close() {
    client.authorizations.add(headers.authorization);
    client.bodies.add(_body.isEmpty ? null : jsonDecode(utf8.decode(_body)));
    return client.respond(method, uri);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Headers implements HttpHeaders {
  Object? authorization;
  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    if (name == HttpHeaders.authorizationHeader) authorization = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _HttpResponse extends Stream<List<int>> implements HttpClientResponse {
  _HttpResponse(
      {this.statusCode = 200,
      this.data = const {'sensors': []},
      this.bodyError});
  final Object? data;
  final Object? bodyError;
  @override
  final int statusCode;
  @override
  StreamSubscription<List<int>> listen(void Function(List<int>)? onData,
          {Function? onError, void Function()? onDone, bool? cancelOnError}) =>
      (bodyError != null
              ? Stream<List<int>>.error(bodyError!)
              : Stream.value(
                  utf8.encode(jsonEncode({'success': true, 'data': data}))))
          .listen(onData,
              onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
