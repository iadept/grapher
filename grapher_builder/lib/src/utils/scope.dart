import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/utils/schema.dart';

class Scope {
  static Scope? _instance;

  final Schema? schema;
  final bool allowUnknownEnum;

  final Map<String, BaseType> _objects = {};

  Scope._({required this.schema, required this.allowUnknownEnum});

  factory Scope() => _instance!;

  factory Scope.make(BuilderOptions options) {
    final schemaFolder = options.config['schemaFolder'];
    final allowUnnamedEnum = options.config['allowUnnamedEnum'] as bool?;

    Schema? schema;

    if (schemaFolder != null) {
      schema = Schema.parse(schemaFolder: schemaFolder);
    }

    final instance = Scope._(
      schema: schema,
      allowUnknownEnum: allowUnnamedEnum ?? false,
    );

    _instance = instance;
    return instance;
  }

  BaseType? get(Element value) => _objects[value.libraryPath];

  void add(BaseType value) => _objects[value.library ?? value.dartName] = value;
}
