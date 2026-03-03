import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/source/class.dart';
import 'package:grapher_builder/src/source/definition.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/const.dart';
import 'package:grapher_builder/src/utils/exception.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/utils/schema.dart';
import 'package:grapher_builder/src/utils/config.dart';

sealed class BaseType extends Entity {
  final String? library;
  final String dartName;
  final String? graphName;

  String get dartNameFull => dartName;

  @override
  String get identifier => dartName;

  const BaseType({
    super.resolvers,
    required this.library,
    required this.dartName,
    this.graphName,
  });

  String? generateQueryFields() => null;

  String generateToMapValue(String field) => field;

  factory BaseType.parse(Entity? parent, DartType value) {
    final alias = value.alias?.element;
    if (alias != null) {
      if (alias.isIDType) {
        return SimpleType(dartName: 'ID', graphName: 'ID');
      }
    }
    if (value.isDartCoreString) {
      return SimpleType(dartName: 'String', graphName: 'String');
    } else if (value.isDartCoreInt) {
      return SimpleType(dartName: 'int', graphName: 'Int');
    } else if (value.isDartCoreDouble) {
      return SimpleType(
        dartName: 'double',
        graphName: 'Float',
        generateFromMapField: (field) => 'double.parse($field.toString())',
      );
    } else if (value.isDartCoreBool) {
      return SimpleType(dartName: 'bool', graphName: 'Boolean');
    } else if (value is TypeParameterType) {
      return GenericType(
        library: value.element.libraryPath,
        dartName: value.getDisplayString(),
      );
    } else if (value is InterfaceType) {
      if (value.isDartCoreList) {
        return ListType(
          resolvers: parent?.resolvers,
          item: Definition.parse(parent, value.typeArguments.first),
        );
      } else {
        final cachedElement = Config().get(value.element);
        if (cachedElement != null) {
          return cachedElement;
        }
        final element = value.element;

        if (element is ClassElement) {
          final annotation = ObjectAnnotation.peek(element);
          if (annotation != null) {
            return ClassEntityType.parse(annotation, element);
          }
          final inputAnnotation = InputAnnotation.peek(element);
          if (inputAnnotation != null) {
            return ClassInputEntityType.parse(inputAnnotation, element);
          }
        }
        if (element is EnumElement) {
          return EnumType.parse(element);
        }
        return _custom(parent!, value);
      }
    }
    throw GrapherError(
      'Unsupported type:  ${value.getDisplayString()}',
      path: parent?.location,
    );
  }

  @override
  String toString() => graphName ?? dartName;

  @override
  int get hashCode => super.location.hashCode;

  @override
  bool operator ==(Object other) {
    if (other is BaseType) {
      return super.hashCode == other.hashCode;
    }
    return false;
  }
}

class SimpleType extends BaseType {
  final String Function(String field)? generateFromMapField;

  SimpleType({
    super.library,
    required super.dartName,
    required super.graphName,
    this.generateFromMapField,
  });
}

class GenericType extends BaseType {
  GenericType({required super.library, required super.dartName})
    : super(graphName: null);
}

class ListType extends BaseType with GenericTypeMixin {
  final Definition item;

  const ListType({required super.resolvers, required this.item})
    : super(library: null, dartName: 'List', graphName: null);

  @override
  String generateToMapValue(String field) {
    return '$field.map((e) => ${item.generateToMapField('e')}).toList()';
  }
}

BaseType _custom(Entity? parent, InterfaceType element) {
  final resolver = parent?.resolvers?.firstWhereOrNull((r) {
    if (r.aliasElement != null) {
      return r.aliasElement == element.alias?.element;
    }
    return r.dartType == element.element.thisType;
  });
  if (resolver != null) {
    return ClassWithResolverType(
      resolvers: parent?.resolvers,
      library: element.element.libraryPath,
      dartName: element.element.displayName,
      graphName: resolver.name,
      resolver: resolver,
    );
  }
  final param = parent?.find<ConstructorField>();

  if (param != null) {
    if (param.union == null) {
      throw Exception(
        'Custom type needs "union" or suitable "resolvers" param in: \'${param.location}\'',
      );
    }
    return ObjectType(
      library: element.element.libraryPath,
      dartName: element.element.displayName,
      parent: parent,
    );
  }
  throw Exception(
    'Not found resolver in field: \'${parent?.location ?? element.element.displayName}\'',
  );
}

class ObjectType extends BaseType {
  @override
  final Entity? parent;

  const ObjectType({
    required super.library,
    required super.dartName,
    required this.parent,
  }) : super(graphName: null);

  @override
  String generateToMapValue(String field) => throw UnimplementedError();
}

class ClassWithResolverType extends BaseType {
  final ResolverAnnotation resolver;

  const ClassWithResolverType({
    required super.resolvers,
    required super.library,
    required super.dartName,
    required super.graphName,
    required this.resolver,
  });

  @override
  String generateToMapValue(String field) {
    return '${resolver.dartCallName}.toMap($field)';
  }
}

