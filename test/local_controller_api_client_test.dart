import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:automatic_watering_mobile/app/app_state.dart';
import 'package:automatic_watering_mobile/app/app_state_store.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_repository.dart';
import 'package:automatic_watering_mobile/features/controller_settings/controller_settings_save_controller.dart';
import 'package:automatic_watering_mobile/features/controller_settings/settings_response_data.dart';
import 'package:automatic_watering_mobile/features/watering_hubs/watering_hub.dart';
import 'package:automatic_watering_mobile/features/local_controller/controller_address_service.dart';
import 'package:automatic_watering_mobile/features/local_controller/mdns_controller_resolver.dart';

import 'package:automatic_watering_mobile/features/diagnostics/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_register_write_models.dart';
import 'package:automatic_watering_mobile/features/local_controller/modbus_register_read_models.dart';

import 'controller_settings_sync_test.dart'
    show settingsResponseDataJson, settingsJson;

void main() {
  for (final data in <Object?>[
    {'restartScheduled': false},
    {},
    null,
    {'restartScheduled': 'true'},
    {'restartScheduled': 1},
  ]) {
    test('settings save does not enter reboot without confirmation: $data',
        () async {
      final diagnostics = InMemoryDiagnosticsLog();
      final client = HttpLocalControllerApiClient(
        addressService:
            ControllerAddressService(mdnsControllerResolver: _Resolver()),
        httpClient: _FakeHttpClient(responseBody: {
          'success': true,
          'data': data,
          'error': null,
        }),
        diagnosticsLog: diagnostics,
      );
      final settings = SettingsResponseData.fromJson(settingsResponseDataJson);
      final now = DateTime.utc(2026);
      final stateStore = AppStateStore()
        ..setState(AppState.readyWithHub(
          activeWateringHub: WateringHub(
            id: 'hub',
            displayName: 'Контролер',
            bleDeviceId: 'hub',
            lastKnownHostname: 'watering-hub.local',
            apiAccessToken: 'token',
            serverDeviceId: null,
            onboardingCompletedAt: now,
            createdAt: now,
            updatedAt: now,
          ),
          activePlanSchema: null,
          settings: settings,
          deviceObjects: const [],
        ));
      final controller = ControllerSettingsSaveController(
        stateStore: stateStore,
        repository: ControllerSettingsRepository(apiClient: client),
        rebootDelay: Duration.zero,
        reconnectTimeout: Duration.zero,
      );
      addTearDown(controller.dispose);
      addTearDown(stateStore.dispose);
      final statuses = <ControllerSettingsSaveFlowStatus>[];
      final subscription =
          controller.states.listen((state) => statuses.add(state.status));
      addTearDown(subscription.cancel);

      expect(await controller.save(settings.settings), isFalse);
      expect(statuses, [
        ControllerSettingsSaveFlowStatus.saving,
        ControllerSettingsSaveFlowStatus.saveFailed,
      ]);
      expect(stateStore.state.settings, same(settings));
      expect(diagnostics.entries, hasLength(1));
    });
  }

  test('settings PUT preserves warmup and accepts confirmed restart', () async {
    final transport = _FakeHttpClient(responseBody: {
      'success': true,
      'data': {'restartScheduled': true},
      'error': null,
    });
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: transport,
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );
    final settings = ControllerSettings.fromJson({
      ...settingsJson,
      'globalSettings': {
        ...settingsJson['globalSettings']! as Map<String, Object?>,
        'modbusWarmupMs': 2000,
      },
    });

    await client.putSettings(
        hostname: 'watering-hub.local',
        apiAccessToken: 'token',
        settings: settings);

    expect(transport.lastUri?.path, '/api/settings');
    expect(transport.lastRequestBody?['globalSettings'],
        containsPair('modbusWarmupMs', 2000));
    expect(
        transport.lastRequestBody?.keys,
        unorderedEquals([
          'globalSettings',
          'remoteLogSettings',
          'valveSettings',
          'pressureSensor',
          'magistralWaterCounterSetting',
          'leafWaterCounterSettings',
          'soilSensorSettings',
        ]));
  });

  test('read Modbus registers posts authenticated body and parses values',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final httpClient = _FakeHttpClient(responseBody: {
      'success': true,
      'error': null,
      'data': {
        'status': 0,
        'slaveAddress': 11,
        'registerAddress': 256,
        'quantity': 2,
        'values': [123, 65535],
      },
    });
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: httpClient,
      diagnosticsLog: diagnosticsLog,
    );

    final result = await client.readModbusRegisters(
      hostname: 'watering-hub.local',
      apiAccessToken: 'token',
      request: const ModbusRegisterReadRequest(
        slaveAddress: 11,
        registerAddress: 256,
        quantity: 2,
      ),
    );

    expect(httpClient.lastMethod, 'POST');
    expect(httpClient.lastUri.toString(),
        'https://192.168.1.42/api/modbus/register/get');
    expect(httpClient.lastAuthorization, 'Bearer token');
    expect(httpClient.lastRequestBody,
        {'slaveAddress': 11, 'registerAddress': 256, 'quantity': 2});
    expect(result.status, 0);
    expect(result.slaveAddress, 11);
    expect(result.registerAddress, 256);
    expect(result.quantity, 2);
    expect(result.values, [123, 65535]);
    expect(() => result.values.clear(), throwsUnsupportedError);
    expect(diagnosticsLog.entries, isEmpty);
  });

  test('Modbus read preserves controller-provided integer data', () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: _FakeHttpClient(responseBody: {
        'success': true,
        'error': null,
        'data': {
          'status': 0,
          'slaveAddress': 256,
          'registerAddress': 65535,
          'quantity': 65,
          'values': [-1, 65536],
        },
      }),
      diagnosticsLog: diagnosticsLog,
    );

    final result = await client.readModbusRegisters(
      hostname: 'watering-hub.local',
      apiAccessToken: 'token',
      request: const ModbusRegisterReadRequest(
        slaveAddress: 256,
        registerAddress: 65535,
        quantity: 65,
      ),
    );

    expect(result.slaveAddress, 256);
    expect(result.registerAddress, 65535);
    expect(result.quantity, 65);
    expect(result.values, [-1, 65536]);
    expect(diagnosticsLog.entries, isEmpty);
  });

  for (final data in <Object?>[
    null,
    {},
    {'status': 226},
    ...[
      {'status': 226},
      {'values': null},
      {
        'values': [123, '456']
      },
    ].map((overrides) => <String, Object?>{
          'status': 0,
          'slaveAddress': 11,
          'registerAddress': 256,
          'quantity': 2,
          'values': [123, 456],
          ...overrides,
        }),
  ]) {
    test('Modbus read rejects malformed or failed data $data', () async {
      final diagnosticsLog = InMemoryDiagnosticsLog();
      final client = HttpLocalControllerApiClient(
        addressService:
            ControllerAddressService(mdnsControllerResolver: _Resolver()),
        httpClient: _FakeHttpClient(responseBody: {
          'success': true,
          'error': null,
          'data': data,
        }),
        diagnosticsLog: diagnosticsLog,
      );

      await expectLater(
        client.readModbusRegisters(
          hostname: 'watering-hub.local',
          apiAccessToken: 'token',
          request: const ModbusRegisterReadRequest(
            slaveAddress: 11,
            registerAddress: 256,
            quantity: 2,
          ),
        ),
        throwsA(isA<LocalControllerApiException>()),
      );
      expect(diagnosticsLog.entries.single.path, '/api/modbus/register/get');
      expect(diagnosticsLog.entries.single.responseBody, isNotNull);
    });
  }

  for (final statusCode in [200, 401, 502]) {
    test('Modbus read logs rejection with HTTP $statusCode', () async {
      final diagnosticsLog = InMemoryDiagnosticsLog();
      final httpClient = _FakeHttpClient(
        statusCode: statusCode,
        responseBody: {
          'success': false,
          'error': 'Failed to read Modbus register',
          'data': {'status': 226},
        },
      );
      final client = HttpLocalControllerApiClient(
        addressService:
            ControllerAddressService(mdnsControllerResolver: _Resolver()),
        httpClient: httpClient,
        diagnosticsLog: diagnosticsLog,
      );

      await expectLater(
        client.readModbusRegisters(
          hostname: 'watering-hub.local',
          apiAccessToken: 'token',
          request: const ModbusRegisterReadRequest(
            slaveAddress: 1,
            registerAddress: 0,
            quantity: 1,
          ),
        ),
        throwsA(isA<LocalControllerApiException>()),
      );
      expect(httpClient.requestBodies, hasLength(1));
      expect(diagnosticsLog.entries.single.path, '/api/modbus/register/get');
      expect(diagnosticsLog.entries.single.responseBody,
          contains('Failed to read Modbus register'));
    });
  }

  test('close all valves posts authenticated request without a body', () async {
    final httpClient = _FakeHttpClient(responseBody: {
      'success': true,
      'data': <String, Object?>{},
      'error': null,
    });
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: httpClient,
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    await client.closeAllValves(
      hostname: '192.168.1.42',
      apiAccessToken: 'secret-token',
    );

    expect(httpClient.lastMethod, 'POST');
    expect(httpClient.lastUri.toString(),
        'https://192.168.1.42/api/valves/close-all');
    expect(httpClient.lastAuthorization, 'Bearer secret-token');
    expect(httpClient.lastRequestBody, isNull);
  });

  for (final status in [
    HttpStatus.ok,
    HttpStatus.unauthorized,
    HttpStatus.serviceUnavailable
  ]) {
    test('close all valves rejects failure with HTTP $status', () async {
      final client = HttpLocalControllerApiClient(
        addressService:
            ControllerAddressService(mdnsControllerResolver: _Resolver()),
        httpClient: _FakeHttpClient(
          statusCode: status,
          responseBody: {
            'success': false,
            'data': <String, Object?>{},
            'error': 'Command rejected',
          },
        ),
        diagnosticsLog: InMemoryDiagnosticsLog(),
      );

      await expectLater(
        client.closeAllValves(
            hostname: '192.168.1.42', apiAccessToken: 'token'),
        throwsA(isA<LocalControllerApiException>()),
      );
    });
  }

  test('settings success false logs controller error before parsing data',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: _FakeHttpClient(
        responseBody: {
          'success': false,
          'error': 'Controller rejected settings read',
          'data': null,
        },
      ),
      diagnosticsLog: diagnosticsLog,
      timeout: const Duration(seconds: 1),
    );

    await expectLater(
      client.getSettings(hostname: '192.168.1.42', apiAccessToken: 'token'),
      throwsA(isA<LocalControllerApiException>()),
    );

    expect(diagnosticsLog.entries.single.message,
        'Controller rejected settings read');
  });

  test('empty response success false logs controller error', () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: _FakeHttpClient(
        responseBody: {
          'success': false,
          'error': 'Manual valve command rejected',
          'data': null,
        },
      ),
      diagnosticsLog: diagnosticsLog,
      timeout: const Duration(seconds: 1),
    );

    await expectLater(
      client.openValveForTime(
        hostname: '192.168.1.42',
        apiAccessToken: 'token',
        pin: 17,
        seconds: 30,
      ),
      throwsA(isA<LocalControllerApiException>()),
    );

    expect(
        diagnosticsLog.entries.single.message, 'Manual valve command rejected');
  });

  test('Modbus controller error logs diagnostics and throws marker exception',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: _FakeHttpClient(
        responseBody: {
          'success': false,
          'error': 'Modbus device timeout',
          'data': null,
        },
      ),
      diagnosticsLog: diagnosticsLog,
      timeout: const Duration(seconds: 1),
    );

    await expectLater(
      client.writeModbusRegister(
        hostname: '192.168.1.42',
        apiAccessToken: 'token',
        request: const ModbusRegisterWriteRequest(
          slaveAddress: 11,
          value: 12,
          registerAddress: 256,
        ),
      ),
      throwsA(isA<LocalControllerApiException>()),
    );

    expect(diagnosticsLog.entries.single.message, 'Modbus device timeout');
  });

  test('empty response success true succeeds without diagnostics entry',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: _FakeHttpClient(
        responseBody: {
          'success': true,
          'error': null,
          'data': null,
        },
      ),
      diagnosticsLog: diagnosticsLog,
      timeout: const Duration(seconds: 1),
    );

    await client.openValveForTime(
      hostname: '192.168.1.42',
      apiAccessToken: 'token',
      pin: 17,
      seconds: 30,
    );

    expect(diagnosticsLog.entries, isEmpty);
  });

  test('write Modbus register posts authenticated request body', () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final httpClient = _FakeHttpClient(
      responseBody: {
        'success': true,
        'error': null,
        'data': {
          'status': 0,
          'slaveAddress': 11,
          'registerAddress': 256,
          'value': 12,
        },
      },
    );
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: httpClient,
      diagnosticsLog: diagnosticsLog,
      timeout: const Duration(seconds: 1),
    );

    final result = await client.writeModbusRegister(
      hostname: '192.168.1.42',
      apiAccessToken: 'token',
      request: const ModbusRegisterWriteRequest(
        slaveAddress: 11,
        value: 12,
        registerAddress: 256,
      ),
    );

    expect(result.status, 0);
    expect(result.slaveAddress, 11);
    expect(result.value, 12);
    expect(result.registerAddress, 256);
    expect(httpClient.lastMethod, 'POST');
    expect(httpClient.lastAuthorization, 'Bearer token');
    expect(httpClient.lastUri?.path, '/api/modbus/register/save');
    expect(httpClient.requestBodies, hasLength(1));
    expect(httpClient.lastRequestBody, {
      'slaveAddress': 11,
      'registerAddress': 256,
      'value': 12,
    });
    expect(diagnosticsLog.entries, isEmpty);
  });

  test('Modbus write result comes from the controller response', () async {
    final client = HttpLocalControllerApiClient(
      addressService:
          ControllerAddressService(mdnsControllerResolver: _Resolver()),
      httpClient: _FakeHttpClient(responseBody: {
        'success': true,
        'error': null,
        'data': {
          'status': 0,
          'slaveAddress': 17,
          'registerAddress': 32,
          'value': 42,
        },
      }),
      diagnosticsLog: InMemoryDiagnosticsLog(),
    );

    final result = await client.writeModbusRegister(
      hostname: '192.168.1.42',
      apiAccessToken: 'token',
      request: const ModbusRegisterWriteRequest(
        slaveAddress: 11,
        registerAddress: 256,
        value: 12,
      ),
    );

    expect(result.status, 0);
    expect(result.slaveAddress, 17);
    expect(result.registerAddress, 32);
    expect(result.value, 42);
  });

  for (final data in [
    null,
    {'slaveAddress': 11, 'registerAddress': 256, 'value': 12},
    {'status': 226, 'slaveAddress': 11, 'registerAddress': 256, 'value': 12},
  ]) {
    test('Modbus write rejects invalid or failed result $data', () async {
      final diagnosticsLog = InMemoryDiagnosticsLog();
      final client = HttpLocalControllerApiClient(
        addressService:
            ControllerAddressService(mdnsControllerResolver: _Resolver()),
        httpClient: _FakeHttpClient(responseBody: {
          'success': true,
          'error': null,
          'data': data,
        }),
        diagnosticsLog: diagnosticsLog,
      );

      await expectLater(
        client.writeModbusRegister(
          hostname: '192.168.1.42',
          apiAccessToken: 'token',
          request: const ModbusRegisterWriteRequest(
            slaveAddress: 11,
            registerAddress: 256,
            value: 12,
          ),
        ),
        throwsA(isA<LocalControllerApiException>()),
      );
      expect(diagnosticsLog.entries.single.path, '/api/modbus/register/save');
    });
  }

  for (final statusCode in [HttpStatus.ok, HttpStatus.internalServerError]) {
    test('Modbus write failure with HTTP $statusCode stops the operation',
        () async {
      final diagnosticsLog = InMemoryDiagnosticsLog();
      final httpClient = _FakeHttpClient(
        statusCode: statusCode,
        responseBody: {
          'success': false,
          'data': {
            'status': 226,
            'slaveAddress': 11,
            'registerAddress': 256,
            'value': 12,
          },
          'error': 'Failed to write Modbus register',
        },
      );
      final client = HttpLocalControllerApiClient(
        addressService:
            ControllerAddressService(mdnsControllerResolver: _Resolver()),
        httpClient: httpClient,
        diagnosticsLog: diagnosticsLog,
      );

      await expectLater(
        client.writeModbusRegister(
          hostname: '192.168.1.42',
          apiAccessToken: 'token',
          request: const ModbusRegisterWriteRequest(
            slaveAddress: 11,
            value: 12,
            registerAddress: 256,
          ),
        ),
        throwsA(isA<LocalControllerApiException>()),
      );

      expect(httpClient.requestBodies, hasLength(1));
      expect(diagnosticsLog.entries.single.path, '/api/modbus/register/save');
      expect(diagnosticsLog.entries.single.responseBody,
          contains('Failed to write Modbus register'));
    });
  }
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient(
      {required Map<String, Object?> responseBody,
      this.statusCode = HttpStatus.ok})
      : _responseBody = responseBody;

  final Map<String, Object?> _responseBody;
  final requestBodies = <Map<String, Object?>?>[];
  Uri? lastUri;
  final int statusCode;
  String? lastMethod;
  Object? lastAuthorization;
  Map<String, Object?>? lastRequestBody;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    lastUri = url;
    return _FakeHttpClientRequest(_responseBody, this);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    lastMethod = 'POST';
    lastUri = url;
    return _FakeHttpClientRequest(_responseBody, this);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) async {
    lastUri = url;
    return _FakeHttpClientRequest(_responseBody, this);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._responseBody, this._client);

  final Map<String, Object?> _responseBody;
  final _FakeHttpClient _client;
  final _headers = _FakeHttpHeaders();
  final _body = <int>[];

  @override
  HttpHeaders get headers => _headers;

  @override
  bool persistentConnection = false;

  @override
  int contentLength = -1;

  @override
  void add(List<int> data) {
    _body.addAll(data);
  }

  @override
  Future<HttpClientResponse> close() async {
    _client.lastAuthorization =
        _headers._values[HttpHeaders.authorizationHeader];
    if (_body.isNotEmpty) {
      _client.lastRequestBody =
          jsonDecode(utf8.decode(_body)) as Map<String, Object?>;
    }
    _client.requestBodies.add(_client.lastRequestBody);
    return _FakeHttpClientResponse(
      _responseBody,
      _client.statusCode,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(Map<String, Object?> body, this.statusCode)
      : _body = utf8.encode(jsonEncode(body));

  final List<int> _body;

  @override
  final int statusCode;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    return Stream<List<int>>.value(_body).listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpHeaders implements HttpHeaders {
  final _values = <String, Object>{};

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _values[name] = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Resolver implements MdnsControllerResolver {
  @override
  Future<String?> resolve(
          {required String hostname, required String localHostname}) async =>
      '192.168.1.42';
}
