import 'package:grapher_builder/src/source/class.dart';
import 'package:grapher_builder/src/source/definition.dart';
import 'package:grapher_builder/src/source/type.dart';
import 'package:grapher_builder/src/utils/buffer.dart';
import 'package:grapher_builder/src/utils/config.dart';
import 'package:grapher_builder/src/utils/exception.dart';
import 'package:grapher_builder/src/utils/schema.dart';

/// Builds the selection set of an operation and the named fragments it uses.
///
/// A recursive field (one that leads back to a type it is selected from) is
/// expanded up to [ConstructorField.maxDepth] times. A fragment cannot contain
/// such a field (fragment spreads must not form cycles), so it is left out of
/// the fragment definition and selected next to the spread instead:
///
/// ```graphql
/// widgets {
///   ...EntityChatWidgetFields
///   ... on EntityChatBlockWidget { children { ...EntityChatWidgetFields } }
/// }
/// ```
class Selection {
  final Map<String, _Fragment> _fragments = {};
  final Set<String> _building = {};

  /// Selection set of [def]; null for scalars.
  String? body(Definition def) => _body(def, null, _Scope.operation());

  /// Definitions of the fragments used by the selection.
  Iterable<String> get fragments => _fragments.values.map((e) => e.definition);

  String? _body(Definition def, GenericMapped? parentMapped, _Scope scope) {
    final mapped = def.mergeGenerics(parentMapped);
    switch (def.type) {
      case SimpleType():
      case EnumType():
        return null;
      case ClassWithResolverType e:
        return e.resolver.queryBody;
      case ClassEntityType e:
        if (e.isFragment) {
          final type = e.graphName ?? e.dartName;
          return _spread(
            '${type}Fields',
            type,
            {_key(e, mapped)},
            (scope) => _classBody(e, mapped, scope),
            scope,
          );
        }
        return _classBody(e, mapped, scope);
      case ListType e:
        return _body(e.item, mapped, scope);
      case GenericType e:
        final mappedDef = mapped?[e.dartName];
        return mappedDef == null ? null : _body(mappedDef, mapped, scope);
      case ObjectType():
        throw UnimplementedError();
    }
  }

  String _classBody(ClassEntityType e, GenericMapped? mapped, _Scope scope) {
    final buffer = Buffer();
    buffer.writeln('__typename');
    for (final field in _classFields(e, mapped, scope)) {
      buffer.writeln(field.split('\n'));
    }
    return buffer.toString();
  }

  /// Selections of the fields of [e], without `__typename`.
  List<String> _classFields(
    ClassEntityType e,
    GenericMapped? mapped,
    _Scope scope,
  ) {
    final inner = scope.enter(_key(e, mapped));
    return [
      for (final param in e.constructor.params.where((e) => !e.skipInQuery))
        ?_field(param, mapped, inner),
    ];
  }

  /// Selection of one field; null when the field is omitted.
  String? _field(
    ConstructorField param,
    GenericMapped? mapped,
    _Scope scope, {
    bool isRecursive = false,
  }) {
    var inner = scope;
    if (isRecursive ||
        _targets(param, mapped).any((e) => scope.path.contains(e))) {
      final deferred = scope.deferred;
      if (deferred != null) {
        deferred.add(_Deferred(scope.wrappers, param, mapped));
        return null;
      }
      final maxDepth = param.maxDepth;
      if (maxDepth == null) {
        throw GrapherError(
          'Recursive field needs "maxDepth" in @GrapherField',
          path: param.location,
        );
      }
      if (scope.depthOf(param) >= maxDepth) {
        return null;
      }
      inner = scope.deepen(param);
    }

    final header = StringBuffer(param.graphName ?? param.dartName);
    if (param.input != null) {
      header.write('(${param.inputName}: \\\$${param.input!})');
    }
    inner = inner.wrap(header.toString());

    final body = param.union != null
        ? _unionBody(param, mapped, inner)
        : _body(param.def, mapped, inner);

    final buffer = Buffer();
    buffer.write(header.toString());
    if (body != null) {
      buffer.writeln(' {');
      buffer.block((b) => b.writeln(body.split('\n')));
      buffer.write('}');
    }
    return buffer.toString();
  }

  String _unionBody(
    ConstructorField param,
    GenericMapped? mapped,
    _Scope scope,
  ) {
    final type = param.fragment;

    String members(_Scope scope) {
      // Field selections of each member; null when the member is not a plain
      // class (a fragment or a resolver), its body is then selected as is.
      final fields = <String, List<String>?>{};
      final bodies = <String, String?>{};
      param.union!.forEach((key, value) {
        final def = Definition.parse(param, value);
        final memberScope = scope.wrap('... on $key');
        final memberMapped = def.mergeGenerics(mapped);
        final defType = def.type;
        if (defType is ClassEntityType && !defType.isFragment) {
          fields[key] = _classFields(defType, memberMapped, memberScope);
        } else {
          fields[key] = null;
          bodies[key] = _body(def, mapped, memberScope);
        }
      });
      final shared = _sharedFields(type, fields.values);

      final buffer = Buffer();
      buffer.writeln('__typename');
      for (final field in shared) {
        buffer.writeln(field.split('\n'));
      }
      for (final MapEntry(:key, :value) in fields.entries) {
        final body = value == null
            ? bodies[key]
            : value.where((e) => !shared.contains(e)).join('\n');
        if (body != null && body.isNotEmpty) {
          buffer.writeln('... on $key {');
          buffer.block((b) => b.writeln(body.split('\n')));
          buffer.writeln('}');
        }
      }
      return buffer.toString();
    }

    if (type == null) {
      return members(scope);
    }
    final schema = Config().schema;
    if (schema != null) {
      final object = schema.get(type);
      if (object == null) {
        throw GrapherError.notFound(param.location, type);
      }
      if (object is! SchemaUnion && object is! SchemaInterface) {
        throw GrapherError(
          'Fragment type "$type" must be a union or an interface',
          path: param.location,
        );
      }
    }
    return _spread(
      '${type}Fields',
      type,
      _targets(param, mapped).toSet(),
      members,
      scope,
    );
  }

