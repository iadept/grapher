import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_annotation/grapher_annotation.dart';
import 'package:grapher_builder/src/utils/exception.dart';
import 'package:source_gen/source_gen.dart';

class EnumAnnotation {
  final String? name;
  final bool isStrict;
  final bool isFinal;

  const EnumAnnotation._({
    required this.name,
    required this.isStrict,
    required this.isFinal,
  });

  factory EnumAnnotation.read(ConstantReader reader) {
    return EnumAnnotation._(
      name: reader.peek('name')?.stringValue,
      isStrict: reader.peek('isStrict')?.boolValue ?? true,
      isFinal: reader.peek('isFinal')?.boolValue ?? false,
    );
  }

  static EnumAnnotation? peek(EnumElement element) =>
      _getAnnotation<GrapherEnum, EnumAnnotation>(element, EnumAnnotation.read);
}

class EnumValueAnnotation {
  final String? name;

  const EnumValueAnnotation({required this.name});

  factory EnumValueAnnotation.read(ConstantReader reader) {
    return EnumValueAnnotation(name: reader.peek('name')?.stringValue);
  }

  static EnumValueAnnotation? peek(FieldElement element) =>
      _getAnnotation<GrapherEnumValue, EnumValueAnnotation>(
        element,
        EnumValueAnnotation.read,
      );
}

// Object

mixin BaseAnnotation {
  String? get name;
  List<ResolverAnnotation>? get resolvers;
}

class ObjectAnnotation with BaseAnnotation {
  @override
  final String? name;
  final bool createToMap;
  @override
  final List<ResolverAnnotation>? resolvers;

  const ObjectAnnotation._({
    required this.name,
    required this.createToMap,
    this.resolvers,
  });

  factory ObjectAnnotation.read(ConstantReader reader) {
    return ObjectAnnotation._(
      name: reader.peek('name')?.stringValue,
      createToMap: reader.peek('createToMap')?.boolValue ?? false,
      resolvers: _getResolvers(reader),
    );
  }

  static ObjectAnnotation? peek(InterfaceElement element) =>
      _getAnnotation<GrapherObject, ObjectAnnotation>(
        element,
        ObjectAnnotation.read,
      );
}

class FieldAnnotation {
  final String? name;
  final String inputName;
  final String? input;
  final Map<String, DartType>? union;

  final DartObject? defaultValue;
  final bool skipInQuery;

  const FieldAnnotation({
    this.name,
    required this.inputName,
    this.input,
    this.union,
    this.defaultValue,
    this.skipInQuery = false,
  });

  factory FieldAnnotation.read(ConstantReader reader) {
    final unionParam = reader.peek('union');

    DartObject? defaultValue;
    final defaultValueParam = reader.peek('defaultValue');
    if (defaultValueParam != null) {
      defaultValue = defaultValueParam.objectValue;
    }

    return FieldAnnotation(
      name: reader.peek('name')?.stringValue,
      inputName: reader.read('inputName').stringValue,
      input: reader.peek('input')?.stringValue,
      union: unionParam?.mapValue.map((key, value) {
        return MapEntry<String, DartType>(
          key!.toStringValue()!,
          value!.toTypeValue()!,
        );
      }),
      defaultValue: defaultValue,
      skipInQuery: reader.peek('skipInQuery')?.boolValue ?? false,
    );
  }

  static FieldAnnotation? peek(FieldElement element) =>
      _getAnnotation<GrapherField, FieldAnnotation>(
        element,
        FieldAnnotation.read,
      );
}

class InputAnnotation with BaseAnnotation {
  @override
  final String? name;
  @override
  final List<ResolverAnnotation>? resolvers;

  const InputAnnotation({required this.name, this.resolvers});

  factory InputAnnotation.read(ConstantReader reader) {
    return InputAnnotation(
      name: reader.peek('name')?.stringValue,
      resolvers: _getResolvers(reader),
    );
  }

  static InputAnnotation? peek(ClassElement element) =>
      _getAnnotation<GrapherInput, InputAnnotation>(
        element,
        InputAnnotation.read,
      );
}

class ResolverAnnotation {
  final String name;
  final String? queryBody;
  final String dartCallName;
  final DartType dartType;
  final TypeAliasElement? aliasElement;

  const ResolverAnnotation._({
    required this.name,
    required this.queryBody,
    required this.dartCallName,
    required this.dartType,
    required this.aliasElement,
  });

