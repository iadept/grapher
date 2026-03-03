import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gql/ast.dart';
import "package:gql/language.dart" as gql;
import 'package:grapher_builder/src/utils/exception.dart';

sealed class SchemaDef {
  final Schema _root;
  final bool isNonNull;

  bool get isNullable => !isNonNull;

  const SchemaDef._({required Schema root, required this.isNonNull})
    : _root = root;

  factory SchemaDef._parse(Schema root, TypeNode node) {
    if (node is NamedTypeNode) {
      return SchemaNameDef._(
        root: root,
        name: node.name.value,
        isNonNull: node.isNonNull,
      );
    } else if (node is ListTypeNode) {
      final itemType = SchemaDef._parse(root, node.type);
      return SchemaListDef._(
        root: root,
        itemType: itemType,
        isNonNull: node.isNonNull,
      );
    } else {
      throw UnimplementedError();
    }
  }
}

class SchemaNameDef extends SchemaDef {
  final String name;

  SchemaType? get object => _root.get(name);

  const SchemaNameDef._({
    required super.root,
    required this.name,
    required super.isNonNull,
  }) : super._();

  @override
  String toString() => name + (isNonNull ? '!' : '');
}

class SchemaListDef extends SchemaDef {
  final SchemaDef itemType;

  const SchemaListDef._({
    required super.root,
    required this.itemType,
    required super.isNonNull,
  }) : super._();

  @override
  String toString() => '[$itemType]${isNonNull ? '!' : ''}';
}

class SchemaQuery with SchemaNameMixin {
  @override
  final String name;
  final List<SchemaParam> parameters;
  final SchemaDef returnType;

  const SchemaQuery({
    required this.name,
    required this.parameters,
    required this.returnType,
  });

  factory SchemaQuery.parse(Schema schema, FieldDefinitionNode node) {
    return SchemaQuery(
      name: node.name.value,
      parameters: node.args.map((e) => SchemaParam.parse(schema, e)).toList(),
      returnType: SchemaDef._parse(schema, node.type),
    );
  }
}

class SchemaParam with SchemaNameMixin {
  @override
  final String name;
  final SchemaDef definition;
  final bool hasDefaultValue;

  bool get isRequired => definition.isNonNull && !hasDefaultValue;

  const SchemaParam._({
    required this.name,
    required this.definition,
    required this.hasDefaultValue,
  });

  factory SchemaParam.parse(Schema schema, InputValueDefinitionNode node) {
    final type = SchemaDef._parse(schema, node.type);
    return SchemaParam._(
      name: node.name.value,
      definition: type,
      hasDefaultValue: node.defaultValue != null,
    );
  }
}

abstract class SchemaType {
  final Schema schema;
  final String name;

  const SchemaType({required this.schema, required this.name});
}

class SchemaObject extends SchemaType {
  final List<SchemaField> fields;

  const SchemaObject({
    required super.schema,
    required super.name,
    required this.fields,
  });

  factory SchemaObject.parse(Schema schema, ObjectTypeDefinitionNode node) {
    return SchemaObject(
      schema: schema,
      name: node.name.value,
      fields: node.fields.map((e) => SchemaField._field(schema, e)).toList(),
    );
  }
}

class SchemaInput extends SchemaType {
  final List<SchemaParam> fields;

  const SchemaInput({
    required super.schema,
    required super.name,
    required this.fields,
  });

  factory SchemaInput.parse(Schema schema, InputObjectTypeDefinitionNode node) {
    return SchemaInput(
      schema: schema,
      name: node.name.value,
      fields: node.fields.map((e) => SchemaParam.parse(schema, e)).toList(),
    );
  }
}

class SchemaEnum extends SchemaType {
  final List<SchemaEnumValue> values;

  const SchemaEnum({
    required super.schema,
    required super.name,
    required this.values,
  });

  factory SchemaEnum.parse(Schema schema, EnumTypeDefinitionNode node) {
    return SchemaEnum(
      schema: schema,
      name: node.name.value,
      values: node.values.map(SchemaEnumValue.parse).toList(),
    );
  }
}

class SchemaEnumValue {
  final String name;
  final bool deprecated;

