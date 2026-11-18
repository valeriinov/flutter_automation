import 'dart:typed_data';

/// {@category Utils}
///
/// One screenshot a page shows, named by its content hash.
final class AtlasShot {
  /// The content hash that names the screenshot in a snapshot.
  final String hash;

  /// The bytes of the image file.
  final Uint8List bytes;

  /// The media type of the image, such as `image/png`.
  final String type;

  const AtlasShot({
    required this.hash,
    required this.bytes,
    required this.type,
  });
}
