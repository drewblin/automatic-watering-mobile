class FatalAppException implements Exception {
  const FatalAppException(this.message, this.cause);

  final String message;
  final Object cause;

  @override
  String toString() => '$message: $cause';
}
