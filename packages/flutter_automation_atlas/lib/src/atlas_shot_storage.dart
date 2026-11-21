import 'package:flutter_automation_atlas/src/atlas_shot.dart';

/// {@category Utils}
///
/// The remote storage that keeps the screenshots of the atlas, each named by
/// its `AtlasShotId`.
///
/// The atlas does not know where the files live. A project implements this
/// interface for its own storage. The atlas itself reads a screenshot and
/// asks whether the storage holds it with a public `GET` of the link that
/// [urlTemplate] gives.
abstract interface class AtlasShotStorage {
  /// The text that [urlTemplate] holds in place of the screenshot identifier.
  static const shotPlaceholder = '{shot}';

  /// The public link of a screenshot, with [shotPlaceholder] in place of its
  /// identifier.
  String get urlTemplate;

  /// Puts [shots] into the storage. It skips each shot that the storage holds
  /// already.
  ///
  /// Throws when the storage does not take a shot. The command stops with
  /// the message.
  Future<void> upload(List<AtlasShot> shots);

  /// Removes the screenshots that the [shots] identifiers name from the
  /// storage.
  ///
  /// Throws when the storage does not remove a shot. The command stops with
  /// the message.
  Future<void> delete(List<String> shots);
}
