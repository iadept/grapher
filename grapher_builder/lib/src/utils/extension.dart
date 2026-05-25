import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/source/class.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/schema.dart';

extension ObjectExtension<T extends Object> on T {
  K apply<K>(K Function(T value) op) {
    return op(this);
  }

  K? as<K>() {
    if (this is K) {
      return this as K;
    }
    return null;
  }
}

extension StringExtension on String {
  String get capitalized {
    if (isEmpty) return '';
    if (length == 1) return toUpperCase();
    return '${this[0].toUpperCase()}${substring(1)}';
  }

  String get uncapitalized {
    if (isEmpty) return '';
    if (length == 1) return toLowerCase();
    return '${this[0].toLowerCase()}${substring(1)}';
  }
}

extension StringIterableExtension on Iterable<String> {
  String get uncapitalized {
    if (length == 1) return first.uncapitalized;
    return [
      first.uncapitalized,
      ...toList().sublist(1).map((e) => e.capitalized),
    ].join('');
  }
}

const _annotationPath = 'package:grapher_annotation/grapher_annotation.dart';

extension ElementExtension on Element {
  String get libraryPath => '${library?.identifier}.$name';

  bool get isIDType => libraryPath == '$_annotationPath.ID';
}

extension VariableElementExtension on VariableElement {
  bool get isEnumValue => isStatic && isConst;
}

List<ResolverAnnotation>? concat<T>(
  List<ResolverAnnotation>? l1,
  List<ResolverAnnotation>? l2,
) {
  final result = {...?l1, ...?l2};
  return result.isEmpty ? null : result.toList();
}

extension ListParameterExtension<E extends Parameter> on List<E> {
  E? byName(String name) {
    return firstWhereOrNull((e) => name == (e.graphName ?? e.dartName));
  }
}

extension ListSchemaNameMixin<T extends SchemaNameMixin> on List<T> {
  T? byName(String name) {
    return firstWhereOrNull((e) => e.name == name);
  }
}
