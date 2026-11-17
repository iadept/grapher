import 'package:example/item.dart';

void check(bool cond, String label) {
  if (!cond) {
    throw StateError('FAILED: $label');
  }
  print('ok: $label');
}

void main() {
  // 1. Full parse through the generated fromMap (DateTime resolver + enum + nested defaults).
  final view = ItemView.fromJson({
    'id': '42',
    'createdAt': '2026-11-17T10:00:00.000Z',
    'name': 'Washer',
    'description': null,
    'count': 3,
    'status': 'public',
    'sale': true,
    'title': 'T',
  });
  check(view.id == '42', 'fromMap id');
  check(
    view.createdAt == DateTime.utc(2026, 11, 17, 10),
    'fromMap DateTime via resolver',
  );
  check(view.status == ItemStatus.public, 'fromMap enum');
  check(view.sale, 'fromMap bool');

  // 2. Default value when the key is absent.
  final viewNoSale = ItemView.fromJson({
    'id': '7',
    'createdAt': '2026-01-01T00:00:00.000Z',
    'name': 'Oven',
    'description': null,
    'count': 1,
    'status': null,
    'title': null,
  });
  check(!viewNoSale.sale, 'defaultValue applied');

  // 3. toJson: nulls stripped, enum mapped back to string.
  final back = view.toJson();
  check(back['sale'] == true, 'toMap keeps value');
  check(back['status'] == 'public', 'toMap enum string');
  check(!back.containsKey('description'), 'toMap strips null');
  check(back['title'] == 'T', 'toMap keeps title');

  // 4. Generated query: body, variables, and parser end-to-end.
  final q = ItemHeader.query(SelectItemInput.byId('1'));
  check(q.name == 'items', 'query name');
  check(q.body.contains('query Items'), 'query body');
  check(q.variables!['input']['id'] == '1', 'query input variables');
  final parsedHeaders = q.parserFn([
    {'id': 'a', 'name': 'n1'},
  ]);
  check(parsedHeaders.length == 1 && parsedHeaders[0].name == 'n1', 'query parse');

  // 5. Query with two inputs.
  final bq = Brand.query(
    SelectBrandsInput.byIds(['b1', 'b2']),
    SelectPopularityInRegionInput(countryCode: 'RU'),
  );
  check(bq.variables!['input']['ids'] is List, 'brand ids variable');
  check(
    bq.variables?['popularityInput']['countryCode'] == 'RU',
    'brand second input variable',
  );
  final page = bq.parserFn({
    'edges': [
      {'id': 'b1', 'name': 'Brand One', 'popular': true},
    ],
    'pageInfo': {'hasNextPage': true, 'startCursor': 's', 'endCursor': 'e'},
  });
  check(page.items.length == 1 && page.items[0].name == 'Brand One', 'page parse');
  check(page.pageInfo.hasNextPage, 'pageInfo parse');

  // 6. Union discrimination.
  final oven = itemDetailsFromMap({
    'details': {
      '__typename': 'OvenDetails',
      'power': 5,
      'hasConvection': false,
    },
  });
  check(oven.details is OvenDetails, 'union to OvenDetails');

  // 7. Mutation from input getter.
  final m = UpdateItemInput(id: '42', status: 'draft').mutation;
  check(m.name == 'updateItem', 'mutation name');
  check(m.body.contains('mutation UpdateItem'), 'mutation body');
  check(
    m.variables['input']['status'] == 'draft' &&
        m.variables['input']['id'] == '42',
    'mutation variables',
  );

  // 8. Enum maps.
  check(itemStatusFromMap('promo') == ItemStatus.promo, 'enum fromMap');
  check(itemStatusToMap(ItemStatus.draft) == 'draft', 'enum toMap');
  check(itemStatusFromMap('nope') == null, 'enum unknown -> null');

  print('SMOKE OK');
}
