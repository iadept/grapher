import 'package:analyzer/dart/element/element.dart';
import 'package:build/build.dart';
import 'package:grapher_annotation/grapher_annotation.dart';
import 'package:grapher_builder/src/source/mutation.dart';
import 'package:grapher_builder/src/source/query.dart';
import 'package:grapher_builder/src/source/subscription.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/exception.dart';
import 'package:grapher_builder/src/utils/scope.dart';
import 'package:source_gen/source_gen.dart';

class _EntityGenerator extends GeneratorForAnnotation<GrapherObject> {
  final Set<String> generated;

  const _EntityGenerator(this.generated);

  @override
  generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    try {
      final source = ClassEntityType.parse(
        ObjectAnnotation.peek(element as ClassElement)!,
        element,
      );

      final queries = SourceQuery.parseClass(source, element);

      final subscription = SubscriptionSource.parseClass(source, element);

      generated.addAll(queries.map((e) => e.location));

      source.validate();
      final result = StringBuffer();
      result.writeln(
        [
          ...queries.map((e) => e.generate()),
          ...subscription.map((e) => e.generate()),
          source.generateFromMap(),
        ].nonNulls.join('\n'),
      );

      return result.toString();
    } catch (e, s) {
      onBuildError(e, s, element);
    }
  }
}

class _InputGenerator extends GeneratorForAnnotation<GrapherInput> {
  final Set<String> generated;

  const _InputGenerator(this.generated);

  @override
  generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    try {
      final source = ClassEntityType.parse(
        InputAnnotation.peek(element as ClassElement)!,
        element,
      );
      source.validateInput;

      final query = SourceQuery.parseClass(
        source,
        element,
      ).where((e) => !generated.contains(e.location));
      final mutations = SourceMutation.parseClass(source, element);

      final result = StringBuffer();
      result.writeln(
        [
          source.generateToMap(),
          ...query.map((e) => e.generate()),
          ...mutations.map((e) => e.generate()),
        ].nonNulls.join('\n'),
      );
      return result.toString();
    } catch (e, s) {
      onBuildError(e, s, element);
    }
  }
}

class _EnumGenerator extends GeneratorForAnnotation<GrapherEnum> {
  @override
  generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final source = EnumType.parse(element as EnumElement);
    try {
      source.validate();
    } on ValidationError catch (e, s) {
      onBuildError(e, s, element);
    }
    final result = StringBuffer();
    result.writeln(
      [source.generateFromMap(), source.generateToMap()].nonNulls.join('\n'),
    );
    return result.toString();
  }
}

class _MutationGenerator extends GeneratorForAnnotation<GrapherMutation> {
  @override
  generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    final source = SourceMutation.parseTopLevelFunction(
      element as TopLevelFunctionElement,
    );
    // source.validate(scope.schema);
    final result = StringBuffer();
    result.writeln([source?.generate()].nonNulls.join('\n'));
    return result.toString();
  }
}

class _QueryGenerator extends GeneratorForAnnotation<GrapherQuery> {
  @override
  generateForAnnotatedElement(
    Element element,
    ConstantReader annotation,
    BuildStep buildStep,
  ) {
    try {
      final source = SourceQuery.parseTopLevelFunction(
        element as TopLevelFunctionElement,
      );

      //  source?.validate();

      final result = StringBuffer();
      result.writeln([source?.generate()].nonNulls.join('\n'));
      return result.toString();
    } catch (e, s) {
      onBuildError(e, s, element);
    }
  }
}

/// The main builder function that initializes the scope and sets up the code generators.
Builder grapherBuilder(BuilderOptions options) {
  Scope.make(options);

  final generated = <String>{};

  return SharedPartBuilder([
    _EntityGenerator(generated),
    _InputGenerator(generated),
    _EnumGenerator(),
    _MutationGenerator(),
    _QueryGenerator(),
  ], 'grapher');
}
