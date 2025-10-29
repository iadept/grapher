import 'package:graphql/client.dart';

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
  /// You can use it in GrapherCache
  final Duration? cacheTTL;

  QueryOptions<T> result({FetchPolicy? fetchPolicy, Context? context}) =>
      QueryOptions<T>(
        document: gql(body),
        operationName: name.substring(0, 1).toUpperCase() + name.substring(1),
        variables: variables ?? {},
        parserFn: (data) => parserFn(data[name]),
        fetchPolicy: fetchPolicy,
        context: context,
      );

  const Query({
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

  MutationOptions<T> result({FetchPolicy? fetchPolicy, Context? context}) =>
      MutationOptions<T>(
        document: gql(body),
        operationName: name.substring(0, 1).toUpperCase() + name.substring(1),
        variables: variables,
        parserFn: (data) => parserFn(data[name]),
        fetchPolicy: fetchPolicy,
        context: context,
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

  SubscriptionOptions<T> result({FetchPolicy? fetchPolicy, Context? context}) =>
      SubscriptionOptions<T>(
        document: gql(body),
        parserFn: (data) => parserFn(data[name]),
        fetchPolicy: fetchPolicy,
        context: context,
      );

  const Subscription({
    required this.name,
    required this.body,
    required this.parserFn,
  });
}
