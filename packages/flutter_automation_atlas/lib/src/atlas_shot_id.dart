import 'package:crypto/crypto.dart';

/// {@category Utils}
///
/// The identifier of a screenshot: the SHA-256 of its bytes, 64 lowercase hex
/// digits. A snapshot, the shots folder and a remote storage name a
/// screenshot by it.
abstract final class AtlasShotId {
  static final _pattern = RegExp(r'^[0-9a-f]{64}$');

  /// The identifier of the screenshot that holds [bytes].
  static String hashBytes(List<int> bytes) {
    return sha256.convert(bytes).toString();
  }

  /// Whether [id] has the form of a screenshot identifier.
  static bool isValid(String id) => _pattern.hasMatch(id);
}
