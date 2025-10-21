import 'package:analyzer/dart/element/element.dart';
import 'package:collection/collection.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';

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

extension IterableExtension<E> on Iterable<E> {
  bool containsWhere(bool Function(E element) test) =>
      firstWhereOrNull(test) != null;
}

const _annotationPath = 'package:grapher_annotation/grapher_annotation.dart';

extension ElementExtension on Element {
  String get libraryPath => '${library?.identifier}.$name';

  bool get isIDType => libraryPath == '$_annotationPath.ID';
  bool get isJSONType => libraryPath == '$_annotationPath.JSON';
}

extension VariableElementExtension on VariableElement {
  bool get isEnumValue => isStatic && isConst && !isSynthetic;
}

List<ResolverAnnotation>? concat<T>(
  List<ResolverAnnotation>? l1,
  List<ResolverAnnotation>? l2,
) {
  final result = {...?l1, ...?l2};
  return result.isEmpty ? null : result.toList();
}
