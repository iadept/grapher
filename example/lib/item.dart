import 'package:example/utils.dart';
import 'package:grapher_annotation/grapher_annotation.dart';

part 'item.g.dart';

@ProjectObject(name: 'Item')
class ItemHeader {
  final ID id;
  final String name;

  const ItemHeader(this.id, this.name);

  @GrapherQuery(name: 'items')
  static Query<List<ItemHeader>> query(SelectItemInput input) =>
      _itemHeaderQuery(input);
}

@ProjectObject(createToMap: true)
class ItemView extends ItemHeader {
  final DateTime createdAt;

  final String? description;
  final int count;
  @GrapherField(defaultValue: false)
  final bool? sale;
  @GrapherField(defaultValue: ItemStatus.draft)
  final ItemStatus? status;

  const ItemView(
    super.id,
    this.createdAt,
    super.name,
    this.description,
    this.count,
    this.status,
    this.sale,
  );

  @GrapherQuery(name: 'items')
  static Query<List<ItemView>> query(SelectItemInput input) =>
      _itemViewQuery(input);

  // You can use generated methods as JsonSerializable like
  factory ItemView.fromJson(dynamic json) => itemViewFromMap(json);

  // Created by createToMap param
  Map<String, dynamic> toJson() => itemViewToMap(this);
}

@GrapherEnum(name: 'ItemStatus')
enum ItemStatus { draft, public, promo }

@GrapherInput()
class SelectItemInput {
  final ID? id;

  const SelectItemInput({this.id});

  factory SelectItemInput.byId(ID id) => SelectItemInput(id: id);
}

@GrapherInput(name: 'UpdateItemInput')
class UpdateItemInput {
  final ID id;
  final String? status;

  @GrapherMutation(name: 'updateItem')
  Mutation<ItemView> get mutation => _updateItemInputMutation(this);

  const UpdateItemInput({required this.id, this.status});
}

@ProjectObject(name: 'Brand')
class Brand {
  final ID id;
  final String name;

  @GrapherField(input: 'inputPopularity')
  final bool popular;

  const Brand(this.id, this.name, this.popular);

  @GrapherQuery(name: 'brands')
  static Query<List<Brand>> query(
    SelectBrandsInput input,
    // Additional input for popularity filter
    SelectPopularityInRegionInput popularityInput,
  ) => _brandQuery(input, popularityInput);
}

@GrapherInput()
class SelectBrandsInput {
  final List<ID>? ids;

  const SelectBrandsInput({this.ids});

  factory SelectBrandsInput.byIds(List<ID> ids) => SelectBrandsInput(ids: ids);
}

@GrapherInput()
class SelectPopularityInRegionInput {
  final ID countryCode;

  const SelectPopularityInRegionInput({required this.countryCode});
}

// Union and Interface Example

@ProjectObject(name: 'ItemDetails')
class ItemDetails {
  @GrapherField(
    union: {
      'WashingMachineDetails': WashingMachineDetails,
      'RefrigeratorDetails': RefrigeratorDetails,
      'OvenDetails': OvenDetails,
    },
  )
  final Object? details;

  const ItemDetails({this.details});
}

// union Details = WashingMachineDetails | RefrigeratorDetails | OvenDetails

@ProjectObject(name: 'WashingMachineDetails')
class WashingMachineDetails {
  final int loadCapacity;
  final int spinSpeed;

  const WashingMachineDetails({
    required this.loadCapacity,
    required this.spinSpeed,
  });
}

@ProjectObject(name: 'RefrigeratorDetails')
class RefrigeratorDetails {
  final int volume;
  final bool hasFreezer;

  const RefrigeratorDetails({required this.volume, required this.hasFreezer});
}

@ProjectObject(name: 'OvenDetails')
class OvenDetails {
  final int power;
  final bool hasConvection;

  const OvenDetails({required this.power, required this.hasConvection});
}
