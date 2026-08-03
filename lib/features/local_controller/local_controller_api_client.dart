import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../../core/api_envelope.dart';
import '../controller_settings/controller_settings.dart';
import '../controller_settings/settings_response_data.dart';
import '../sensors/sensor_metric.dart';

enum LocalControllerApiErrorKind {
  networkUnavailable,
  tlsCertificate,
  tokenInvalid,
  controllerUnavailable,
  unexpectedResponse,
}

class LocalControllerApiException implements Exception {
  const LocalControllerApiException(this.kind, this.message);

  final LocalControllerApiErrorKind kind;
  final String message;

  @override
  String toString() => message;
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
}

class HttpLocalControllerApiClient implements LocalControllerApiClient {
  HttpLocalControllerApiClient({
    HttpClient? httpClient,
    Duration timeout = const Duration(seconds: 8),
    String expectedCertificateFingerprint =
        automaticWateringHubCertificateFingerprint,
  })  : _httpClient = httpClient ??
            _createPinnedHttpClient(
              expectedCertificateFingerprint,
            ),
        _timeout = timeout;

  static const automaticWateringHubCertificateFingerprint =
      'DE:B7:7B:DC:88:1B:09:EE:23:19:8D:72:06:FA:E6:AD:F9:E4:8A:F1:5B:1D:EE:BB:4F:58:7F:0E:2F:42:B3:AC';