  /// Fields every member of the interface [type] selects the same way; they
  /// are selected once on the interface instead of in each `... on` member.
  ///
  /// Only fields the schema declares on the interface are shared: a union
  /// (or an unknown type) has no fields of its own.
  List<String> _sharedFields(String? type, Iterable<List<String>?> members) {
    if (type == null || members.isEmpty || members.contains(null)) {
      return const [];
    }
    final object = Config().schema?.get(type);
    if (object is! SchemaInterface) return const [];
    final declared = object.fields.map((e) => e.name).toSet();
    return members.first!
        .where((field) => members.every((e) => e!.contains(field)))
        .where((field) => declared.contains(_fieldName(field)))
        .toList();
  }

  String _fieldName(String selection) =>
      RegExp(r'^\w+').firstMatch(selection)?.group(0) ?? selection;

  /// Spread of the fragment [name] plus the recursive fields left out of it.
  String _spread(
    String name,
    String type,
    Set<String> keys,
    String Function(_Scope scope) build,
    _Scope scope,
  ) {
    if (!_building.add(name)) {
      throw GrapherError('Fragment $name references itself');
    }
    final fragmentScope = _Scope.fragment(keys);
    final body = build(fragmentScope);
    _building.remove(name);

    final buffer = Buffer();
    buffer.writeln('fragment $name on $type {');
    buffer.block((b) => b.writeln(body.split('\n')));
    buffer.write('}');
    final fragment = _Fragment(buffer.toString(), fragmentScope.deferred!);

    final existing = _fragments[name];
    if (existing == null) {
      _fragments[name] = fragment;
    } else if (existing.definition != fragment.definition) {
      throw GrapherError('Fragment $name has different selections');
    }

    final result = Buffer();
    result.writeln('...$name');
    for (final deferred in fragment.deferred) {
      // Inside another fragment the field is deferred again, so its wrappers
      // must stay in the scope.
      final field = _field(
        deferred.field,
        deferred.mapped,
        deferred.wrappers.fold(scope, (scope, e) => scope.wrap(e)),
        isRecursive: true,
      );
      if (field != null) {
        result.writeln(_wrapIn(deferred.wrappers, field).split('\n'));
      }
    }
    return result.toString();
  }

  String _wrapIn(List<String> wrappers, String selection) {
    if (wrappers.isEmpty) return selection;
    final buffer = Buffer();
    buffer.writeln('${wrappers.first} {');
    buffer.block(
      (b) => b.writeln(_wrapIn(wrappers.sublist(1), selection).split('\n')),
    );
    buffer.write('}');
    return buffer.toString();
  }

  /// Keys of the classes the field selects.
  Iterable<String> _targets(ConstructorField param, GenericMapped? mapped) {
    final union = param.union;
    if (union != null) {
      return union.values.expand(
        (e) => _classKeys(Definition.parse(param, e), mapped),
      );
    }
    return _classKeys(param.def, mapped);
  }

  Iterable<String> _classKeys(Definition def, GenericMapped? parentMapped) {
    final mapped = def.mergeGenerics(parentMapped);
    switch (def.type) {
      case ClassEntityType e:
        return [_key(e, mapped)];
      case ListType e:
        return _classKeys(e.item, mapped);
      case GenericType e:
        final mappedDef = mapped?[e.dartName];
        return mappedDef == null ? const [] : _classKeys(mappedDef, mapped);
      default:
        return const [];
    }
  }

  /// Identifies a class with its generic arguments: `Page<A>` inside
  /// `Page<B>` is not a recursion.
  String _key(ClassEntityType e, GenericMapped? mapped) {
    final base = e.library ?? e.dartName;
    if (e.generic.isEmpty) return base;
    final args = e.generic.map((g) => mapped?[g.name]?.dartNameFull ?? g.name);
    return '$base<${args.join(', ')}>';
  }
}

class _Scope {
  /// Classes being expanded, outermost first.
  final List<String> path;

  /// How many times each recursive field is already expanded, by location.
  final Map<String, int> depth;

  /// Set while a fragment is built: recursive fields are collected here
  /// instead of being selected.
  final List<_Deferred>? deferred;

  /// Selections from the fragment root to the current one.
  final List<String> wrappers;

  const _Scope._(this.path, this.depth, this.deferred, this.wrappers);

  _Scope.operation() : this._(const [], const {}, null, const []);

  /// The fragment root stands for [keys]: a field leading back to any of them
  /// is recursive.
  _Scope.fragment(Set<String> keys) : this._([...keys], const {}, [], const []);

  int depthOf(ConstructorField field) => depth[field.location] ?? 0;

  _Scope enter(String key) =>
      _Scope._([...path, key], depth, deferred, wrappers);

  _Scope deepen(ConstructorField field) => _Scope._(
    path,
    {...depth, field.location: depthOf(field) + 1},
    deferred,
    wrappers,
  );

  _Scope wrap(String selection) =>
      _Scope._(path, depth, deferred, [...wrappers, selection]);
}

class _Deferred {
  final List<String> wrappers;
  final ConstructorField field;
  final GenericMapped? mapped;

  const _Deferred(this.wrappers, this.field, this.mapped);
}

class _Fragment {
  final String definition;
  final List<_Deferred> deferred;

  const _Fragment(this.definition, this.deferred);
}
