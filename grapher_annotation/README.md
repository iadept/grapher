# Grapher

Grapher is helper for generate GraphQL from dart code!

# Usage

See example project

Annotation have **name** param, which used for schema validation, if it does not exist validation skipped

## Types

Define class with unnamed or _ constructor, all fields in this constructor used in code generation

### Object

```dart
@GrapherObject(name: 'Item')
class Item {
  final ID id;
  final DateTime createdAt;
  final String name;
  final String? description;
  final int count;

  final ItemStatus? status;

  const Item(
    this.id,
    this.createdAt,
    this.name,
    this.description,
    this.count,
    this.status,
  );
}
```

### Input

```dart
@GrapherInput(name: "SelectItemInput")
class SelectItemInput {
  final ID? id;

  const SelectItemInput({this.id});
}

```

### Enum

```dart
@GrapherEnum(name: "Status")
enum Status {
    @GrapherEnumValue(name: "new")
    open,
    closed,
}
```


## Actions

Use in

- static function
```dart
@GrapherQuery(name: 'items')
static Query<List<Item>> query(SelectItemInput input) => _itemQuery(input);
```
- getter if use parent class
```dart
@GrapherMutation(name: 'updateItem')
Mutation<Item> get mutation => _updateItemInputMutation(this);
```

### Query 

### Mutation 

### Subscription

## Options

### Resolvers

For custom types use resolvers and create custom annotation
```dart
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

const  timestampResolver = TimestampResolver();

class ProjectObject extends GrapherObject {
  const ProjectObject({super.name})
    : super(resolvers: const [timestampResolver]);
}
```
