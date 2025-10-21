import 'dart:io';

import 'package:collection/collection.dart';
import 'package:gql/ast.dart';
import "package:gql/language.dart" as gql;
import 'package:grapher_builder/src/utils/exception.dart';

class SchemaQuery {
  final String name;
  final List<SchemaParameter> parameters;
  final SchemaDefinition returnType;

  const SchemaQuery({
    required this.name,
    required this.parameters,
    required this.returnType,
  });

  factory SchemaQuery.parse(Schema schema, FieldDefinitionNode node) {
    return SchemaQuery(
      name: node.name.value,
      parameters: node.args
          .map((e) => SchemaParameter.parse(schema, e))
          .toList(),
      returnType: SchemaDefinition._parse(schema, node.type),
    );
  }
}

class SchemaParameter {
  final String name;
  final SchemaDefinition definition;
  final bool hasDefaultValue;

  bool get isRequired => definition.isNonNull && !hasDefaultValue;

  const SchemaParameter({
    required this.name,
    required this.definition,
    required this.hasDefaultValue,
  });

  factory SchemaParameter.parse(Schema schema, InputValueDefinitionNode node) {
    final type = SchemaDefinition._parse(schema, node.type);
    return SchemaParameter(
      name: node.name.value,
      definition: type,
      hasDefaultValue: node.defaultValue != null,
    );
  }
}

sealed class SchemaDefinition {
  final Schema schema;
  final bool isNonNull;

  const SchemaDefinition({required this.schema, required this.isNonNull});

  factory SchemaDefinition._parse(Schema schema, TypeNode node) {
    if (node is NamedTypeNode) {
      return SchemaNameType(
        schema: schema,
        name: node.name.value,
        isNonNull: node.isNonNull,
      );
    } else if (node is ListTypeNode) {
      final itemType = SchemaDefinition._parse(schema, node.type);
      return SchemaListType(
        schema: schema,
        itemType: itemType,
        isNonNull: node.isNonNull,
      );
    } else {
      throw UnimplementedError();
    }
  }
}

class SchemaNameType extends SchemaDefinition {
  final String name;

  SchemaBase? get object => schema.get(name);

  const SchemaNameType({
    required super.schema,
    required this.name,
    required super.isNonNull,
  });

  @override
  String toString() => name + (isNonNull ? '!' : '');
}

class SchemaListType extends SchemaDefinition {
  final SchemaDefinition itemType;

  const SchemaListType({
    required super.schema,
    required this.itemType,
    required super.isNonNull,
  });

  @override
  String toString() => '[$itemType]${isNonNull ? '!' : ''}';
}

abstract class SchemaBase {
  final Schema schema;
  final String name;

  const SchemaBase({required this.schema, required this.name});
}

class SchemaObject extends SchemaBase {
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

class SchemaInput extends SchemaBase {
  final List<SchemaParameter> fields;

  const SchemaInput({
    required super.schema,
    required super.name,
    required this.fields,
  });

  factory SchemaInput.parse(Schema schema, InputObjectTypeDefinitionNode node) {
    return SchemaInput(
      schema: schema,
      name: node.name.value,
      fields: node.fields.map((e) => SchemaParameter.parse(schema, e)).toList(),
    );
  }
}

class SchemaEnum extends SchemaBase {
  final List<String> values;

  const SchemaEnum({
    required super.schema,
    required super.name,
    required this.values,
  });

  factory SchemaEnum.parse(Schema schema, EnumTypeDefinitionNode node) {
    return SchemaEnum(
      schema: schema,
      name: node.name.value,
      values: node.values.map((e) => e.name.value).toList(),
    );
  }
}

class SchemaField {
  final String name;
  final SchemaDefinition definition;

  const SchemaField({required this.name, required this.definition});

  factory SchemaField._field(Schema schema, FieldDefinitionNode node) {
    final type = SchemaDefinition._parse(schema, node.type);
    return SchemaField(name: node.name.value, definition: type);
  }
}

class Schema {
  final objects = <SchemaBase>[];
  final queries = <SchemaQuery>[];
  final mutations = <FieldDefinitionNode>[];

  Schema._();

  factory Schema.parse({required String schemaFolder}) {
    if (!Directory(schemaFolder).existsSync()) {
      throw GrapherException('Schema folder "$schemaFolder" not found');
    }

    final files = Directory(
      schemaFolder,
    ).listSync(recursive: true).where((e) => e.path.endsWith('.graphqls'));

    final objectNodes = <ObjectTypeDefinitionNode>[];
    final inputNodes = <InputObjectTypeDefinitionNode>[];
    final enumNodes = <EnumTypeDefinitionNode>[];

    final queries = <FieldDefinitionNode>[];
    final mutations = <FieldDefinitionNode>[];

    for (final path in files) {
      final file = File(path.path);
      final definitions = gql.parseString(file.readAsStringSync()).definitions;

      objectNodes.addAll(definitions.whereType<ObjectTypeDefinitionNode>());
      enumNodes.addAll(definitions.whereType<EnumTypeDefinitionNode>());
      inputNodes.addAll(definitions.whereType<InputObjectTypeDefinitionNode>());

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
      ...inputNodes.map((e) => SchemaInput.parse(schema, e)),
      ...enumNodes.map((e) => SchemaEnum.parse(schema, e)),
    ]);

    schema.queries.addAll(queries.map((e) => SchemaQuery.parse(schema, e)));

    return schema;
  }

  SchemaBase? get(String name) =>
      objects.firstWhereOrNull((e) => e.name == name);
}
