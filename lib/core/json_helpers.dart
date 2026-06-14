DateTime readDateTime(Object? value, String fieldName) {
  if (value is String) {
    return DateTime.parse(value);
  }
  throw FormatException('Missing or invalid DateTime field: $fieldName');
}

double readDouble(Object? value, String fieldName) {
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('Missing or invalid number field: $fieldName');
}

int readInt(Object? value, String fieldName) {
  if (value is int) {
    return value;
  }
  throw FormatException('Missing or invalid integer field: $fieldName');
}

String readString(Object? value, String fieldName) {
  if (value is String) {
    return value;
  }
  throw FormatException('Missing or invalid string field: $fieldName');
}

List<T> readList<T>(
  Object? value,
  String fieldName,
  T Function(Object? item) parseItem,
) {
  if (value is List) {
    return List<T>.unmodifiable(value.map(parseItem));
  }
  throw FormatException('Missing or invalid list field: $fieldName');
}

Map<String, Object?> readObject(Object? value, String fieldName) {
  if (value is Map) {
    return value.cast<String, Object?>();
  }
  throw FormatException('Missing or invalid object field: $fieldName');
}
