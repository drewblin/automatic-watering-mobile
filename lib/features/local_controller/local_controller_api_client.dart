import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../controller_settings/controller_settings.dart';
import '../controller_settings/settings_response_data.dart';
import '../diagnostics/diagnostics_log.dart';
import '../sensors/sensor_metric.dart';
import 'controller_address_service.dart';
import 'modbus_register_write_models.dart';
import 'modbus_register_read_models.dart';

class LocalControllerApiException implements Exception {
  const LocalControllerApiException();

  @override
  String toString() => 'LocalControllerApiException';
}

class LocalControllerConnectionException extends LocalControllerApiException {
  const LocalControllerConnectionException();
}

abstract interface class LocalControllerApiClient {
  Future<void> checkSettingsAccess({
    required String hostname,
    required String apiAccessToken,
  });

  Future<SettingsResponseData> getSettings({
    required String hostname,
    required String apiAccessToken,
  });

  Future<void> putSettings({
    required String hostname,
    required String apiAccessToken,
    required ControllerSettings settings,
  });

  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String hostname,
    required String apiAccessToken,
  });

  Future<void> openValveForTime({
    required String hostname,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  });

  Future<void> closeAllValves({
    required String hostname,
    required String apiAccessToken,
  });

  Future<ModbusRegisterWriteResult> writeModbusRegister({
    required String hostname,
    required String apiAccessToken,
    required ModbusRegisterWriteRequest request,
  });

  Future<ModbusRegisterReadResult> readModbusRegisters({
    required String hostname,
    required String apiAccessToken,
    required ModbusRegisterReadRequest request,
  });
}

typedef _ResponseParser<T> = Future<T> Function(
  HttpClientResponse response,
  _ControllerRequest request,
);

class HttpLocalControllerApiClient implements LocalControllerApiClient {
  HttpLocalControllerApiClient({
    required HttpClient httpClient,
    required DiagnosticsLog diagnosticsLog,
    required ControllerAddressService addressService,
    Duration timeout = const Duration(seconds: 8),
  })  : _httpClient = httpClient,
        _addressService = addressService,
        _diagnosticsLog = diagnosticsLog,
        _timeout = timeout;

  static const automaticWateringHubCertificateFingerprint =
      'DE:B7:7B:DC:88:1B:09:EE:23:19:8D:72:06:FA:E6:AD:F9:E4:8A:F1:5B:1D:EE:BB:4F:58:7F:0E:2F:42:B3:AC';

  final HttpClient _httpClient;
  final ControllerAddressService _addressService;
  final DiagnosticsLog _diagnosticsLog;
  final Duration _timeout;

  @override
  Future<void> checkSettingsAccess({
    required String hostname,
    required String apiAccessToken,
  }) async {
    await getSettings(hostname: hostname, apiAccessToken: apiAccessToken);
  }

  @override
  Future<SettingsResponseData> getSettings({
    required String hostname,
    required String apiAccessToken,
  }) {
    return _send(
      request: _ControllerRequest.get(hostname, '/api/settings'),
      apiAccessToken: apiAccessToken,
      parse: _handleSettingsResponse,
    );
  }