  const SchemaEnumValue({required this.name, required this.deprecated});

  factory SchemaEnumValue.parse(EnumValueDefinitionNode node) {
    final deprecated = node.directives.firstWhereOrNull(
      (e) => e.name.value == 'deprecated',
    );

    return SchemaEnumValue(
      name: node.name.value,
      deprecated: deprecated != null,
    );
  }
}

class SchemaUnion extends SchemaType {
  final List<SchemaDef> values;

  const SchemaUnion._({
    required super.schema,
    required super.name,
    required this.values,
  });

  factory SchemaUnion._parse(Schema schema, UnionTypeDefinitionNode node) {
    return SchemaUnion._(
      schema: schema,
      name: node.name.value,
      values: node.types.map((e) => SchemaDef._parse(schema, e)).toList(),
    );
  }
}

class SchemaField {
  final String name;
  final SchemaDef definition;
  final bool deprecated;

  const SchemaField._({
    required this.name,
    required this.definition,
    required this.deprecated,
  });

  factory SchemaField._field(Schema schema, FieldDefinitionNode node) {
    final type = SchemaDef._parse(schema, node.type);
    final deprecated = node.directives.firstWhereOrNull(
      (e) => e.name.value == 'deprecated',
    );

    return SchemaField._(
      name: node.name.value,
      definition: type,
      deprecated: deprecated != null,
    );
  }
}

mixin SchemaNameMixin {
  String get name;
}

class Schema {
  final objects = <SchemaType>[];
  final queries = <SchemaQuery>[];
  final mutations = <FieldDefinitionNode>[];

  Schema._();

  factory Schema.parse({required String schemaFolder}) {
    if (!Directory(schemaFolder).existsSync()) {
      throw GrapherError('Schema folder "$schemaFolder" not found');
    }

    final files = Directory(
      schemaFolder,
    ).listSync(recursive: true).where((e) => e.path.endsWith('.graphqls'));

    final objectNodes = <ObjectTypeDefinitionNode>[];
    final inputNodes = <InputObjectTypeDefinitionNode>[];
    final enumNodes = <EnumTypeDefinitionNode>[];
    final unionNodes = <UnionTypeDefinitionNode>[];

    final queries = <FieldDefinitionNode>[];
    final mutations = <FieldDefinitionNode>[];

    for (final path in files) {
      final file = File(path.path);
      final definitions = gql.parseString(file.readAsStringSync()).definitions;

      objectNodes.addAll(definitions.whereType<ObjectTypeDefinitionNode>());
      enumNodes.addAll(definitions.whereType<EnumTypeDefinitionNode>());
      inputNodes.addAll(definitions.whereType<InputObjectTypeDefinitionNode>());
      unionNodes.addAll(definitions.whereType<UnionTypeDefinitionNode>());

      queries.addAll(
        definitions
            .whereType<ObjectTypeDefinitionNode>()
            .where((e) => e.name.value == 'Query')
            .expand((e) => e.fields),
      );
      queries.addAll(
        definitions
            .whereType<ObjectTypeExtensionNode>()
            .where((e) => e.name.value == 'Query')
            .expand((e) => e.fields),
      );
      mutations.addAll(
        definitions
            .whereType<ObjectTypeDefinitionNode>()
            .where((e) => e.name.value == 'Mutation')
            .expand((e) => e.fields),
      );
      mutations.addAll(
        definitions
            .whereType<ObjectTypeExtensionNode>()
            .where((e) => e.name.value == 'Mutation')
            .expand((e) => e.fields),
      );
    }

    final schema = Schema._();

    schema.objects.addAll([
      ...objectNodes.map((e) => SchemaObject.parse(schema, e)),
      ...unionNodes.map((e) => SchemaUnion._parse(schema, e)),
      ...inputNodes.map((e) => SchemaInput.parse(schema, e)),
      ...enumNodes.map((e) => SchemaEnum.parse(schema, e)),
    ]);

    schema.queries.addAll(queries.map((e) => SchemaQuery.parse(schema, e)));

    return schema;
  }

  SchemaType? get(String name) =>
      objects.firstWhereOrNull((e) => e.name == name);
}
