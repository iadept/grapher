import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/utils/schema.dart';

class Config {
  static Config? _instance;

  final Schema? schema;
  final bool throwCriticalError;

  final Map<String, BaseType> _objects = {};

  Config._({required this.schema, required this.throwCriticalError});

  factory Config() => _instance!;

  factory Config.load(BuilderOptions options) {
    final schemaFolder = options.config['schemaFolder'];
    final throwCriticalError = options.config['throwCriticalError'] ?? true;

    Schema? schema;

    if (schemaFolder != null) {
      schema = Schema.parse(schemaFolder: schemaFolder);
    }

    final instance = Config._(
      schema: schema,
      throwCriticalError: throwCriticalError,
    );

    _instance = instance;
    return instance;
  }

  BaseType? get(Element value) => _objects[value.libraryPath];

  void add(BaseType value) => _objects[value.library ?? value.dartName] = value;
}
