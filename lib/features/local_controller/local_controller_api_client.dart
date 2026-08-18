import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../controller_settings/controller_settings.dart';
import '../controller_settings/settings_response_data.dart';
import '../diagnostics/diagnostics_log.dart';
import '../sensors/sensor_metric.dart';
import 'modbus_address_change_models.dart';

class LocalControllerApiException implements Exception {
  const LocalControllerApiException();

  @override
  String toString() => 'LocalControllerApiException';
}

abstract interface class LocalControllerApiClient {
  Future<void> checkSettingsAccess({
    required String ipAddress,
    required String apiAccessToken,
  });

  Future<SettingsResponseData> getSettings({
    required String ipAddress,
    required String apiAccessToken,
  });

  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  });

  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String ipAddress,
    required String apiAccessToken,
  });

  Future<void> openValveForTime({
    required String ipAddress,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  });

  Future<ModbusAddressChangeResult> changeModbusAddress({
    required String ipAddress,
    required String apiAccessToken,
    required ModbusAddressChangeRequest request,
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
    Duration timeout = const Duration(seconds: 8),
  })  : _httpClient = httpClient,
        _diagnosticsLog = diagnosticsLog,
        _timeout = timeout;

  static const automaticWateringHubCertificateFingerprint =
      'DE:B7:7B:DC:88:1B:09:EE:23:19:8D:72:06:FA:E6:AD:F9:E4:8A:F1:5B:1D:EE:BB:4F:58:7F:0E:2F:42:B3:AC';

  final HttpClient _httpClient;
  final DiagnosticsLog _diagnosticsLog;
  final Duration _timeout;

  @override
  Future<void> checkSettingsAccess({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    await getSettings(ipAddress: ipAddress, apiAccessToken: apiAccessToken);
  }

  @override
  Future<SettingsResponseData> getSettings({
    required String ipAddress,
    required String apiAccessToken,
  }) {
    return _send(
      request: _ControllerRequest.get(ipAddress, '/api/settings'),
      apiAccessToken: apiAccessToken,
      parse: _handleSettingsResponse,
    );
  }

  @override
  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) {
    return _send(
      request: _ControllerRequest.put(ipAddress, '/api/settings'),
      apiAccessToken: apiAccessToken,
      body: settings.toJson(),
      parse: _handleEmptyResponse,
    );
  }

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String ipAddress,
    required String apiAccessToken,
  }) {
    return _send(
      request: _ControllerRequest.get(ipAddress, '/api/sensors/metrics'),
      apiAccessToken: apiAccessToken,
      parse: _handleSensorMetricsResponse,
    );
  }

  @override
  Future<void> openValveForTime({
    required String ipAddress,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) {
    return _send(
      request: _ControllerRequest.post(
        ipAddress,
        '/api/valves/open-for-time',
      ),
      apiAccessToken: apiAccessToken,
      body: {'pin': pin, 'seconds': seconds},
      parse: _handleEmptyResponse,
    );
  }

  @override
  Future<ModbusAddressChangeResult> changeModbusAddress({
    required String ipAddress,
    required String apiAccessToken,
    required ModbusAddressChangeRequest request,
  }) {
    return _send(
      request: _ControllerRequest.post(
        ipAddress,
        '/api/service/modbus-address',
      ),
      apiAccessToken: apiAccessToken,
      body: request.toJson(),
      parse: (response, controllerRequest) async {
        await _handleEmptyResponse(response, controllerRequest);
        return ModbusAddressChangeResult(
          currentAddress: request.currentAddress,
          newAddress: request.newAddress,
        );
      },
    );
  }

  Future<T> _send<T>({
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
    final body = await response.transform(utf8.decoder).join().timeout(
          _timeout,
        );
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
}
