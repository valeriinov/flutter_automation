import 'package:dio/dio.dart';

/// Reads the catalog from the backend.
final class CatalogApi {
  final Dio _dio;

  const CatalogApi(this._dio);

  /// Titles of the catalog items.
  Future<List<String>> getItemTitles() async {
    final response = await _dio.get<Map<String, Object?>>('/catalog/items');

    final items = response.data?['items'];

    if (items is! List<Object?>) {
      return const [];
    }

    return [
      for (final item in items)
        if (item is Map<String, Object?>) '${item['title']}',
    ];
  }
}
