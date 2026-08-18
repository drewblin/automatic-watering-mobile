class DiagnosticsLogEntry {
  const DiagnosticsLogEntry({
    required this.occurredAt,
    required this.message,
    this.method,
    this.host,
    this.path,
    this.statusCode,
    this.responseBody,
    this.exceptionType,
    this.details,
  });

  final DateTime occurredAt;
  final String? method;
  final String? host;
  final String? path;
  final String message;
  final int? statusCode;
  final String? responseBody;
  final String? exceptionType;
  final String? details;
}

abstract interface class DiagnosticsLog {
  List<DiagnosticsLogEntry> get entries;

  void record(DiagnosticsLogEntry entry);

  void clear();
}

void recordDiagnosticsIssue({
  required DiagnosticsLog diagnosticsLog,
  required String message,
  Object? error,
  String? details,
}) {
  diagnosticsLog.record(
    DiagnosticsLogEntry(
      occurredAt: DateTime.now().toUtc(),
      message: message,
      exceptionType: error?.runtimeType.toString(),
      details:
          details ?? (error == null ? null : truncateDiagnosticsDetails(error)),
    ),
  );
}

String truncateDiagnosticsDetails(Object error) {
  final raw = error.toString();
  if (raw.length <= 240) {
    return raw;
  }
  return '${raw.substring(0, 240)}...';
}

class InMemoryDiagnosticsLog implements DiagnosticsLog {
  InMemoryDiagnosticsLog({this.maxEntries = 100}) : assert(maxEntries > 0);

  final int maxEntries;
  final List<DiagnosticsLogEntry> _entries = [];

  @override
  List<DiagnosticsLogEntry> get entries => List.unmodifiable(_entries.reversed);

  @override
  void record(DiagnosticsLogEntry entry) {
    _entries.add(entry);
    while (_entries.length > maxEntries) {
      _entries.removeAt(0);
    }
  }

  @override
  void clear() {
    _entries.clear();
  }
}
