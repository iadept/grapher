import 'package:gql/ast.dart';
import 'package:graphql/client.dart' as gql;

/// GraphQL Query data class
class Query<T> {
  /// The name of the query
  final String name;

  /// The variables for the query
  final Map<String, dynamic>? variables;

  /// The body of the query
  final String body;

  /// The parser function to parse the query result
  final T Function(dynamic body) parserFn;

  /// Optional cache time-to-live duration
  final Duration? cacheTTL;

  DocumentNode get _node => gql.gql(body);

  gql.QueryOptions<T> get result => gql.QueryOptions<T>(
    document: _node,
    operationName: name.substring(0, 1).toUpperCase() + name.substring(1),
    variables: variables ?? {},
    parserFn: (data) => parserFn(data[name]),
    fetchPolicy: gql.FetchPolicy.noCache,
  );

  Query({
    required this.name,
    required this.variables,
    required this.body,
    required this.parserFn,
    this.cacheTTL,
  });
}

/// GraphQL Mutation data class
class Mutation<T> {
  /// The name of the mutation
  final String name;

  /// The variables for the mutation
  final Map<String, dynamic> variables;

  /// The body of the mutation
  final String body;

  /// The parser function to parse the mutation result
  final T Function(dynamic body) parserFn;

  DocumentNode get _node => gql.gql(body);

  gql.MutationOptions<T> get result => gql.MutationOptions<T>(
    document: _node,
    operationName: name.substring(0, 1).toUpperCase() + name.substring(1),
    variables: variables,
    parserFn: (data) => parserFn(data[name]),
    fetchPolicy: gql.FetchPolicy.noCache,
  );

  const Mutation({
    required this.name,
    required this.variables,
    required this.body,
    required this.parserFn,
  });
}

/// GraphQL Subscription data class
class Subscription<T> {
  /// The name of the subscription
  final String name;

  /// The body of the subscription
  final String body;

  /// The parser function to parse the subscription result
  final T Function(dynamic body) parserFn;

  DocumentNode get _node => gql.gql(body);

  gql.SubscriptionOptions<T> get result => gql.SubscriptionOptions<T>(
    document: _node,
    parserFn: (data) => parserFn(data[name]),
    fetchPolicy: gql.FetchPolicy.noCache,
  );

  const Subscription({
    required this.name,
    required this.body,
    required this.parserFn,
  });
}