  @override
  Future<void> putSettings({
    required String hostname,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) {
    return _send(
      request: _ControllerRequest.put(hostname, '/api/settings'),
      apiAccessToken: apiAccessToken,
      body: settings.toJson(),
      parse: _handleSettingsSaveResponse,
    );
  }

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String hostname,
    required String apiAccessToken,
  }) {
    return _send(
      request: _ControllerRequest.get(hostname, '/api/sensors/metrics'),
      apiAccessToken: apiAccessToken,
      parse: _handleSensorMetricsResponse,
    );
  }

  @override
  Future<void> openValveForTime({
    required String hostname,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) {
    return _send(
      request: _ControllerRequest.post(
        hostname,
        '/api/valves/open-for-time',
      ),
      apiAccessToken: apiAccessToken,
      body: {'pin': pin, 'seconds': seconds},
      parse: _handleEmptyResponse,
    );
  }

  @override
  Future<void> closeAllValves({
    required String hostname,
    required String apiAccessToken,
  }) {
    return _send(
      request: _ControllerRequest.post(hostname, '/api/valves/close-all'),
      apiAccessToken: apiAccessToken,
      parse: _handleEmptyResponse,
    );
  }

  @override
  Future<ModbusRegisterWriteResult> writeModbusRegister({
    required String hostname,
    required String apiAccessToken,
    required ModbusRegisterWriteRequest request,
  }) {
    return _send(
      request: _ControllerRequest.post(
        hostname,
        '/api/modbus/register/save',
      ),
      apiAccessToken: apiAccessToken,
      body: request.toJson(),
      parse: _handleModbusRegisterWriteResponse,
    );
  }

  @override
  Future<ModbusRegisterReadResult> readModbusRegisters({
    required String hostname,
    required String apiAccessToken,
    required ModbusRegisterReadRequest request,
  }) {
    return _send(
      request: _ControllerRequest.post(hostname, '/api/modbus/register/get'),
      apiAccessToken: apiAccessToken,
      body: request.toJson(),
      parse: _handleModbusRegisterReadResponse,
    );
  }

  Future<T> _send<T>({
    required _ControllerRequest request,
    required String apiAccessToken,
    required _ResponseParser<T> parse,
    Object? body,
  }) async {
    final ipAddress = await _addressService.resolve(hostname: request.host);
    if (ipAddress == null) throw const LocalControllerConnectionException();
    try {
      return await _sendOnce(
        request: request.withHost(ipAddress),
        apiAccessToken: apiAccessToken,
        parse: parse,
        body: body,
      );
    } on LocalControllerConnectionException {
      final refreshedIp = await _addressService.resolve(
        hostname: request.host,
        refresh: true,
      );
      if (refreshedIp == null) rethrow;
      return _sendOnce(
        request: request.withHost(refreshedIp),
        apiAccessToken: apiAccessToken,
        parse: parse,
        body: body,
      );
    }
  }

  Future<T> _sendOnce<T>({
    required _ControllerRequest request,
    required String apiAccessToken,
    required _ResponseParser<T> parse,
    Object? body,
  }) async {
    try {
      final httpRequest = await _openRequest(request).timeout(_timeout);
      httpRequest.headers.set(
        HttpHeaders.authorizationHeader,
        'Bearer $apiAccessToken',
      );
      httpRequest.headers.set(HttpHeaders.acceptHeader, 'application/json');
      httpRequest.persistentConnection = false;

      if (body != null) {
        final encoded = utf8.encode(jsonEncode(body));
        httpRequest.headers.set(
          HttpHeaders.contentTypeHeader,
          'application/json',
        );
        httpRequest.contentLength = encoded.length;
        httpRequest.add(encoded);
      }

      final response = await httpRequest.close().timeout(_timeout);
      return await parse(response, request);
    } on LocalControllerApiException {
      rethrow;
    } catch (error) {
      _recordRequestException(
        request: request,
        error: error,
        message: error.runtimeType.toString(),
      );
      if (error is SocketException || error is TimeoutException) {
        throw const LocalControllerConnectionException();
      }
      throw const LocalControllerApiException();
    }
  }

  Future<HttpClientRequest> _openRequest(_ControllerRequest request) {
    final uri = Uri(
      scheme: 'https',
      host: request.host,
      path: request.path,
    );
    return switch (request.method) {
      'GET' => _httpClient.getUrl(uri),
      'PUT' => _httpClient.putUrl(uri),
      'POST' => _httpClient.postUrl(uri),
      _ => throw StateError('Unsupported HTTP method: ${request.method}'),
    };
  }

  Future<SettingsResponseData> _handleSettingsResponse(
    HttpClientResponse response,
    _ControllerRequest request,
  ) async {
    final body = await _ensureOkBody(response, request);
    return _parseEnvelope(
      body: body,
      statusCode: response.statusCode,
      request: request,
      label: 'Settings',
      parseData: (data) {
        if (data is! Map<String, Object?>) {
          throw const FormatException('Settings data must be an object');
        }
        return SettingsResponseData.fromJson(data);
      },
    );
  }

  Future<void> _handleSettingsSaveResponse(
    HttpClientResponse response,
    _ControllerRequest request,
  ) async {
    final body = await _ensureOkBody(response, request);
    _parseEnvelope<Object?>(
      body: body,
      statusCode: response.statusCode,
      request: request,
      label: 'Settings save',
      parseData: (data) {
        if (data is! Map<String, Object?> || data['restartScheduled'] != true) {
          throw const FormatException('Settings save did not confirm restart');
        }
        return null;
      },
    );
  }

  Future<void> _handleEmptyResponse(
    HttpClientResponse response,
    _ControllerRequest request,
  ) async {
    final body = await _ensureOkBody(response, request);
    _parseEnvelope<Object?>(
      body: body,
      statusCode: response.statusCode,
      request: request,
      label: 'Empty',
      parseData: (_) => null,
    );
  }

  Future<ModbusRegisterWriteResult> _handleModbusRegisterWriteResponse(
    HttpClientResponse response,
    _ControllerRequest request,
  ) async {
    final body = await _ensureOkBody(response, request);
    return _parseEnvelope(
      body: body,
      statusCode: response.statusCode,
      request: request,
      label: 'Modbus register write',
      parseData: (data) {
        if (data is! Map<String, Object?>) {
          throw const FormatException(
              'Modbus register write data must be an object');
        }
        final result = ModbusRegisterWriteResult.fromJson(data);
        if (result.status != 0) {
          throw FormatException(
              'Failed to write Modbus register: status ${result.status}');
        }
        return result;
      },
    );
  }

  Future<ModbusRegisterReadResult> _handleModbusRegisterReadResponse(
    HttpClientResponse response,
    _ControllerRequest request,
  ) async {
    final body = await _ensureOkBody(response, request);
    return _parseEnvelope(
      body: body,
      statusCode: response.statusCode,
      request: request,
      label: 'Modbus register read',
      parseData: (data) {
        if (data is! Map<String, Object?>) {
          throw const FormatException(
              'Modbus register read data must be an object');
        }
        final result = ModbusRegisterReadResult.fromJson(data);
        if (result.status != 0) {
          throw FormatException(
              'Failed to read Modbus registers: status ${result.status}');
        }
        return result;
      },
    );
  }

  Future<List<ControllerSensorMetric>> _handleSensorMetricsResponse(
    HttpClientResponse response,
    _ControllerRequest request,
  ) async {
    final body = await _ensureOkBody(response, request);
    final receivedAt = DateTime.now().toUtc();
    return _parseEnvelope(
      body: body,
      statusCode: response.statusCode,
      request: request,
      label: 'Metrics',
      parseData: (data) {
        if (data is! Map<String, Object?>) {
          throw const FormatException('Metrics data must be an object');
        }
        final sensors = data['sensors'];
        if (sensors is! List) {
          throw const FormatException('Metrics sensors must be a list');
        }
        return sensors
            .map(
              (item) => ControllerSensorMetric.fromJson(
                json: item is Map<String, Object?>
                    ? item
                    : throw const FormatException(
                        'Metrics sensor must be an object',
                      ),
                receivedAt: receivedAt,
              ),
            )
            .toList(growable: false);
      },
    );
  }

  Future<String> _ensureOkBody(
    HttpClientResponse response,
    _ControllerRequest request,
  ) async {
    final String body;
    try {
      body = await response.transform(utf8.decoder).join().timeout(_timeout);
    } catch (error) {
      if (response.statusCode == HttpStatus.ok) rethrow;
      // The controller already returned an HTTP error. An incomplete error
      // body must not turn that rejection into an address-recovery attempt.
      _recordRequestException(
        request: request,
        error: error,
        statusCode: response.statusCode,
        message:
            'Unexpected controller status ${response.statusCode}; incomplete response body',
      );
      throw const LocalControllerApiException();
    }
    if (response.statusCode == HttpStatus.ok) {
      return body;
    }

    _recordResponseFailure(
      request: request,
      statusCode: response.statusCode,
      responseBody: body,
      message: 'Unexpected controller status ${response.statusCode}',
    );
    throw const LocalControllerApiException();
  }

  T _parseEnvelope<T>({
    required String body,
    required int statusCode,
    required _ControllerRequest request,
    required String label,
    required T Function(Object? data) parseData,
  }) {
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        throw FormatException('$label envelope must be an object');
      }
      final success = decoded['success'] as bool? ?? false;
      if (!success) {
        throw FormatException(
            decoded['error'] as String? ?? '$label envelope failed');
      }
      return parseData(decoded['data']);
    } on FormatException catch (error) {
      _recordRequestException(
        request: request,
        error: error,
        statusCode: statusCode,
        responseBody: body,
        message: error.message,
      );
      throw const LocalControllerApiException();
    }
  }

  void _recordResponseFailure({
    required _ControllerRequest request,
    required int statusCode,
    required String responseBody,
    required String message,
  }) {
    _diagnosticsLog.record(
      DiagnosticsLogEntry(
        occurredAt: DateTime.now().toUtc(),
        method: request.method,
        host: request.host,
        path: request.path,
        statusCode: statusCode,
        responseBody: responseBody,
        message: message,
      ),
    );
  }

  void _recordRequestException({
    required _ControllerRequest request,
    required Object error,
    required String message,
    int? statusCode,
    String? responseBody,
  }) {
    _diagnosticsLog.record(
      DiagnosticsLogEntry(
        occurredAt: DateTime.now().toUtc(),
        method: request.method,
        host: request.host,
        path: request.path,
        statusCode: statusCode,
        responseBody: responseBody,
        exceptionType: error.runtimeType.toString(),
        message: message,
        details: error.toString(),
      ),
    );
  }

  static HttpClient createPinnedHttpClient({
    String expectedFingerprint = automaticWateringHubCertificateFingerprint,
  }) {
    final normalizedExpected = _normalizeFingerprint(expectedFingerprint);
    final client = HttpClient();
    client.badCertificateCallback = (certificate, host, port) {
      final actual = _fingerprint(certificate.der);
      return port == 443 && actual == normalizedExpected;
    };
    return client;
  }

  static String _fingerprint(Uint8List der) {
    final digest = sha256.convert(der);
    return digest.bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join()
        .toUpperCase();
  }

  static String _normalizeFingerprint(String fingerprint) {
    return fingerprint.replaceAll(':', '').toUpperCase();
  }
}

class _ControllerRequest {
  const _ControllerRequest({
    required this.method,
    required this.host,
    required this.path,
  });

  const _ControllerRequest.get(String host, String path)
      : this(method: 'GET', host: host, path: path);

  const _ControllerRequest.put(String host, String path)
      : this(method: 'PUT', host: host, path: path);

  const _ControllerRequest.post(String host, String path)
      : this(method: 'POST', host: host, path: path);

  final String method;
  final String host;
  final String path;

  _ControllerRequest withHost(String host) =>
      _ControllerRequest(method: method, host: host, path: path);
}
