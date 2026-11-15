/// Reads of the catalogue JSON that tolerate a missing or malformed part.
abstract final class CatalogueJson {
  /// [value] when it is an object, an empty object otherwise.
  static Map<String, Object?> asObject(Object? value) {
    return value is Map<String, Object?> ? value : const {};
  }

  /// [value] when it is a list, an empty list otherwise.
  static List<Object?> asList(Object? value) {
    return value is List<Object?> ? value : const [];
  }

  /// The string under [key], `null` when it is missing or not a string.
  static String? tryString(Map<String, Object?> json, String key) {
    final value = json[key];

    return value is String ? value : null;
  }

  /// The object under [key], `null` when it is missing or not an object.
  static Map<String, Object?>? tryObject(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];

    return value is Map<String, Object?> ? value : null;
  }

  /// The text per locale under [key], `null` when it is missing.
  static Map<String, String>? tryText(Map<String, Object?> json, String key) {
    final value = tryObject(json, key);

    if (value == null) {
      return null;
    }

    return {
      for (final MapEntry(:key, :value) in value.entries)
        if (value is String) key: value,
    };
  }

  /// The objects of the list under [key], empty when it is missing.
  static List<Map<String, Object?>> objects(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];

    if (value is! List<Object?>) {
      return const [];
    }

    return value.whereType<Map<String, Object?>>().toList(growable: false);
  }
}
