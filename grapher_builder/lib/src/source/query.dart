import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/source/class.dart';
import 'package:grapher_builder/src/source/definition.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/buffer.dart';
import 'package:grapher_builder/src/utils/exception.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/utils/config.dart';

class SourceQuery extends Entity {
  @override
  final ClassEntityType? parent;
  final String dartName;
  final String graphName;

  late final List<MethodParameter> params;
  late final Definition result;

  @override
  String get identifier => 'Query<$dartName>';

  SourceQuery._({
    required super.resolvers,
    required this.parent,
    required this.dartName,
    required this.graphName,
  });

  static List<SourceQuery> parseClass(
    ClassEntityType parent,
    ClassElement element,
  ) {
    return [
      ...element.getters.map((e) => SourceQuery.parseGetter(parent, e)),
      ...element.methods.map((e) => SourceQuery.parse(parent, e)),
    ].nonNulls.toList();
  }

  static SourceQuery? parse(ClassEntityType parent, MethodElement element) {
    final annotation = QueryAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    if (!element.isStatic) {
      throw Exception('${element.displayName} may be static!');
    }
    final result = element.returnType;
    if (result is InterfaceType) {
      final object = SourceQuery._(
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

  static SourceQuery? parseGetter(
    ClassEntityType parent,
    GetterElement element,
  ) {
    final annotation = QueryAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    final result = element.returnType as InterfaceType;

    final object = SourceQuery._(
      resolvers: concat(parent.resolvers, annotation.resolvers),
      parent: parent,
      dartName: element.displayName,
      graphName: annotation.name,
    );

    object.params = [MethodParameter.input(parent, object)];
    object.result = Definition.parse(object, result.typeArguments.first);

    return object;
  }

  static SourceQuery? parseTopLevelFunction(TopLevelFunctionElement element) {
    final annotation = QueryAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }

    final result = element.returnType as InterfaceType; // Check Query

    final object = SourceQuery._(
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

  void validate() {
    final schema = Config().schema;
    if (schema == null) return;

    final query = schema.queries.firstWhereOrNull((e) => e.name == graphName);
    if (query == null) {
      throw GrapherException.notFound(location, graphName);
    }

    // Check required
    for (final param in query.parameters) {
      if (params.containsWhere((e) => e.graphName == param.name) &&
          param.definition.isNonNull) {
        throw Exception(
          'Parameter "${param.name}" is required in "$graphName"',
        );
      }
    }

    for (final param in [params.firstOrNull].nonNulls) {
      final name = param.graphName ?? param.dartName;
      final schemaParam = query.parameters.firstWhereOrNull(
        (e) => e.name == name,
      );

      if (schemaParam == null) {
        throw GrapherException(
          'Parameter "$name" in query "$graphName" is not found',
          path: location,
        );
      }
      param.validate(schemaParam);
    }
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
