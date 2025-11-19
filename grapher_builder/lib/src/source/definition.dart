import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_annotation/grapher_annotation.dart';
import 'package:grapher_builder/src/source/class.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/buffer.dart';
import 'package:grapher_builder/src/utils/const.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/utils/schema.dart';

typedef GenericMapped = Map<String, Definition>;

class Definition extends Entity {
  @override
  final Entity? parent;
  final BaseType type;
  final bool isNullable;
  final List<Definition>? generics;

  @override
  String? get identifier => null;

  String? get _genericsString => generics?.isNotEmpty == true
      ? '<${generics!.map((e) => e.dartNameFull).join(', ')}>'
      : null;

  String get dartNameFull =>
      [type.dartName, _genericsString, if (isNullable) '?'].nonNulls.join('');

  String get dartNameFullNullable =>
      [type.dartName, _genericsString, '?'].nonNulls.join('');

  String get graphNameFull {
    switch (type) {
      case SimpleType():
      case ClassEntityType():
      case ClassWithResolverType():
        return [type.graphName ?? type.dartName, if (!isNullable) '!'].join('');
      case ListType e:
        return ['[', e.item.graphNameFull, ']', if (!isNullable) '!'].join('');
      case EnumType():
      case ObjectType():
      case GenericType():
        throw UnimplementedError();
    }
  }

  GenericMapped? _merge(GenericMapped? source) {
    final type = this.type;
    if (type is ClassEntityType) {
      if (generics?.isNotEmpty == true) {
        return Map.fromEntries(
          generics!.mapIndexed((i, e) {
            final genericType = e.type;
            if (genericType is GenericType) {
              return MapEntry(
                type.generic[i].name,
                source![genericType.dartName]!,
              );
            }
            return MapEntry(type.generic[i].name, e);
          }),
        );
      }
    }
    return source;
  }

  String? graphBody([GenericMapped? parentMapped]) {
    final mapped = _merge(parentMapped);
    switch (type) {
      case SimpleType():
      case EnumType():
        return null;
      case ClassWithResolverType e:
        return e.resolver.queryBody;
      case ClassEntityType e:
        final buffer = Buffer();
        buffer.writeln('__typename');
        buffer.writeln(
          e.constructor.params.where((e) => !e.skipInQuery).map((e) {
            final buffer = Buffer();

            buffer.write(e.graphName ?? e.dartName);
            if (e.input != null) {
              buffer.write('(${e.inputName}: \\\$${e.input!})');
            }
            if (e.union != null) {
              buffer.writeln(' {');
              buffer.block((buffer) {
                buffer.writeln('__typename');
                e.union!.forEach((key, value) {
                  buffer.writeln('... on $key {');
                  buffer.block((b) {
                    final def = Definition.parse(this, value);
                    final body = def.graphBody(mapped);
                    if (body != null) {
                      b.writeln(body.split('\n'));
                    }
                  });
                  buffer.writeln('}');
                });
              });
              buffer.writeln('}');
            } else {
              final body = e.def.graphBody(mapped);
              if (body != null) {
                buffer.writeln(' {');
                buffer.block((buffer) => buffer.writeln(body.split('\n')));
                buffer.writeln('}');
              }
            }
            return buffer.toString();
          }),
        );
        return buffer.toString();

      case ListType e:
        return e.item.graphBody(mapped);
      case GenericType e:
        return mapped?[e.dartName]?.graphBody(mapped);
      case ObjectType():
        throw UnimplementedError();
    }
  }

  Definition({
    required this.parent,
    required this.type,
    required this.isNullable,
    this.generics,
  }) : super(resolvers: parent?.resolvers);

  factory Definition.parse(Entity? parent, DartType value) {
    final type = BaseType.parse(parent, value);
    List<Definition>? generics;
    if (type is GenericTypeMixin) {
      generics = value is InterfaceType
          ? value.typeArguments.map((e) => Definition.parse(parent, e)).toList()
          : null;
    }

    return Definition(
      parent: parent,
      type: type,
      isNullable: value.nullabilitySuffix == NullabilitySuffix.question,
      generics: generics,
    );
  }

  String generateToMapValue(String field) {
    if (isNullable) {
      return '$field == null ? null : ${type.generateToMapValue(field)}';
    }
    return type.generateToMapValue(field);
  }

  String generateFromMapField(String field, {String? defaultValue}) {
    String expr = _generateFromMapField(field);
    if (isNullable) {
      expr = '$field == null ? null : $expr';
      if (defaultValue != null) {
        return '($expr) ?? $defaultValue';
      }
    }
    return expr;
  }

  String _generateFromMapField(String field) {
    switch (type) {
      case SimpleType e:
        return e.generateFromMapField?.call(field) ?? '$field as ${e.dartName}';
      case ClassWithResolverType e:
        return '${e.resolver.dartCallName}.fromMap($field)';
      case ClassEntityType():
        final result = StringBuffer();
        result.write([type.dartName, fromMapPostfix].uncapitalized);
        result.write(_genericsString ?? '');
        result.write('($field');
        if (generics?.isNotEmpty == true) {
          result.write(',');
          result.write(
            generics!
                .map((e) => "(e)=> ${e.generateFromMapField('e')}")
                .join(', '),
          );
        }
        result.write(')');
        return result.toString();
      case ListType e:
        return '($field as List).map((item) => ${e.item.generateFromMapField('item')}).toList()';
      case GenericType e:
        return '$genericPrefix${e.dartName}($field)';
      case EnumType e:
        final expr =
            '${[e.dartName, fromMapPostfix].uncapitalized}($field as String)';
        if (isNullable) {
          return expr;
        } else {
          return '$expr!';
        }
      case ObjectType():
        throw UnimplementedError();
    }
  }

