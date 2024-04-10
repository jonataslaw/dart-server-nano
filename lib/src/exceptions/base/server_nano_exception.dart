class NanoServerException implements Exception {
  final String message;
  NanoServerException(this.message);

  @override
  String toString() => '(ServerNano): $message';
}
