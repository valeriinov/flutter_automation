import 'package:flutter_automation_atlas/src/atlas_shot.dart';

/// {@category Utils}
///
/// Puts the screenshots of a page where a browser reads them and answers with
/// their links.
///
/// The atlas does not know where the files live. A project implements this
/// interface for its own storage.
abstract interface class AtlasShotPublisher {
  /// Publishes [shots] and returns the link of each, by [AtlasShot.hash].
  ///
  /// Throws when a shot cannot be published; the command that asked stops
  /// with the message.
  Future<Map<String, Uri>> publish(List<AtlasShot> shots);
}
