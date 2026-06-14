class ApiEnvelope<T> {
  const ApiEnvelope({
    required this.success,
    required this.data,
    required this.error,
  });

  final bool success;
  final T data;
  final String? error;

  factory ApiEnvelope.fromJson(
    Map<String, Object?> json,
    T Function(Object? data) parseData,
  ) {
    return ApiEnvelope<T>(
      success: json['success'] as bool? ?? false,
      data: parseData(json['data']),
      error: json['error'] as String?,
    );
  }

  Map<String, Object?> toJson(Object? Function(T data) serializeData) {
    return {
      'success': success,
      'data': serializeData(data),
      'error': error,
    };
  }
}
