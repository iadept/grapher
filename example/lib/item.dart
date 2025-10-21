import 'package:collection/collection.dart';
import 'package:example/utils.dart';
import 'package:grapher_annotation/grapher_annotation.dart';

part 'item.g.dart';

@ProjectObject(name: 'Item')
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

  @GrapherQuery(name: 'items')
  static Query<List<Item>> query(SelectItemInput input) => _itemQuery(input);
}

@GrapherEnum(name: 'ItemStatus')
enum ItemStatus { draft, public }

@GrapherInput()
class SelectItemInput {
  final ID? id;

  const SelectItemInput({this.id});

  factory SelectItemInput.byId(ID id) => SelectItemInput(id: id);
}

@GrapherInput()
class UpdateItemInput {
  final ID id;

  @GrapherMutation(name: 'updateItem')
  Mutation<Item> get mutation => _updateItemInputMutation(this);

  const UpdateItemInput({required this.id});
}
