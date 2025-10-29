import 'package:meta/meta_meta.dart';

@Target({TargetKind.enumType})
/// Used to annotate enum
class GrapherEnum {
  /// The name of the enum in the GraphQL schema.
  final String? name;

  /// If true, validate that all enum values are mapped.
  final bool isStrict;

  /// If true, the enum cannot be extended in the GraphQL schema and you can use
  /// non optional field in models
  final bool isFinal;

  const GrapherEnum({this.name, this.isStrict = true, this.isFinal = false});
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

@Target({TargetKind.classType})
/// Used to annotate type
class GrapherObject {
  /// The name of the type in the GraphQL schema.
  final String? name;

  /// A list of resolver mixins to handle custom serialization/deserialization.
  final List<GrapherResolverMixin>? resolvers;

  const GrapherObject({this.name, this.resolvers});
}

@Target({TargetKind.classType})
/// Used to annotate input type
class GrapherInput {
  /// The name of the input type in the GraphQL schema.
  final String? name;

  /// A list of resolver mixins to handle custom serialization/deserialization.
  final List<GrapherResolverMixin>? resolvers;

  const GrapherInput({this.name, this.resolvers});
}

/// Used to annotate fields in a class.
@Target({TargetKind.field})
/// Used to annotate field of type [GrapherObject] or input [GrapherInput]
class GrapherField {
  /// The name of the field in the GraphQL schema.
  /// By default, it is the same as the Dart field name.
  final String? name;

  /// The name of the input argument for this field.
  /// By default, it is 'input'.
  final String inputName;

  /// The name of the input variable for this field.
  final String? input;

  /// A map of GraphQL type names to Dart types. This is used for union types
  /// and interfaces.
  final Map<String, Type>? union;

  /// The value to use when the enum value is not recognized.
  /// Currently in development.
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

@Target({TargetKind.method, TargetKind.getter, TargetKind.function})
/// Used to annotate query
class GrapherQuery {
  /// The name of the query in the GraphQL schema.
  final String name;

  /// A list of resolver mixins to handle custom serialization/deserialization.
  final List<GrapherResolverMixin>? resolvers;

  const GrapherQuery({required this.name, this.resolvers});
}

@Target({TargetKind.getter, TargetKind.function})
/// Used to annotate mutation
class GrapherMutation {
  /// The name of the mutation in the GraphQL schema.
  final String name;
  final List<GrapherResolverMixin>? resolvers;

  const GrapherMutation({required this.name, this.resolvers});
}

@Target({TargetKind.getter})
/// Used to annotate subscription
class GrapherSubscription {
  /// The name of the subscription in the GraphQL schema.
  final String name;

  /// A list of resolver mixins to handle custom serialization/deserialization.
  final List<GrapherResolverMixin>? resolvers;

  const GrapherSubscription({required this.name, this.resolvers});
}

@Target({TargetKind.classType})
/// Used to annotate resolver
///
/// Resolver can be used to define custom serialization/deserialization
/// for a specific GraphQL type.
///
/// Resolver should extend [GrapherResolverMixin] to implement fromMap and toMap
/// methods.
class GrapherResolver {
  /// GraphQL type name
  final String name;

  /// Query body for custom resolver
  final String? queryBody;

  const GrapherResolver({required this.name, this.queryBody});
}

mixin GrapherResolverMixin<T extends Object> {
  T fromMap(dynamic json);

  dynamic toMap(T value);
}
