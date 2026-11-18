import 'dart:convert';

import 'package:flutter_automation_atlas/src/atlas_exception.dart';

/// {@category Utils}
///
/// Typed reads out of decoded JSON, failing with an [AtlasException] that
/// names the key instead of a type error.
abstract final class AtlasJson {
  /// Returns [json] as an object, or fails naming the [subject].
  static Map<String, Object?> readObject(Object? json, String subject) {
    if (json is Map<String, Object?>) {
      return json;
    }

    throw AtlasException('$subject is not a JSON object.');
  }

  /// Decodes [text] into an object, or fails naming the [subject].
  static Map<String, Object?> decodeObject(String text, String subject) {
    try {
      return readObject(jsonDecode(text), subject);
    } on FormatException catch (error) {
      throw AtlasException('$subject is not JSON: ${error.message}');
    }
  }

  /// Returns the object under [key], `null` when it is absent or not one.
  static Map<String, Object?>? tryReadObject(
    Map<String, Object?> json,
    String key,
  ) {
    final value = json[key];

    return value is Map<String, Object?> ? value : null;
  }

  /// Returns the string under [key], or fails when it is not one.
  static String readString(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value is String) {
      return value;
    }

    throw AtlasException('"$key" is not a string in $json.');
  }

  /// Returns the string under [key], `null` when it is absent or not one.
  static String? tryReadString(Map<String, Object?> json, String key) {
    final value = json[key];

    return value is String ? value : null;
  }

  /// Returns the list under [key], empty when it is absent.
  static List<Object?> readList(Map<String, Object?> json, String key) {
    final value = json[key];

    if (value == null) {
      return const [];
    }

    if (value is List<Object?>) {
      return value;
    }

    throw AtlasException('"$key" is not a list in $json.');
  }

  /// Returns the objects of the list under [key], empty when it is absent.
  static List<Map<String, Object?>> readObjects(
    Map<String, Object?> json,
    String key,
  ) {
    return readList(
      json,
      key,
    ).map((item) => readObject(item, 'An item of "$key"')).toList();
  }
}
