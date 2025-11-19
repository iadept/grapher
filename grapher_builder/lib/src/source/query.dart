import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/source/class.dart';
import 'package:grapher_builder/src/source/definition.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/buffer.dart';
import 'package:grapher_builder/src/utils/config.dart';
import 'package:grapher_builder/src/utils/extension.dart';

class QuerySource extends Entity {
  @override
  final ClassEntityType? parent;
  final String dartName;
  final String graphName;

  late final List<MethodParameter> params;
  late final Definition result;

  @override
  String get identifier => dartName;

  QuerySource._({
    required super.resolvers,
    required this.parent,
    required this.dartName,
    required this.graphName,
  });

  static List<QuerySource> parseClass(
    ClassEntityType parent,
    ClassElement element,
  ) {
    return [
      ...element.getters.map((e) => QuerySource.parseGetter(parent, e)),
      ...element.methods.map((e) => QuerySource.parse(parent, e)),
    ].nonNulls.toList();
  }

  static QuerySource? parse(ClassEntityType parent, MethodElement element) {
    final annotation = QueryAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    if (!element.isStatic) {
      throw Exception('${element.displayName} may be static!');
    }
    final result = element.returnType;
    if (result is InterfaceType) {
      final object = QuerySource._(
        resolvers: concat(parent.resolvers, annotation.resolvers),
        parent: parent,
        dartName: element.displayName,
        graphName: annotation.name,
      );

      object.params = element.formalParameters
          .map((e) => MethodParameter.parse(object, e))
          .toList();

      object.result = Definition.parse(object, result.typeArguments.first);

      return object;
    }
    throw Exception('${element.displayName} may return Query<T>');
  }

  static QuerySource? parseGetter(
    ClassEntityType parent,
    GetterElement element,
  ) {
    final annotation = QueryAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    final result = element.returnType as InterfaceType;

    final object = QuerySource._(
      resolvers: concat(parent.resolvers, annotation.resolvers),
      parent: parent,
      dartName: element.displayName,
      graphName: annotation.name,
    );

    object.params = [MethodParameter.input(parent, object)];
    object.result = Definition.parse(object, result.typeArguments.first);

    return object;
  }

  static QuerySource? parseTopLevelFunction(TopLevelFunctionElement element) {
    final annotation = QueryAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }

    final result = element.returnType as InterfaceType; // Check Query

    final object = QuerySource._(
      resolvers: annotation.resolvers,
      parent: null,
      dartName: element.displayName,
      graphName: annotation.name,
    );

    object.params = element.formalParameters
        .map((e) => MethodParameter.parse(object, e))
        .toList();

    object.result = Definition.parse(object, result.typeArguments.first);

    return object;
  }

  ValidationError? validate() {
    final schema = Config().schema;
    if (schema == null) return null;

    final query = schema.queries.byName(graphName);
    if (query == null) {
      return ValidationError.notFound(graphName, rawLocation);
    }

    // Check required parameters
    for (final requiredParam in query.parameters.where((e) => e.isRequired)) {
      if (params.byName(requiredParam.name) == null) {
        return ValidationError.parameterMissing(
          requiredParam.name,
          graphName,
          rawLocation,
        );
      }
    }

    for (final param in params) {
      final name = param.graphName ?? param.dartName;
      final schemaParam = query.parameters.byName(name);
      if (schemaParam != null) {
        if (schemaParam.isRequired && param.def.isNullable) {
          // TODO Check
          return ValidationError.nullabilityMismatch(
            param.def.isNullable,
            schemaParam.definition.isNullable,
            param.rawLocation,
          );
        }
      }
    }

    return result.validate(query.returnType, skipNullability: true);
  }

  String generate() {
    final b = Buffer();
    // Function signature
    b.write('Query<${result.dartNameFull}> _');
    b.write([?parent?.dartName, dartName].uncapitalized);
    b.writeln('(');
    b.block(
      (b) =>
          b.writeln(params.map((e) => '${e.def.dartNameFull} ${e.dartName},')),
    );
    b.writeln('{Duration? cacheTTL,}');
    b.writeln(') { ');

    // Body variable
    b.writeln("const body = '''");
    b.writeln("query ${graphName.capitalized}(");
    b.block((b) => b.writeln(params.map((e) => e.queryParameter)));
    b.writeln(") {");
    b.block((b) {
      b.write("$graphName(");
      b.write(
        [
          params.firstOrNull,
        ].nonNulls.map((e) => e.queryParameterValue).join(','),
      );

      b.write(")");
      final query = result.graphBody()?.split('\n');
      if (query != null) {
        b.writeln(" {");
        b.block((b) => b.writeln(query));
        b.writeln("}");
      } else {
        b.writeln();
      }
    });

    b.write("}");
    b.write("''';");

    // Return Query<T>
    b.writeln('return Query<${result.dartNameFull}>(');
    b.writeln("\tname: '$graphName',");
    b.writeln("\tvariables: {");
    for (final param in params) {
      b.write("'${param.dartName}': ");
      b.write(param.def.generateToMapValue(param.dartName));
      b.writeln(",");
    }
    b.writeln("},");
    b.writeln("\tbody: body,");

    b.writeln("\tparserFn: (json) => ${result.generateFromMapField('json')},");
    b.writeln("\tcacheTTL: cacheTTL,");
    b.writeln(');');

    b.writeln('}');

    return b.toString();
  }
}
