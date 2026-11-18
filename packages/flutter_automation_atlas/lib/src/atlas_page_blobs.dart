import 'package:collection/collection.dart';

/// {@category Utils}
///
/// Stores every long string the page data repeats once.
///
/// The journals of many stages carry the same payload — the base64 image a
/// response holds — so a string of at least [minLength] characters standing
/// more than once in the data moves to `blobs`, in the order it first stands,
/// and each place it stood holds `{"$blob": <index>}` instead. The page puts
/// the strings back as it reads its data, before it renders anything.
abstract final class AtlasPageBlobs {
  /// Fewest characters a repeated string takes to move to `blobs`.
  static const minLength = 1024;

  /// The key of the object standing for a string in `blobs`.
  static const referenceKey = r'$blob';

  /// The key of the page data holding the strings.
  static const blobsKey = 'blobs';

  /// The [data] with every repeated long string referenced from `blobs`, or
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

  static Iterable<String> _readLongStrings(Object? node) {
    return switch (node) {
      String() when node.length >= minLength => [node],
      Map<String, Object?>() => node.values.expand(_readLongStrings),
      List<Object?>() => node.expand(_readLongStrings),
      _ => const [],
    };
  }
}

Object? _referenceBlobs(Object? node, Map<String, int> indexes) {
  return switch (node) {
    String() when indexes.containsKey(node) => {
      AtlasPageBlobs.referenceKey: indexes[node],
    },
    Map<String, Object?>() => node.map(
      (key, value) => MapEntry(key, _referenceBlobs(value, indexes)),
    ),
    List<Object?>() =>
      node.map((value) => _referenceBlobs(value, indexes)).toList(),
    _ => node,
  };
}
