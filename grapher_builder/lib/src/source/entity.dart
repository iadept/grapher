import 'package:grapher_builder/src/utils/annotation_data.dart';

abstract class Part {
  final List<ResolverAnnotation>? resolvers;

  Part? get parent => null;

  String? get identifier;

  String get location => [parent?.location, identifier].nonNulls.join('.');

  const Part({required this.resolvers});

  T? find<T>() {
    if (this is T) {
      return this as T;
    } else if (parent is T) {
      return parent as T;
    } else {
      return parent?.find<T>();
    }
  }
}
