import 'package:grapher_builder/src/utils/annotation_data.dart';

abstract class Entity {
  final List<ResolverAnnotation>? resolvers;

  Entity? get parent => null;

  String? get identifier;

  String get location => [parent?.location, identifier].nonNulls.join(' -> ');
  List<String> get rawLocation =>
      [parent?.location, identifier].nonNulls.toList();

  const Entity({required this.resolvers});

  T? find<T extends Entity>() {
    if (this is T) {
      return this as T;
    } else if (parent is T) {
      return parent as T;
    } else {
      return parent?.find<T>();
    }
  }
}

mixin GenericTypeMixin {}

enum ValidationOptional { ignore, over, full }

class ValidationError extends Error {
  final String message;
  final List<String> location;
  final bool isCritical;

  ValidationError(this.message, this.location, {this.isCritical = false});

  factory ValidationError.notFound(String graphName, List<String> location) =>
      ValidationError(
        '$graphName not found in schema',
        location,
        isCritical: true,
      );

  factory ValidationError.nullabilityMismatch(
    bool modelNullable,
    bool schemaNullable,
    List<String> location,
  ) => ValidationError(
    'Nullability mismatch, in schema ${schemaNullable ? 'nullable' : 'non-nullable'}',
    location,
  );

  factory ValidationError.typeMismatch(
    String schemaType,
    List<String> location,
  ) => ValidationError('Type mismatch, in schema $schemaType', location);

  factory ValidationError.parameterMissing(
    String graphName,
    String sourceGraphName,
    List<String> location,
  ) => ValidationError(
    "Parameter $graphName is required in \"$sourceGraphName\"",
    location,
    isCritical: true,
  );

  ValidationError from(List<String> location) {
    final result = [...this.location];
    for (final e in location) {
      if (result.first == e) {
        result.removeAt(0);
      } else {
        break;
      }
    }

    return ValidationError(message, [
      // ...location,
      // '/',
      ...result,
    ], isCritical: isCritical);
  }

  @override
  String toString() {
    return '$location - $message';
  }
}
