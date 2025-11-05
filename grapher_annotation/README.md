# Grapher

Grapher is a helper for generating client-side GraphQL from models written in Dart!

Support all base features:
- Type, Input, Enum
- Query, Mutation, Subscription
- Union
- Subquery (query on field)

Not implemented, but plan:
- Fragments generation (for reduce query complexity)
- Multiple queries in one

# Usage

See [example](https://github.com/iadept/grapher/tree/main/example) project

Annotation have **name** param, by default use dart name of object, which used for schema validation

## Types

Define class with unnamed or _ constructor, all fields in this constructor used in code generation

Below are examples of the Dart model for the GraphQL entity example.

### Object

```dart
@GrapherObject(name: 'Item')
class Item {
  final ID id;
  final DateTime createdAt;
  final String name;
  final String? description;
  final int count;
  final ItemStatus? status; // Enumeration values ​​are optional to ensure greater compatibility.

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

```graphql
type Item {
    id: ID!
    createdAt: Timestamp!
    name: String!
    description: String
    count: Int!
    price: Double!
    status: ItemStatus!
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

```graphql
input SelectItemInput {
    id: ID
}
```

For greater compatibility, you can replace enum values with a string.

### Fields

All fields maybe annotated for change behavior

```dart
@GrapherObject(name: 'Item')
class Item {
  @GrapherField(name: 'code')
  final ID id;

  const Item(
    this.id,
  );
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

```graphql
enum Status {
    new,
    closed
}
```

## Actions

The library uses wrappers that you must use **result** for further use

Use in

- static function in object or input
```dart
@GrapherObject()
class Item {
  // ...

  @GrapherQuery(name: 'items')
  static Query<List<Item>> query(SelectItemInput input) => _itemQuery(input);
}
```

```graphql
extend type Query {
    items(input: SelectItemInput!): [Item!]!
}
```
- top level function
```dart
@GrapherQuery(name: 'items')
Query<List<Item>> query(SelectItemInput input) => _query(input);
```
- getter in input
```dart
@GrapherObject()
class UpdateItemInput {
  // ...

  @GrapherMutation(name: 'updateItem')
  Mutation<Item> get mutation => _updateItemInputMutation(this);
}
```

### Query 

### Mutation 

### Subscription

## Options

### Resolvers

For custom types use resolvers and create custom annotation

Custom resolver maybe **const** class!

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

// To avoid import issues, define the resolver class or instance in the same file as the new annotations.
const timestampResolver = TimestampResolver();

// Example for GrapherObject
class ProjectObject extends GrapherObject {
  const ProjectObject({super.name})
    : super(resolvers: const [timestampResolver]);
}

// And use @ProjectObject(name:)
```
