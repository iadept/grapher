import 'package:analyzer/dart/constant/value.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/source/definition.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/const.dart';
import 'package:grapher_builder/src/utils/exception.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/utils/schema.dart';

class Constructor extends Entity {
  final String? dartName;
  final List<ConstructorParam> params = [];

  @override
  final ClassEntityType? parent;

  String get name => dartName == null ? '' : '.$dartName';

  @override
  String get identifier => dartName ?? 'new';

  Constructor._({
    required super.resolvers,
    required this.parent,
    required this.dartName,
  });

  static Constructor parseDefaultConstructor(
    ClassEntityType entity,
    ClassElement element,
  ) {
    final constructors = element.constructors
        .where((e) => e.isFactory == false)
        .toList();
    final constructor =
        constructors.firstWhereOrNull((e) => e.name == 'new') ??
        constructors.firstWhereOrNull((e) => e.name == '_');
    if (constructor == null) {
      throw Exception('${element.displayName} may be have unnamed constructor');
    }
    return Constructor.parse(entity, constructor);
  }

  factory Constructor.parse(
    ClassEntityType parent,
    ConstructorElement element,
  ) {
    final result = Constructor._(
      resolvers: parent.resolvers,
      parent: parent,
      dartName: element.name == 'new' ? null : element.name,
    );

    result.params.addAll(
      element.formalParameters.map((e) => ConstructorParam.parse(result, e)),
    );

    return result;
  }
}

abstract class _Parameter extends Entity {
  final String dartName;
  final String? graphName;
  late final Definition def;
  final bool isNamed;

  String get queryParameter =>
      '\\\$${graphName ?? dartName}: ${def.graphNameFull}';

  String get queryParameterValue => '${graphName ?? dartName}: \\\$$dartName';

  _Parameter({
    required super.resolvers,
    required this.dartName,
    required this.graphName,
    required this.isNamed,
  });
}

class ConstructorParam extends _Parameter {
  @override
  final Constructor parent;
  final Map<String, DartType>? union;
  final String inputName;
  final String? input;
  final DartObject? defaultValue;

  final bool skipInQuery;

  @override
  String get identifier => dartName;

  ConstructorParam._({
    required this.parent,
    required super.resolvers,
    required super.dartName,
    required super.graphName,
    required super.isNamed,
    required this.union,
    required this.inputName,
    required this.input,
    required this.defaultValue,
    required this.skipInQuery,
  }) : super();

  static FieldAnnotation? _getAnnotation(Element element) {
    if (element is FieldFormalParameterElement && element.field != null) {
      return FieldAnnotation.peek(element.field!);
    } else if (element is SuperFormalParameterElement &&
        element.superConstructorParameter != null) {
      return _getAnnotation(element.superConstructorParameter!);
    }
    return null;
  }

  static ConstructorParam parse(
    Constructor parent,
    FormalParameterElement element,
  ) {
    final annotation = _getAnnotation(element);

    final object = ConstructorParam._(
      parent: parent,
      resolvers: parent.resolvers,
      dartName: element.displayName,
      graphName: annotation?.name,
      isNamed: element.isNamed,
      union: annotation?.union,
      inputName: annotation?.inputName ?? 'input',
      input: annotation?.input,
      defaultValue: annotation?.defaultValue,
      skipInQuery: annotation?.skipInQuery ?? false,
    );

    object.def = Definition.parse(object, element.type);

    if (!object.def.isNullable && annotation?.defaultValue != null) {
      throw GrapherException(
        'Non-nullable field ${element.displayName} cannot have defaultValue ',
        path: object.location,
      );
    }

    if (annotation?.defaultValue != null &&
        annotation?.defaultValue?.type?.element != element.type.element) {
      throw GrapherException(
        'defaultValue type mismatch for ${element.displayName}',
        path: object.location,
      );
    }

    return object;
  }

  String generateFromMapValue(String field) {
    final name = "$field['${graphName ?? dartName}']";
    String value;

    if (union != null) {
      value = '${[fromUnionPrefix, dartName].uncapitalized}($name)';
      if (def.isNullable) {
        value = '$name == null ? null : $value';
      } else {
        value = '$value!';
      }
    } else {
      value = def.generateFromMapField(
        name,
        defaultValue: _dartObjectToString(defaultValue),
      );
    }
    if (isNamed) {
      value = '$dartName: $value';
    }
    return value;
  }

  String generateToMapValue() {
    final field = "result['${graphName ?? dartName}'] =";
    return '$field ${def.generateToMapField('object.$dartName')}';
  }
}

class MethodParameter extends _Parameter {
  @override
  final Entity? parent;

  @override
  String get identifier => dartName;

  MethodParameter({
    required this.parent,
    required super.dartName,
    required super.graphName,
    required super.isNamed,
  }) : super(resolvers: parent?.resolvers);

  factory MethodParameter.parse(
    Entity? parent,
    FormalParameterElement element,
  ) {
    String? overrideName;
    final object = MethodParameter(
      parent: parent,
      dartName: element.displayName,
      graphName: overrideName,
      isNamed: element.isNamed,
    );

    object.def = Definition.parse(object, element.type);

    return object;
  }

  factory MethodParameter.input(BaseType parent, Entity? object) {
    final param = MethodParameter(
      parent: object,
      dartName: 'input',
      graphName: null,
      isNamed: false,
    );

    param.def = Definition(parent: param, type: parent, isNullable: false);

    return param;
  }

  void validate(SchemaParameter parameter) {
    final name = graphName ?? dartName;
    if (name != parameter.name) {
      throw ValidationError('Expected ${parameter.name}', path: location);
    }
  }
}

class Generic {
  final String name;

  const Generic({required this.name});

  factory Generic.parse(TypeParameterElement element) {
    return Generic(name: element.displayName);
  }
}

String? _dartObjectToString(DartObject? object) {
  if (object == null) {
    return null;
  }
  if (object.type?.isDartCoreString == true) {
    return "'${object.toStringValue()}'";
  } else if (object.type?.isDartCoreBool == true) {
    return object.toBoolValue().toString();
  } else if (object.type?.isDartCoreInt == true) {
    return object.toIntValue().toString();
  } else if (object.type?.isDartCoreDouble == true) {
    return object.toDoubleValue().toString();
  } else {
    final variable = object.variable;
    if (variable?.isEnumValue == true) {
      return '${variable!.type.element!.name}.${variable.name}';
    }
    throw GrapherException('Unsupported defaultValue type: ${object.type}');
  }
}
