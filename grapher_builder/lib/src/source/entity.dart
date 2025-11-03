import 'package:grapher_builder/src/utils/annotation_data.dart';

abstract class Entity {
  final List<ResolverAnnotation>? resolvers;

  Entity? get parent => null;

  String? get identifier;

  String get location => [parent?.location, identifier].nonNulls.join('.');

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
