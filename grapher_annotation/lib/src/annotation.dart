import 'package:meta/meta_meta.dart';

// Enum

@Target({TargetKind.enumType})
/// Used to annotate enums that will be used in GraphQL schema.
class GrapherEnum {
  /// The name of the enum in the GraphQL schema.
  final String? name;

  /// If true, validate that all enum values are mapped.
  final bool isStrict;

  const GrapherEnum({this.name, this.isStrict = true});
}

@Target({TargetKind.enumValue})
/// Used to annotate enum values in a GraphQL schema.
class GrapherEnumValue {
  /// The name of the enum value in the GraphQL schema.
  /// By default, it is the same as the Dart enum value name.
  /// If you want to use a different name, you can specify it.
  final String? name;

  const GrapherEnumValue({this.name});
}

// Entity

@Target({TargetKind.classType})
class GrapherObject {
  final String? name;
  final List<GrapherResolverMixin>? resolvers;

  const GrapherObject({this.name, this.resolvers});
}

/// Used to annotate fields in a class.
@Target({TargetKind.field})
class GrapherField {
  /// The name of the field in the GraphQL schema.
  /// By default, it is the same as the Dart field name.
  final String? name;
  final String inputName;
  final String? input;

  /// A map of GraphQL type names to Dart types. This is used for union types
  /// and interfaces.
  final Map<String, Type>? union;
  final Enum? unknownValue;

  /// If true, this field will be skipped in query generation.
  /// Used for custom resolve fields
  ///
  /// Example
  /// final String code;
  /// @GrapherField(name: 'code', skipInQuery: true)
  /// EnumType get codeType;
  ///
  /// codeType use code value
  final bool skipInQuery;

  const GrapherField({
    this.name,
    this.inputName = 'input',
    this.input,
    this.union,
    this.unknownValue,
    this.skipInQuery = false,
  });
}

// Input

@Target({TargetKind.classType})
class GrapherInput {
  final String? name;
  final List<GrapherResolverMixin>? resolvers;

  const GrapherInput({this.name, this.resolvers});
}

@Target({TargetKind.method, TargetKind.getter, TargetKind.function})
class GrapherQuery {
  final String name;
  final List<GrapherResolverMixin>? resolvers;

  const GrapherQuery({required this.name, this.resolvers});
}

@Target({TargetKind.getter, TargetKind.function})
class GrapherMutation {
  final String name;
  final List<GrapherResolverMixin>? resolvers;

  const GrapherMutation({required this.name, this.resolvers});
}

@Target({TargetKind.getter})
class GrapherSubscription {
  final String name;
  final List<GrapherResolverMixin>? resolvers;

  const GrapherSubscription({required this.name, this.resolvers});
}

// Resolver

@Target({TargetKind.classType})
class GrapherResolver {
  final String name;
  final String? queryBody;

  const GrapherResolver({required this.name, this.queryBody});
}

mixin GrapherResolverMixin<T extends Object> {
  T fromMap(dynamic json);

  dynamic toMap(T value);
}

// Custom

@Target({TargetKind.classType})
class GrapherCustom<T extends Object> {
  final String? name;
  final String? queryBody;
  final T Function(dynamic json)? fromMap;
  final dynamic Function(T value)? toMap;
  final List<GrapherResolverMixin>? resolvers;

  const GrapherCustom({
    this.name,
    this.queryBody,
    required this.fromMap,
    required this.toMap,
    this.resolvers,
  });
}
