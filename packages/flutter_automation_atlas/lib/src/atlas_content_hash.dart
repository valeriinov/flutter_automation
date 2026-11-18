import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';

/// {@category Utils}
///
/// The short hash the catalogue addresses content by: the first twelve hex
/// digits of its SHA-1.
abstract final class AtlasContentHash {
  static const _length = 12;

  /// Hashes the [bytes] of a file.
  static String hashBytes(List<int> bytes) {
    return sha1.convert(bytes).toString().substring(0, _length);
  }

  /// Hashes the file at [path], `null` when there is no file.
  static String? tryHashFile(String path) {
    final file = File(path);

    if (!file.existsSync()) {
      return null;
    }

    return hashBytes(file.readAsBytesSync());
  }

  /// Hashes the canonical encoding of [json].
  static String hashJson(Object? json) {
    return hashBytes(utf8.encode(encodeCanonicalJson(json)));
  }

  /// Encodes [json] with the keys of every object sorted, so equal values
  /// encode equal whatever order their keys were written in.
  static String encodeCanonicalJson(Object? json) {
    return jsonEncode(_sortKeys(json));
  }
}

Object? _sortKeys(Object? json) {
  if (json is Map<String, Object?>) {
    final keys = json.keys.toList()..sort();

    return {for (final key in keys) key: _sortKeys(json[key])};
  }

  if (json is List<Object?>) {
    return json.map(_sortKeys).toList();
  }

  return json;
}
