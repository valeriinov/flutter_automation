import 'dart:convert';

import 'package:collection/collection.dart';

import 'package:flutter_automation_mock/src/catalogue/automation_catalogue_step.dart';

/// {@category Utils}
///
/// Stores the repeated parts of the catalogue JSON once.
///
/// [pack] moves the response of each request into `responses`. The key is a
/// hash of the JSON of the response with its keys sorted. The request keeps the
/// key. [pack] then moves each string of at least [minBlobLength] characters
/// that stands more than once into `blobs`, in the order it first stands. Each
/// place it stood holds `{"$blob": <index>}`. [unpack] puts everything back.
abstract final class AutomationCatalogueTables {
  /// Fewest characters a repeated string takes to move to `blobs`.
  static const minBlobLength = 1024;

  /// Key of the object that stands for a string in `blobs`.
  static const blobReferenceKey = r'$blob';

  /// Key of the table that maps a response hash to the response.
  static const responsesKey = 'responses';

  /// Key of the list of the repeated long strings.
  static const blobsKey = 'blobs';

  static const _flowsKey = 'flows';
  static const _variantsKey = 'variants';
  static const _stepsKey = 'steps';
  static const _fnvOffset = -3750763034362895579;
  static const _fnvPrime = 0x100000001b3;

  /// [json] with its responses and repeated long strings stored once.
  static Map<String, Object?> pack(Map<String, Object?> json) {
    final responses = <String, Object?>{};
    final withHashes = _mapRequests(
      json,
      (request) => _moveResponse(request, responses),
    );

    return _moveBlobs({
      ...withHashes,
      if (responses.isNotEmpty) responsesKey: responses,
    });
  }

  /// [json] as [pack] found it: the blobs and the responses put back.
  static Map<String, Object?> unpack(Map<String, Object?> json) {
    final blobs = json[blobsKey];
    final resolved = blobs is List<Object?>
        ? {
            for (final MapEntry(:key, :value) in json.entries)
              if (key != blobsKey) key: _resolveBlobs(value, blobs),
          }
        : json;
    final responses = resolved[responsesKey];

    if (responses is! Map<String, Object?>) {
      return resolved;
    }

    return _mapRequests(
      resolved,
      (request) => _restoreResponse(request, responses),
    );
  }

  static Map<String, Object?> _moveResponse(
    Map<String, Object?> request,
    Map<String, Object?> responses,
  ) {
    final response = request[AutomationCatalogueRequest.responseKey];

    if (response == null) {
      return request;
    }

    return {
      for (final MapEntry(:key, :value) in request.entries)
        if (key != AutomationCatalogueRequest.responseKey) key: value,
      AutomationCatalogueRequest.responseHashKey: store(responses, response),
    };
  }

  /// Puts [response] into [responses] and returns its key.
  ///
  /// The key is [hashResponse] of [response]. A different response that has the
  /// same hash gets the key with `-1`, `-2` and so on. [hashOf] replaces
  /// [hashResponse].
  static String store(
    Map<String, Object?> responses,
    Object response, {
    String Function(Object response) hashOf = hashResponse,
  }) {
    final hash = hashOf(response);

    for (int suffix = 0; ; suffix += 1) {
      final key = suffix == 0 ? hash : '$hash-$suffix';
      final known = responses[key];

      if (known == null) {
        responses[key] = response;

        return key;
      }

      if (const DeepCollectionEquality().equals(known, response)) {
        return key;
      }
    }
  }

  /// The hash of [response] as 16 lowercase hex digits.
  ///
  /// Two responses with the same content and another key order have the same
  /// hash.
  static String hashResponse(Object response) {
    int hash = _fnvOffset;

    for (final byte in utf8.encode(jsonEncode(_sortKeys(response)))) {
      hash = (hash ^ byte) * _fnvPrime;
    }

    return BigInt.from(hash).toUnsigned(64).toRadixString(16).padLeft(16, '0');
  }

  static Object? _sortKeys(Object? node) {
    return switch (node) {
      Map<String, Object?>() => {
        for (final key in node.keys.sorted((a, b) => a.compareTo(b)))
          key: _sortKeys(node[key]),
      },
      List<Object?>() => node.map(_sortKeys).toList(),
      _ => node,
    };
  }

  static Map<String, Object?> _restoreResponse(
    Map<String, Object?> request,
    Map<String, Object?> responses,
  ) {
    final hash = request[AutomationCatalogueRequest.responseHashKey];

    if (hash is! String) {
      return request;
    }

    return {
      for (final MapEntry(:key, :value) in request.entries)
        if (key != AutomationCatalogueRequest.responseHashKey) key: value,
      AutomationCatalogueRequest.responseKey: ?responses[hash],
    };
  }

  static Map<String, Object?> _mapRequests(
    Map<String, Object?> json,
    Map<String, Object?> Function(Map<String, Object?> request) map,
  ) {
    return _mapObjects(
      json,
      _flowsKey,
      (flow) => _mapObjects(
        flow,
        _variantsKey,
        (variant) => _mapObjects(
          variant,
          _stepsKey,
          (step) => _mapObjects(step, AutomationCatalogueStep.requestsKey, map),
        ),
      ),
    );
  }

  static Map<String, Object?> _mapObjects(
    Map<String, Object?> json,
    String key,
    Map<String, Object?> Function(Map<String, Object?> object) map,
  ) {
    final objects = json[key];

    if (objects is! List<Object?>) {
      return json;
    }

    return {
      ...json,
      key: [
        for (final object in objects)
          if (object is Map<String, Object?>) map(object) else object,
      ],
    };
  }

  static Map<String, Object?> _moveBlobs(Map<String, Object?> data) {
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
      String() when node.length >= minBlobLength => [node],
      Map<String, Object?>() => node.values.expand(_readLongStrings),
      List<Object?>() => node.expand(_readLongStrings),
      _ => const [],
    };
  }

  static Object? _referenceBlobs(Object? node, Map<String, int> indexes) {
    return switch (node) {
      String() when indexes.containsKey(node) => {
        blobReferenceKey: indexes[node],
      },
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
        blobs[node[blobReferenceKey] as int],
      Map<String, Object?>() => node.map(
        (key, value) => MapEntry(key, _resolveBlobs(value, blobs)),
      ),
      List<Object?>() =>
        node.map((value) => _resolveBlobs(value, blobs)).toList(),
      _ => node,
    };
  }

  static bool _isBlob(Map<String, Object?> node) {
    return node.length == 1 && node[blobReferenceKey] is int;
  }
}