class ClassEntityType extends BaseType with GenericTypeMixin {
  late final Constructor constructor;
  final List<Generic> generic;

  @override
  String get dartNameFull {
    if (generic.isEmpty) return dartName;
    return '$dartName<${generic.map((e) => e.name).join(', ')}>';
  }

  ClassEntityType({
    required super.resolvers,
    required super.library,
    required super.dartName,
    required super.graphName,
    required this.generic,
  });

  factory ClassEntityType.parse(
    BaseAnnotation annotation,
    ClassElement element,
  ) {
    String? graphName = annotation.name;

    if (graphName == null) {
      for (final supertype in element.allSupertypes) {
        final superElement = supertype.element;
        final superAnnotation = ObjectAnnotation.peek(superElement);
        if (superAnnotation != null && superAnnotation.name != null) {
          if (superAnnotation.name != null) {
            graphName = superAnnotation.name;
            break;
          }
        }
      }
    }

    final entity = ClassEntityType(
      resolvers: annotation.resolvers,
      library: element.libraryPath,
      dartName: element.displayName,
      graphName: graphName,
      generic: element.typeParameters.map(Generic.parse).toList(),
    );

    entity.constructor = Constructor.parseDefaultConstructor(entity, element);

    Config().add(entity);

    return entity;
  }

  ValidationError? validate({
    SchemaType? validateObject,
    GenericMapped? genericMapped,
  }) {
    SchemaType? object = validateObject;

    final graphName = this.graphName;
    if (object == null) {
      if (graphName != null) {
        final schema = Config().schema;
        if (schema == null) return null;
        object = schema.get(graphName);
        if (object == null) {
          return ValidationError.notFound(graphName, rawLocation);
        }
      } else {
        return null;
      }
    }

    if (object is! SchemaObject) {
      return ValidationError.typeMismatch(object.name, rawLocation);
    }

    for (final param in constructor.params) {
      final name = param.graphName ?? param.dartName;
      final schemaParam = object.fields.firstWhereOrNull((e) => e.name == name);
      if (schemaParam == null) {
        return ValidationError.notFound(name, param.rawLocation);
      }
      if (schemaParam.deprecated) {
        return ValidationError('Field is deprecated', param.rawLocation);
      }
      final result = param.def.validate(
        schemaParam.definition,
        genericMapped: genericMapped,
      );
      if (result != null) {
        return result;
      }
    }
    return null;
  }

  @override
  String generateToMapValue(String field) {
    final name = [dartName, toMapPostfix].uncapitalized;
    return '$name($field)';
  }

  String generateToMap() {
    final result = StringBuffer();
    result.write(
      "Map<String, dynamic> ${[dartName, toMapPostfix].uncapitalized}(",
    );
    result.writeln('$dartName object,');
    result.writeln(') {');
    result.writeln('final result = <String, dynamic>{};');

    for (final param in constructor.params) {
      result.writeln('${param.generateToMapValue()};');
    }

    result.writeln('result.removeWhere((_, value) => value == null);');
    result.writeln('return result;');
    result.write('}');
    return result.toString();
  }

  String generateFromMap() {
    final result = StringBuffer();
    // Function signature
    result.write('$dartNameFull ');
    result.write([dartName, fromMapPostfix].uncapitalized);
    if (generic.isNotEmpty) {
      result.write('<');
      result.write(generic.map((e) => e.name).join(', '));
      result.write('>');
    }
    result.writeln('(');
    final params = [
      'dynamic json',
      ...generic.map(
        (e) => '${e.name} Function(dynamic json) $genericPrefix${e.name}',
      ),
    ];
    result.writeln(params.join(', '));

    result.writeln(') {');

    // Union parsers
    constructor.params.where((e) => e.union != null).forEach((param) {
      final name = [fromUnionPrefix, param.dartName].uncapitalized;
      result.writeln('${param.def.dartNameFullNullable} $name(dynamic json) {');
      result.writeln("\tfinal type = json['__typename'];");
      for (final item in param.union!.entries) {
        final t = Definition.parse(this, item.value);
        result.writeln("\tif (type == '${item.key}') {");
        result.writeln('\t\treturn ${t.generateFromMapField('json')};');
        result.writeln('\t}');
      }
      result.writeln('\treturn null;');
      result.writeln('}');
    });

    result.writeln('return $dartNameFull${constructor.name}(');
    result.write(
      constructor.params
          .map((e) {
            return e.generateFromMapValue('json');
          })
          .join(','),
    );
    result.writeln(');');
    result.writeln('}');
    return result.toString();
  }
}

class ClassInputEntityType extends ClassEntityType {
  ClassInputEntityType({
    required super.resolvers,
    required super.library,
    required super.dartName,
    required super.graphName,
    required super.generic,
  });

