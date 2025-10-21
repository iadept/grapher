import 'package:analyzer/dart/element/element.dart';
import 'package:analyzer/dart/element/type.dart';
import 'package:grapher_builder/src/utils/annotation_data.dart';
import 'package:grapher_builder/src/utils/buffer.dart';
import 'package:grapher_builder/src/source/entity.dart';
import 'package:grapher_builder/src/utils/extension.dart';
import 'package:grapher_builder/src/source/definition.dart';
import 'package:grapher_builder/src/source/type.dart';

class SubscriptionSource extends Part {
  @override
  final ClassEntityType? parent;
  final String dartName;
  final String graphName;

  late final Definition result;

  @override
  String get identifier => dartName;

  SubscriptionSource._({
    required super.resolvers,
    required this.parent,
    required this.dartName,
    required this.graphName,
  });

  static List<SubscriptionSource> parseClass(
    ClassEntityType parent,
    ClassElement element,
  ) {
    return [
      ...element.getters.map((e) => SubscriptionSource.parseGetter(parent, e)),
    ].nonNulls.toList();
  }

  static SubscriptionSource? parseGetter(
    ClassEntityType parent,
    GetterElement element,
  ) {
    final annotation = SubscriptionAnnotation.peek(element);
    if (annotation == null) {
      return null;
    }
    final result = element.returnType as InterfaceType;

    final object = SubscriptionSource._(
      resolvers: concat(parent.resolvers, annotation.resolvers),
      parent: parent,
      dartName: element.displayName,
      graphName: annotation.name,
    );

    object.result = Definition.parse(object, result.typeArguments.first);

    return object;
  }

  String generate() {
    final b = Buffer();

    // Function signature
    b.write('Subscription<${result.dartNameFull}> _');
    b.write([?parent?.dartName, dartName].uncapitalized);
    b.writeln('()');

    b.writeln(' { ');

    // Body variable
    b.writeln("const body = '''");
    b.writeln("subscription ${graphName.capitalized} {");
    b.block((b) {
      b.write(graphName);

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
    b.writeln("''';");

    // Return Query<T>
    b.writeln('return Subscription<${result.dartNameFull}>(');
    b.writeln("\tname: '$graphName',");
    b.writeln("\tbody: body,");

    b.writeln("\tparserFn: (json) => ${result.generateFromMapField('json')},");
    b.writeln(');');

    b.writeln('}');

    return b.toString();
  }
}
