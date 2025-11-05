import 'package:analyzer/dart/element/element.dart';

class GrapherException extends Error {
  final String? path;
  final String message;

  GrapherException(this.message, {this.path});

  factory GrapherException.notFound(String path, String name) =>
      GrapherException('Type "$name" not found in schema', path: path);

  @override
  String toString() => [path, message].nonNulls.join(': ');
}

class ValidationError extends GrapherException {
  ValidationError(super.message, {required String super.path});

  factory ValidationError.notFound(String path, String name) =>
      ValidationError('Type "$name" not found in schema', path: path);

  @override
  String toString() => [path, message].nonNulls.join(': ');
}

void throwValidationError(String message, String path) {
  print([path, message].nonNulls.join(': '));
}

void onBuildError(Object e, StackTrace s, [Element? element]) {
  print(e);
}
