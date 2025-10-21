import 'dart:convert';

import 'package:grapher_annotation/src/template.dart';

mixin GrapherCacheStoreMixin {
  Future<Map<String, dynamic>?> get(Query query);

  Future<void> put(Query query, Map<String, dynamic> data);

  Future<void> remove();
}

class GrapherInMemoryCacheStore with GrapherCacheStoreMixin {
  Map<String, dynamic>? _data;

  GrapherInMemoryCacheStore();

  @override
  Future<Map<String, dynamic>?> get(Query query) async => _data;

  @override
  Future<void> put(Query query, Map<String, dynamic> data) async {
    _data = data;
  }

  @override
  Future<void> remove() async {
    _data = null;
  }
}

extension QueryExtension on Query {
  String get cacheKey => base64Url.encode(utf8.encode(name));
}

class GrapherCache<T> {
  final Query query;
  final GrapherCacheStoreMixin store;

  GrapherCache({required this.query, required this.store});

  static GrapherCache<T>? from<T>(
    Query<T> query,
    GrapherCacheStoreMixin store,
  ) {
    if (query.cacheTTL != null) {
      return GrapherCache(query: query, store: store);
    }
    return null;
  }

  Future<T?> get value async {
    final data = await store.get(query);
    if (data != null) {
      return query.parserFn(data[query.name]);
    }
    return null;
  }

  Future<void> update(Map<String, dynamic>? data) async {
    if (data != null) {
      await store.put(query, data);
    } else {
      await store.remove();
    }
  }
}