  String generateToMapField(String field) {
    switch (type) {
      case SimpleType():
        return field;
      case ListType e:
        if (isNullable) {
          return "$field?.map((e) => ${e.item.generateToMapField('e')}).toList()";
        }
        return "$field.map((e) => ${e.item.generateToMapField('e')}).toList()";
      case ClassWithResolverType e:
        if (isNullable) {
          return "$field == null ? null : ${e.resolver.dartCallName}.toMap($field!)";
        }
        return '${e.resolver.dartCallName}.toMap($field)';
      case ClassEntityType():
        if (isNullable) {
          return "$field == null ? null : ${[type.dartName, toMapPostfix].uncapitalized}($field!)";
        }
        return "${[type.dartName, toMapPostfix].uncapitalized}($field)";
      case EnumType e:
        if (isNullable) {
          return "$field == null ? null : ${[e.dartName, toMapPostfix].uncapitalized}($field!)";
        }
        return '${[e.dartName, toMapPostfix].uncapitalized}($field)';

      case GenericType e:
        throw Exception('Cannot convert Object to JSON ${e.location}');
      case ObjectType e:
        throw Exception('Cannot convert Object to JSON ${e.location}');
    }
  }

  bool _validateNullability(
    SchemaDef schemaDef, {
    bool skipNullability = false,
    bool isInput = false,
  }) {
    final field = parent?.as<ConstructorField>();

    if (skipNullability) return true;

    if ((isNullable != schemaDef.isNullable)) {
      // Input can be over nullable
      if (isInput && schemaDef.isNullable) return true;

      // Field can ignore nullability
      // if (!isNullable && field?.ignoreNullability == true) return true;
      if (field?.ignoreNullability == true) return true;

      if (!isNullable && field?.defaultValue != null) return true;

      if (type is EnumType) {
        // TODO
        return true;
      }

      final object = schemaDef.as<SchemaNameDef>()?.object?.as<SchemaEnum>();
      if (object != null) {
        if (type.dartName == 'String') return true;
        final t = type;
        if (t is EnumType && isNullable && schemaDef.isNonNull) {
          return true;
        }
      }
      return false;
    }
    return true;
  }

  ValidationError? validate(
    SchemaDef schemaDef, {
    bool skipNullability = false,
    bool allowOverNullability = false,
    GenericMapped? genericMapped,
  }) {
    final location = parent?.rawLocation ?? rawLocation;

    if (!_validateNullability(
      schemaDef,
      skipNullability: skipNullability,
      isInput: allowOverNullability,
    )) {
      return ValidationError.nullabilityMismatch(
        isNullable,
        schemaDef.isNullable,
        location,
      );
    }

    switch (schemaDef) {
      case SchemaNameDef e:
        final schemaName = e.name;
        if (type.graphName == null) {
          switch (type) {
            case EnumType():
              break;
            case SimpleType():
              break;
            case GenericType e:
              final mappedType = genericMapped?[e.dartName];
              if (mappedType == null) {
                return ValidationError.notFound(schemaName, location);
              }
              return mappedType.validate(
                schemaDef,
                allowOverNullability: allowOverNullability,
                genericMapped: genericMapped,
              );
            case ListType():
              return ValidationError.typeMismatch(
                schemaDef.toString(),
                location,
              );
            case ObjectType():
              final parent = this.parent;
              if (parent is ConstructorField) {
                if (parent.union != null) {
                  return null;
                } else {}
              } else {
                return ValidationError('', location, isCritical: true);
              }

              break;
            case ClassWithResolverType():
              throw Exception('Resolver ${type.location}');
            case ClassEntityType e:
              return e
                  .validate(
                    validateObject: schemaDef.object,
                    genericMapped: _merge(genericMapped),
                  )
                  ?.from(location);
          }
        } else {
          final field = parent?.as<ConstructorField>();
          final graphName = field?.overrideType ?? type.graphName;
          if (schemaName != graphName) {
            if (schemaDef.as<SchemaNameDef>()?.object is SchemaEnum) {
              // TODO
              return null;
            }
            if (graphName == GrapherField.overrideTypeEnum) {
              if (type is SimpleType && type.dartName == 'String') {
                return ValidationError.typeMismatch(schemaName, location);
              }
            } else if (graphName != GrapherField.overrideTypeAny) {
              return ValidationError.typeMismatch(schemaName, location);
            }
          }
        }

        break;
      case SchemaListDef e:
        final type = this.type;
        if (type is ListType) {
          return type.item.validate(
            e.itemType,
            allowOverNullability: allowOverNullability,
            genericMapped: genericMapped,
          );
        } else {
          return ValidationError.typeMismatch('List', location);
        }
    }

    return null;
  }
}
