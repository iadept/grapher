import 'package:grapher_annotation/grapher_annotation.dart';

@GrapherResolver(name: 'Timestamp')
class TimestampResolver with GrapherResolverMixin<DateTime> {
  const TimestampResolver();

  @override
  DateTime fromMap(dynamic json) => DateTime.parse(json as String);

  @override
  dynamic toMap(DateTime value) {
    return value.toUtc().toIso8601String();
  }
}

/// Use const instance to avoid recreating the resolver multiple times.
const timestampResolver = TimestampResolver();

class ProjectObject extends GrapherObject {
  const ProjectObject({super.name, super.createToMap = false})
    : super(resolvers: const [timestampResolver]);
}
