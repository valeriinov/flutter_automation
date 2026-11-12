import 'package:dio/dio.dart';

import 'package:example/catalog/catalog_item.dart';

/// Reads the catalog from the backend.
final class CatalogApi {
  final Dio _dio;

  const CatalogApi(this._dio);

  /// Items of the catalog.
  Future<List<CatalogItem>> getItems() async {
    final response = await _dio.get<Map<String, Object?>>('/catalog/items');

    final items = response.data?['items'];

    if (items is! List<Object?>) {
      return const [];
    }

    return [
      for (final item in items)
        if (item is Map<String, Object?>) ?_tryReadItem(item),
    ];
  }

  CatalogItem? _tryReadItem(Map<String, Object?> json) {
    final id = json['id'];

    if (id is! int) {
      return null;
    }

    return CatalogItem(id: id, title: '${json['title']}');
  }
}
