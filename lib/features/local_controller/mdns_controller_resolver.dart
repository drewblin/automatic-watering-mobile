import 'package:flutter/services.dart';

import '../diagnostics/diagnostics_log.dart';

abstract interface class MdnsControllerResolver {
  Future<String?> resolve({
    required String hostname,
    required String localHostname,
  });
}

class MethodChannelMdnsControllerResolver implements MdnsControllerResolver {
  const MethodChannelMdnsControllerResolver({
    MethodChannel channel = const MethodChannel(
      'automatic_watering/mdns_resolver',
    ),
    required DiagnosticsLog diagnosticsLog,
    this.serviceType = '_automatic-watering._tcp.',
    this.timeout = const Duration(seconds: 5),
  })  : _channel = channel,
        _diagnosticsLog = diagnosticsLog;

  final MethodChannel _channel;
  final DiagnosticsLog _diagnosticsLog;
  final String serviceType;
  final Duration timeout;

  @override
  Future<String?> resolve({
    required String hostname,
    required String localHostname,
  }) async {
    try {
      final resolvedIpAddress = await _channel.invokeMethod<String>('resolve', {
        'serviceType': serviceType,
        'serviceName': hostname,
        'localHostname': localHostname,
        'timeoutMs': timeout.inMilliseconds,
      });
      if (resolvedIpAddress == null) {
        recordDiagnosticsIssue(
          diagnosticsLog: _diagnosticsLog,
          message: 'Не вдалося зарезолвити mDNS host контролера.',
          details: 'host=$localHostname',
        );
      } else {
        recordDiagnosticsIssue(
          diagnosticsLog: _diagnosticsLog,
          message: 'mDNS host контролера зарезолвлено.',
          details: 'host=$localHostname; resolvedIpAddress=$resolvedIpAddress',
        );
      }
      return resolvedIpAddress;
    } on MissingPluginException catch (error) {
      recordDiagnosticsIssue(
        diagnosticsLog: _diagnosticsLog,
        message: 'Не вдалося виконати mDNS discovery через platform channel.',
        error: error,
        details: 'host=$localHostname; error=$error',
      );
      return null;
    } on PlatformException catch (error) {
      recordDiagnosticsIssue(
        diagnosticsLog: _diagnosticsLog,
        message: 'Не вдалося виконати mDNS discovery через platform channel.',
        error: error,
        details: 'host=$localHostname; error=$error',
      );
      return null;
    }
  }
}
