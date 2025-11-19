import 'package:analyzer/dart/element/element.dart';
import 'package:grapher_builder/src/source/entity.dart';

class GrapherError extends Error {
  final String? path;
  final String message;

  GrapherError(this.message, {this.path});

  factory GrapherError.notFound(String path, String name) =>
      GrapherError('Type "$name" not found in schema', path: path);

  @override
  String toString() => [path, message].nonNulls.join(': ');
}

void throwValidation(ValidationError? error) {
  if (error == null) {
    return;
  }
  print(
    [
      if (error.isCritical) 'ERROR',
      error.location,
      error.message,
    ].nonNulls.join(': '),
  );
}

void onBuildError(Object e, StackTrace s, [Element? element]) {
  print(e);
  // print(s);
}