  final HttpClient _httpClient;
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
  }) async {
    HttpClientRequest request;
    try {
      request = await _httpClient
          .getUrl(Uri(scheme: 'https', host: ipAddress, path: '/api/settings'))
          .timeout(_timeout);
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $apiAccessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.persistentConnection = false;

      final response = await request.close().timeout(_timeout);
      return await _handleResponse(response);
    } on TimeoutException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller HTTPS request timed out',
      );
    } on HandshakeException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on TlsException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on SocketException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller network is unavailable',
      );
    }
  }

  @override
  Future<void> putSettings({
    required String ipAddress,
    required String apiAccessToken,
    required ControllerSettings settings,
  }) async {
    HttpClientRequest request;
    try {
      request = await _httpClient
          .putUrl(Uri(scheme: 'https', host: ipAddress, path: '/api/settings'))
          .timeout(_timeout);
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $apiAccessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.persistentConnection = false;
      final body = utf8.encode(jsonEncode(settings.toJson()));
      request.contentLength = body.length;
      request.add(body);

      final response = await request.close().timeout(_timeout);
      await _handleEmptyResponse(response);
    } on TimeoutException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller HTTPS request timed out',
      );
    } on HandshakeException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on TlsException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on SocketException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller network is unavailable',
      );
    }
  }

  @override
  Future<List<ControllerSensorMetric>> getSensorMetrics({
    required String ipAddress,
    required String apiAccessToken,
  }) async {
    HttpClientRequest request;
    try {
      request = await _httpClient
          .getUrl(
            Uri(
              scheme: 'https',
              host: ipAddress,
              path: '/api/sensors/metrics',
            ),
          )
          .timeout(_timeout);
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $apiAccessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.persistentConnection = false;

      final response = await request.close().timeout(_timeout);
      return await _handleSensorMetricsResponse(response);
    } on TimeoutException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller HTTPS request timed out',
      );
    } on HandshakeException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on TlsException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on SocketException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller network is unavailable',
      );
    }
  }

  @override
  Future<void> openValveForTime({
    required String ipAddress,
    required String apiAccessToken,
    required int pin,
    required int seconds,
  }) async {
    HttpClientRequest request;
    try {
      request = await _httpClient
          .postUrl(
            Uri(
              scheme: 'https',
              host: ipAddress,
              path: '/api/valves/open-for-time',
            ),
          )
          .timeout(_timeout);
      request.headers
          .set(HttpHeaders.authorizationHeader, 'Bearer $apiAccessToken');
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      request.persistentConnection = false;
      final body = utf8.encode(jsonEncode({'pin': pin, 'seconds': seconds}));
      request.contentLength = body.length;
      request.add(body);

      final response = await request.close().timeout(_timeout);
      await _handleEmptyResponse(response);
    } on TimeoutException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller HTTPS request timed out',
      );
    } on HandshakeException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on TlsException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tlsCertificate,
        'Controller TLS certificate check failed',
      );
    } on SocketException catch (_) {
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.networkUnavailable,
        'Controller network is unavailable',
      );
    }
  }

  Future<SettingsResponseData> _handleResponse(
    HttpClientResponse response,
  ) async {
    final statusCode = response.statusCode;
    if (statusCode == HttpStatus.unauthorized) {
      await response.drain<void>();
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.tokenInvalid,
        'Controller rejected API access token',
      );
    }
    if (statusCode == HttpStatus.serviceUnavailable) {
      await response.drain<void>();
      throw const LocalControllerApiException(
        LocalControllerApiErrorKind.controllerUnavailable,
        'Controller returned service unavailable',
      );
    }
    if (statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw LocalControllerApiException(
        LocalControllerApiErrorKind.unexpectedResponse,
        'Unexpected controller status $statusCode',
      );
    }

    final body = await response.transform(utf8.decoder).join().timeout(
          _timeout,
        );
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Settings envelope must be an object');
      }
      final envelope = ApiEnvelope<SettingsResponseData>.fromJson(
        decoded,
        (data) {
          if (data is! Map<String, Object?>) {
            throw const FormatException('Settings data must be an object');
          }
          return SettingsResponseData.fromJson(data);
        },
      );
      if (!envelope.success) {
        throw FormatException(envelope.error ?? 'Settings envelope failed');
      }
      return envelope.data;
    } on FormatException catch (error) {
      throw LocalControllerApiException(
        LocalControllerApiErrorKind.unexpectedResponse,
        error.message,
      );
    }
  }

  Future<void> _handleEmptyResponse(HttpClientResponse response) async {
    final statusCode = response.statusCode;
    if (statusCode == HttpStatus.ok) {
      await response.drain<void>();
      return;
    }
    if (statusCode == HttpStatus.badRequest) {
      final body = await response.transform(utf8.decoder).join().timeout(
            _timeout,
          );
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        throw const LocalControllerApiException(
          LocalControllerApiErrorKind.unexpectedResponse,
          'Помилка валідації на контролері.',
        );
      }
      final envelope = ApiEnvelope<Map<String, Object?>>.fromJson(
        decoded,
        (data) => data is Map<String, Object?> ? data : <String, Object?>{},
      );
      throw LocalControllerApiException(
        LocalControllerApiErrorKind.unexpectedResponse,
        envelope.error!,
      );
    }
    await response.drain<void>();
    throw LocalControllerApiException(
      LocalControllerApiErrorKind.unexpectedResponse,
      'помилка, http код відповіді - $statusCode',
    );
  }

  Future<List<ControllerSensorMetric>> _handleSensorMetricsResponse(
    HttpClientResponse response,
  ) async {
    final statusCode = response.statusCode;
    if (statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw LocalControllerApiException(
        LocalControllerApiErrorKind.unexpectedResponse,
        'помилка, http код відповіді - $statusCode',
      );
    }

    final body = await response.transform(utf8.decoder).join().timeout(
          _timeout,
        );
    try {
      final decoded = jsonDecode(body);
      if (decoded is! Map<String, Object?>) {
        throw const FormatException('Metrics envelope must be an object');
      }
      final receivedAt = DateTime.now().toUtc();
      final envelope = ApiEnvelope<List<ControllerSensorMetric>>.fromJson(
        decoded,
        (data) {
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
      if (!envelope.success) {
        throw FormatException(envelope.error ?? 'Metrics envelope failed');
      }
      return envelope.data;
    } on FormatException catch (error) {
      throw LocalControllerApiException(
        LocalControllerApiErrorKind.unexpectedResponse,
        error.message,
      );
    }
  }

  static HttpClient _createPinnedHttpClient(String expectedFingerprint) {
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
