import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/buffer.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/source/class.dart';
import 'package:grapher_builder/src/source/definition.dart';
import 'package:grapher_builder/src/utils/config.dart';

class MutationSource extends Entity {
  @override
  final ClassEntityType? parent;
  final String dartName;
  final String graphName;
  late final List<MethodParameter> params;
  late final Definition result;

  @override
  String get identifier => dartName;

  MutationSource({
    required super.resolvers,
    required this.parent,
    required this.dartName,
    required this.graphName,
  });

  static List<MutationSource> parseClass(
    ClassEntityType parent,
    ClassElement element,
  ) {
    return [
      ...element.getters.map((e) => MutationSource.parseGetter(parent, e)),
      ...element.methods.map((e) => MutationSource.parse(parent, e)),
    ].nonNulls.toList();
  }

  static MutationSource? parse(ClassEntityType parent, MethodElement element) {
    final fullName =
        '${element.enclosingElement?.displayName}.${element.displayName}';
    final annotation = MutationAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    if (!element.isStatic) {
      throw Exception('$fullName may be static!');
    }
    final result = element.returnType;
    if (result is InterfaceType) {
      final object = MutationSource(
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
    throw Exception('$fullName may return Query<T>');
  }

  static MutationSource? parseGetter(
    ClassEntityType parent,
    GetterElement element,
  ) {
    final annotation = MutationAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    final result = element.returnType as InterfaceType;

    final object = MutationSource(
      resolvers: concat(parent.resolvers, annotation.resolvers),
      parent: parent,
      dartName: element.displayName,
      graphName: annotation.name,
    );

    object.params = [MethodParameter.input(parent, object)];
    object.result = Definition.parse(object, result.typeArguments.first);

    return object;
  }

  static MutationSource? parseTopLevelFunction(
    TopLevelFunctionElement element,
  ) {
    final annotation = MutationAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    final result = element.returnType as InterfaceType;

    final object = MutationSource(
      parent: null,
      resolvers: annotation.resolvers,
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

    final input = schema.mutations.firstWhereOrNull(
      (e) => e.name.value == graphName,
    );
    if (input == null) {
      throw Exception('Mutation $graphName  is not found');
    }
  }

  String generate() {
    final b = Buffer();

    b.write('Mutation<${result.dartNameFull}> _');
    b.write([?parent?.dartName, dartName].uncapitalized);
    b.writeln('(');
    for (final param in params) {
      b.writeln('${param.def.dartNameFull} ${param.dartName},');
    }
    b.writeln(') { ');

    // Body variable
    b.writeln("const body = '''");
    b.writeln("mutation ${graphName.capitalized}(");
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

    // Return Mutation<T>
    b.writeln('return Mutation<${result.dartNameFull}>(');
    b.writeln("\tname: '$graphName',");
    b.writeln("\tvariables: {");
    for (final param in params) {
      b.write("'${param.dartName}': ");
      b.write(param.def.type.generateToMapValue(param.dartName));
      b.writeln(",");
    }
    b.writeln("},");
    b.writeln("\tbody: body,");
    b.writeln("\tparserFn: (e) => ${result.generateFromMapField('e')},");
    b.writeln(');');

    b.writeln('}');

    return b.toString();
  }
}
