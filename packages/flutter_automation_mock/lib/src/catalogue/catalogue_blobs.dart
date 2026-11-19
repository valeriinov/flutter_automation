import 'package:collection/collection.dart';

/// {@category Utils}
///
/// Stores every long string a JSON object repeats once.
///
/// [extract] moves each string of at least [minLength] characters that stands
/// more than once in the object into `blobs`, in the order it first stands.
/// Each place it stood holds `{"$blob": <index>}`. [resolve] puts the strings
/// back. The QA catalogue and the atlas page store their data this way.
abstract final class CatalogueBlobs {
  /// Fewest characters a repeated string takes to move to `blobs`.
  static const minLength = 1024;

  /// Key of the object that stands for a string in `blobs`.
  static const referenceKey = r'$blob';

  /// Key of the list of the repeated long strings.
  static const blobsKey = 'blobs';

  /// [data] with every repeated long string referenced from `blobs`, or
  /// [data] itself when it repeats none.
  static Map<String, Object?> extract(Map<String, Object?> data) {
    final blobs = _readLongStrings(data)
        .groupFoldBy<String, int>(
          (text) => text,
          (count, _) => (count ?? 0) + 1,
        )
        .entries
        .where((entry) => entry.value > 1)
        .map((entry) => entry.key)
        .toList();

    if (blobs.isEmpty) {
      return data;
    }

    final indexes = {for (final (index, blob) in blobs.indexed) blob: index};

    return {
      for (final MapEntry(:key, :value) in data.entries)
        key: _referenceBlobs(value, indexes),
      blobsKey: blobs,
    };
  }

  /// [data] as [extract] found it: every reference replaced by its string and
  /// `blobs` left out; [data] itself when it holds no `blobs` list.
  static Map<String, Object?> resolve(Map<String, Object?> data) {
    final blobs = data[blobsKey];

    if (blobs is! List<Object?>) {
      return data;
    }

    return {
      for (final MapEntry(:key, :value) in data.entries)
        if (key != blobsKey) key: _resolveBlobs(value, blobs),
    };
  }

  static Iterable<String> _readLongStrings(Object? node) {
    return switch (node) {
      String() when node.length >= minLength => [node],
      Map<String, Object?>() => node.values.expand(_readLongStrings),
      List<Object?>() => node.expand(_readLongStrings),
      _ => const [],
    };
  }

  static Object? _referenceBlobs(Object? node, Map<String, int> indexes) {
    return switch (node) {
      String() when indexes.containsKey(node) => {referenceKey: indexes[node]},
      Map<String, Object?>() => node.map(
        (key, value) => MapEntry(key, _referenceBlobs(value, indexes)),
      ),
      List<Object?>() =>
        node.map((value) => _referenceBlobs(value, indexes)).toList(),
      _ => node,
    };
  }

  static Object? _resolveBlobs(Object? node, List<Object?> blobs) {
    return switch (node) {
      Map<String, Object?>() when _isBlob(node) =>
        blobs[node[referenceKey] as int],
      Map<String, Object?>() => node.map(
        (key, value) => MapEntry(key, _resolveBlobs(value, blobs)),
      ),
      List<Object?>() =>
        node.map((value) => _resolveBlobs(value, blobs)).toList(),
      _ => node,
    };
  }

  static bool _isBlob(Map<String, Object?> node) {
    return node.length == 1 && node[referenceKey] is int;
  }
}
