import 'package:analyzer/dart/element/nullability_suffix.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/buffer.dart';
import 'package:grapher_builder/src/utils/const.dart';
import 'package:grapher_builder/src/utils/extension.dart';

typedef GenericMapped = Map<String, Definition>;

class Definition extends Part {
  @override
  final Part? parent;
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
      case ClassCustomType():
      case ClassWithResolverType():
        return [type.graphName ?? type.dartName, if (!isNullable) '!'].join('');
      case ListType e:
        return ['[', e.item.graphNameFull, ']', if (!isNullable) '!'].join('');
      case EnumType():
      case ClassObjectType():
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
      case ClassCustomType e:
        return e.queryBody;
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
      case ClassObjectType():
        throw UnimplementedError();
    }
  }

  Definition({
    required this.parent,
    required this.type,
    required this.isNullable,
    this.generics,
  }) : super(resolvers: parent?.resolvers);

  factory Definition.parse(Part? parent, DartType value) {
    final type = BaseType.parse(parent, value);
    List<Definition>? generics;
    if (type.hasGenerics) {
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

  String generateFromMapField(String field) {
    if (isNullable) {
      return '$field == null ? null : ${_generateFromMapField(field)}';
    }
    return _generateFromMapField(field);
  }

  String _generateFromMapField(String field) {
    switch (type) {
      case SimpleType e:
        return e.generateFromMapField?.call(field) ?? '$field as ${e.dartName}';
      case ClassCustomType e:
        return '${e.fromMap}($field)';
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
        if (isNullable) {
          return '${[e.dartName, fromMapPostfix].uncapitalized}($field as String)';
        } else {
          return '${[e.dartName, fromMapPostfix].uncapitalized}($field as String)!';
        }
      case ClassObjectType():
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

      case ClassCustomType e:
        return '${e.toMap}($field)';
      case ClassWithResolverType e:
        if (isNullable) {
          return "$field == null ? null : ${e.resolver.dartCallName}.toMap($field!)";
        }
        return '${e.resolver.dartCallName}.toMap($field)';
      case ClassEntityType():
        if (isNullable) {
          return "$field == null ? null : ${[type.dartName, toVariablesPostfix].uncapitalized}($field!)";
        }
        return "${[type.dartName, toVariablesPostfix].uncapitalized}($field)";
      case EnumType e:
        if (isNullable) {
          return "$field == null ? null : ${[e.dartName, toMapPostfix].uncapitalized}($field!)";
        }
        return '${[e.dartName, toMapPostfix].uncapitalized}($field)';

      case GenericType e:
        throw Exception('Cannot convert Object to JSON ${e.location}');
      case ClassObjectType e:
        throw Exception('Cannot convert Object to JSON ${e.location}');
    }
  }
}
