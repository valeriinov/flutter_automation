import 'dart:typed_data';

/// {@category Utils}
///
/// One screenshot of the atlas, named by its `AtlasShotId`.
final class AtlasShot {
  /// The identifier that names the screenshot in a snapshot.
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