  factory ClassInputEntityType.parse(
    BaseAnnotation annotation,
    ClassElement element,
  ) {
    final entity = ClassInputEntityType(
      resolvers: annotation.resolvers,
      library: element.libraryPath,
      dartName: element.displayName,
      graphName: annotation.name,
      generic: element.typeParameters.map(Generic.parse).toList(),
    );

    entity.constructor = Constructor.parseDefaultConstructor(entity, element);

    Config().add(entity);

    return entity;
  }

  @override
  ValidationError? validate({
    SchemaType? validateObject,
    GenericMapped? genericMapped,
  }) {
    SchemaType? object = validateObject;
    final graphName = this.graphName ?? dartName;
    if (object == null) {
      final schema = Config().schema;
      if (schema == null) return null;
      object = schema.get(graphName);
      if (object == null) {
        return ValidationError.notFound(graphName, rawLocation);
      }
    } else {
      return null;
    }

    if (object is! SchemaInput) {
      return ValidationError.typeMismatch(object.name, rawLocation);
    }

    // Check required
    final paramNames = constructor.params
        .map((e) => e.graphName ?? e.dartName)
        .toSet();
    for (final field in object.fields.where((e) => e.isRequired)) {
      if (!paramNames.contains(field.name)) {
        return ValidationError.parameterMissing(
          field.name,
          object.name,
          rawLocation,
        );
      }
    }

    // Check types
    for (final param in constructor.params) {
      final schemaParam = object.fields.byName(
        param.graphName ?? param.dartName,
      );

      final result = param.validate(schemaParam, genericMapped);
      if (result != null) {
        return result;
      }
    }
    return null;
  }
}

class EnumType extends BaseType {
  final bool isStrict;
  final bool isFinal;

  final List<EnumValue> values = [];

  EnumType({
    required super.library,
    required super.dartName,
    required super.graphName,
    required this.isStrict,
    required this.isFinal,
  });

  factory EnumType.parse(EnumElement element) {
    final annotation = EnumAnnotation.peek(element);
    final object = EnumType(
      library: element.libraryPath,
      dartName: element.displayName,
      graphName: annotation?.name,
      isStrict: annotation?.isStrict ?? true,
      isFinal: annotation?.isFinal ?? false,
    );

    if (annotation == null) {
      throw GrapherError(
        'Enum ${element.displayName} must be annotated with @GrapherEnum',
        path: object.location,
      );
    }
    object.values.addAll(
      element.fields
          .where((e) => e.isEnumConstant)
          .map((e) => EnumValue.parse(object, e)),
    );

    Config().add(object);
    return object;
  }

  ValidationError? validate() {
    final schema = Config().schema;
    if (schema == null) return null;
    final name = graphName ?? dartName;
    final object = schema.get(name);
    if (object == null) {
      return ValidationError.notFound(name, rawLocation);
    }

    if (object is SchemaEnum) {
      final schemaItems = object.values;
      final names = values.map((e) => e.graphName ?? e.dartName).toSet();
      final schemaNames = schemaItems.map((e) => e.name).toSet();

      for (final name in names.where((e) => !schemaNames.contains(e))) {
        return ValidationError(
          'Enum value "$name" IS NOT FOUND',
          rawLocation,
          isCritical: true,
        );
      }

      if (isStrict) {
        for (final name
            in schemaItems
                .where((e) => !e.deprecated)
                .map((e) => e.name)
                .where((e) => !names.contains(e))) {
          return ValidationError('Enum value "$name" missing', rawLocation);
        }
      }
    } else {
      return ValidationError.typeMismatch(object.name, rawLocation);
    }
    return null;
  }

  @override
  String generateToMapValue(String field) {
    return '${[dartName, toMapPostfix].uncapitalized}($field)';
  }

  String generateFromMap() {
    final result = StringBuffer();
    result.write('$dartName? ');
    result.write([dartName, fromMapPostfix].uncapitalized);
    result.writeln('(String value) {');
    result.writeln('switch(value) {');
    for (final v in values) {
      result.writeln(
        "case '${v.graphName ?? v.dartName}': return $dartName.${v.dartName};",
      );
    }
    result.writeln('}');
    result.writeln('return null;');
    result.writeln('}');
    return result.toString();
  }

  String generateToMap() {
    final result = StringBuffer();
    result.write('String ');
    result.write([dartName, toMapPostfix].uncapitalized);
    result.writeln('($dartName value) {');
    result.writeln('switch(value) {');
    for (final v in values) {
      result.writeln(
        'case $dartName.${v.dartName}: return \'${v.graphName ?? v.dartName}\';',
      );
    }
    result.writeln('}');
    result.writeln('}');
    return result.toString();
  }
}

class EnumValue extends Entity {
  @override
  final EnumType parent;

  final String dartName;
  final String? graphName;

  @override
  String get identifier => dartName;

  const EnumValue({
    required this.parent,
    required this.dartName,
    this.graphName,
  }) : super(resolvers: null);

  factory EnumValue.parse(EnumType parent, FieldElement element) {
    final annotation = EnumValueAnnotation.peek(element);
    return EnumValue(
      parent: parent,
      dartName: element.displayName,
      graphName: annotation?.name,
    );
  }
}