  factory ResolverAnnotation._read(
    ConstantReader reader,
    InterfaceElement element,
  ) {
    final object = reader.objectValue;
    final type = object.type as InterfaceType;

    DartType? typeArgument = element.mixins
        .firstWhereOrNull((m) => m.element.name == 'GrapherResolverMixin')
        ?.typeArguments
        .first;

    if (typeArgument == null) {
      throw GrapherException(
        'The class ${type.element.name} used as a resolver '
        'must extend GrapherResolverMixin<T>.',
      );
    }

    return ResolverAnnotation._(
      name: reader.read('name').stringValue,
      queryBody: reader.peek('queryBody')?.stringValue,
      dartCallName:
          object.variable?.displayName ?? 'const ${type.element.name}()',
      dartType: typeArgument,
      aliasElement: typeArgument.alias?.element,
    );
  }

  static ResolverAnnotation? peek(InterfaceElement element) {
    final annotation = _getAnnotation<GrapherResolver, ResolverAnnotation>(
      element,
      (reader) => ResolverAnnotation._read(reader, element),
    );

    return annotation;
  }

  @override
  int get hashCode => Object.hash(name, dartType, dartCallName);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ResolverAnnotation && other.hashCode == hashCode;
  }
}

List<ResolverAnnotation>? _getResolvers(ConstantReader reader) {
  return reader.peek('resolvers')?.listValue.map<ResolverAnnotation>((
    resolver,
  ) {
    final type = resolver.type as InterfaceType;
    final annotation = ResolverAnnotation.peek(type.element);

    if (annotation == null) {
      throw GrapherException(
        'The class ${type.element.name} used in the resolvers list '
        'must be annotated with @GrapherResolver()',
      );
    }

    final mixin = type.element.mixins.firstWhereOrNull(
      (m) => m.element.name == 'GrapherResolverMixin',
    );

    DartType? typeArgument = mixin?.typeArguments.first;

    if (typeArgument == null) {
      throw GrapherException(
        'The class ${type.element.name} used in the resolvers list '
        'must extend GrapherResolverMixin<T>.',
      );
    }

    return ResolverAnnotation._(
      name: annotation.name,
      dartCallName:
          resolver.variable?.displayName ?? 'const ${type.element.name}()',
      dartType: typeArgument,
      queryBody: annotation.queryBody,
      aliasElement: typeArgument.alias?.element,
    );
  }).toList();
}

// Callable

class QueryAnnotation {
  final String name;
  final List<ResolverAnnotation>? resolvers;

  const QueryAnnotation({required this.name, this.resolvers});

  factory QueryAnnotation.read(ConstantReader reader) {
    return QueryAnnotation(
      name: reader.read('name').stringValue,
      resolvers: _getResolvers(reader),
    );
  }

  static QueryAnnotation? peek(Element element) =>
      _getAnnotation<GrapherQuery, QueryAnnotation>(element, (reader) {
        return QueryAnnotation.read(reader);
      });
}

class MutationAnnotation {
  final String name;
  final List<ResolverAnnotation>? resolvers;

  const MutationAnnotation({required this.name, this.resolvers});

  factory MutationAnnotation.read(ConstantReader reader) {
    return MutationAnnotation(
      name: reader.read('name').stringValue,
      resolvers: _getResolvers(reader),
    );
  }

  static MutationAnnotation? peek(Element element) =>
      _getAnnotation<GrapherMutation, MutationAnnotation>(element, (reader) {
        return MutationAnnotation.read(reader);
      });
}

class SubscriptionAnnotation {
  final String name;
  final List<ResolverAnnotation>? resolvers;

  const SubscriptionAnnotation({required this.name, this.resolvers});

  factory SubscriptionAnnotation.read(ConstantReader reader) {
    return SubscriptionAnnotation(
      name: reader.read('name').stringValue,
      resolvers: _getResolvers(reader),
    );
  }

  static SubscriptionAnnotation? peek(Element element) =>
      _getAnnotation<GrapherSubscription, SubscriptionAnnotation>(
        element,
        (reader) => SubscriptionAnnotation.read(reader),
      );
}

// Utility functions

D? _getAnnotation<A, D>(
  Object element,
  D Function(ConstantReader reader) builder,
) {
  final annotations = TypeChecker.typeNamed(A).annotationsOf(element);

  if (annotations.isEmpty) {
    return null;
  }
  if (annotations.length > 1) {
    throw GrapherException(
      "You tried to add multiple @$A() annotations to the "
      "same element ($element), but that's not possible.",
    );
  }

  return builder(ConstantReader(annotations.single));
}
