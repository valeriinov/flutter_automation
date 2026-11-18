import 'dart:math';

import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';

/// {@category Utils}
///
/// Describes what a capture changed in the snapshot of its variant, one line
/// per change.
abstract final class AtlasSnapshotDiff {
  /// Lines naming what [next] changed against [previous].
  ///
  /// Stages are compared by position: a stage of another action at the same
  /// position reads as the old one removed and the new one added.
  static List<String> describe({
    required AtlasSnapshot? previous,
    required AtlasSnapshot next,
  }) {
    if (previous == null) {
      return ['new snapshot, ${next.stages.length} stages'];
    }

    final stageCount = max(previous.stages.length, next.stages.length);
    final lines = [
      if (previous.ok != next.ok) 'ok ${previous.ok} → ${next.ok}',
      if (previous.device != next.device)
        'device ${previous.device} → ${next.device}',
      if (previous.defHash != next.defHash) 'definition changed',
      ..._describeManifest(previous.manifest, next.manifest),
      for (int index = 0; index < stageCount; index += 1)
        ..._describeStage(
          previous.stages.elementAtOrNull(index),
          next.stages.elementAtOrNull(index),
        ),
      ..._describeEnd(previous.end, next.end),
    ];

    return lines.isEmpty ? const ['no changes'] : lines;
  }

  static List<String> _describeManifest(
    Map<String, String> previous,
    Map<String, String> next,
  ) {
    final added = next.keys.where((path) => !previous.containsKey(path));
    final removed = previous.keys.where((path) => !next.containsKey(path));
    final changed = next.keys.where(
      (path) => previous.containsKey(path) && previous[path] != next[path],
    );
    final counts = [
      if (added.isNotEmpty) '+${added.length}',
      if (removed.isNotEmpty) '-${removed.length}',
      if (changed.isNotEmpty) '~${changed.length}',
    ];

    return counts.isEmpty ? const [] : ['manifest ${counts.join(' ')}'];
  }

  static List<String> _describeStage(AtlasStage? previous, AtlasStage? next) {
    if (previous == null) {
      return [if (next != null) '+ ${next.label}'];
    }

    if (next == null) {
      return ['- ${previous.label}'];
    }

    if (!next.isSameAction(previous)) {
      return ['- ${previous.label}', '+ ${next.label}'];
    }

    final changes = [
      if (previous.shot != next.shot) 'shot',
      if (!next.hasSameJournal(previous)) 'journal',
      if (!next.hasSameTargetRect(previous)) 'targetRect',
      if (!next.hasSameScreen(previous)) 'screen',
      if (previous.ok != next.ok) 'ok',
    ];

    return changes.isEmpty
        ? const []
        : ['~ ${next.label}: ${changes.join(', ')}'];
  }

  static List<String> _describeEnd(AtlasEnd previous, AtlasEnd next) {
    final changes = [
      if (previous.shot != next.shot) 'shot',
      if (!next.hasSameScreen(previous)) 'screen',
      if (!next.hasSameTexts(previous)) 'texts',
    ];

    return changes.isEmpty ? const [] : ['~ end: ${changes.join(', ')}'];
  }
}
