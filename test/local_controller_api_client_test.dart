import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:automatic_watering_mobile/features/local_controller/diagnostics_log.dart';
import 'package:automatic_watering_mobile/features/local_controller/local_controller_api_client.dart';

void main() {
  test('settings success false logs controller error before parsing data',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
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
      client.getSettings(ipAddress: '192.168.1.42', apiAccessToken: 'token'),
      throwsA(isA<LocalControllerApiException>()),
    );

    expect(diagnosticsLog.entries.single.message,
        'Controller rejected settings read');
  });

  test('empty response success false logs controller error', () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
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
        ipAddress: '192.168.1.42',
        apiAccessToken: 'token',
        pin: 17,
        seconds: 30,
      ),
      throwsA(isA<LocalControllerApiException>()),
    );

    expect(
        diagnosticsLog.entries.single.message, 'Manual valve command rejected');
  });

  test('empty response success true succeeds without diagnostics entry',
      () async {
    final diagnosticsLog = InMemoryDiagnosticsLog();
    final client = HttpLocalControllerApiClient(
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
      ipAddress: '192.168.1.42',
      apiAccessToken: 'token',
      pin: 17,
      seconds: 30,
    );

    expect(diagnosticsLog.entries, isEmpty);
  });
}

class _FakeHttpClient implements HttpClient {
  _FakeHttpClient({required Map<String, Object?> responseBody})
      : _responseBody = responseBody;

  final Map<String, Object?> _responseBody;

  @override
  Future<HttpClientRequest> getUrl(Uri url) async {
    return _FakeHttpClientRequest(_responseBody);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) async {
    return _FakeHttpClientRequest(_responseBody);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) async {
    return _FakeHttpClientRequest(_responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientRequest implements HttpClientRequest {
  _FakeHttpClientRequest(this._responseBody);

  final Map<String, Object?> _responseBody;
  final _headers = _FakeHttpHeaders();

  @override
  HttpHeaders get headers => _headers;

  @override
  bool persistentConnection = false;

  @override
  int contentLength = -1;

  @override
  void add(List<int> data) {}

  @override
  Future<HttpClientResponse> close() async {
    return _FakeHttpClientResponse(_responseBody);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  _FakeHttpClientResponse(Map<String, Object?> body)
      : _body = utf8.encode(jsonEncode(body));

  final List<int> _body;

  @override
  int get statusCode => HttpStatus.ok;

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
