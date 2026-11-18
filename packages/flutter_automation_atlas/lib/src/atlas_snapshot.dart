import 'package:collection/collection.dart';

import 'package:flutter_automation_atlas/src/atlas_json.dart';

/// {@category Utils}
///
/// What one capture of a flow variant recorded, as stored in
/// `<store>/data/<flow>/<variant>.<locale>.json`.
///
/// The snapshot holds no time, so capturing an unchanged variant again leaves
/// its file as it was.
final class AtlasSnapshot {
  /// Name of the flow.
  final String flow;

  /// Name of the variant.
  final String variant;

  /// The locale the app ran in.
  final String locale;

  /// Whether every step of the run passed.
  final bool ok;

  /// The simulator the run walked, as `<name> · iOS <version>`.
  final String device;

  /// Hash of the variant's resolved steps and merged mock when it was walked.
  final String defHash;

  /// Every app source file the run executed, mapped to its content hash.
  final Map<String, String> manifest;

  /// One stage per user action of the run.
  final List<AtlasStage> stages;

  /// The screen the run ended on.
  final AtlasEnd end;

  /// The renderer the headless walk that wrote the headless hashes of the
  /// stages and the end ran on, as `AtlasHeadless.readRenderer` names
  /// it; absent while no walk wrote them.
  final String? headlessRenderer;

  /// The commit of the code tree the capture ran on; absent in a snapshot
  /// captured before the commit was recorded or outside a git tree.
  final String? sourceCommit;

  /// Whether the code tree held changes outside the store when the capture
  /// started; absent together with [sourceCommit].
  final bool? sourceDirty;

  const AtlasSnapshot({
    required this.flow,
    required this.variant,
    required this.locale,
    required this.ok,
    required this.device,
    required this.defHash,
    required this.manifest,
    required this.stages,
    required this.end,
    this.headlessRenderer,
    this.sourceCommit,
    this.sourceDirty,
  });

  /// Reads a snapshot back out of its decoded file.
  ///
  /// The [fileLocale] parameter is the locale the file name carries, read
  /// when the file holds none.
  factory AtlasSnapshot.fromJson(Object? json, {required String fileLocale}) {
    final snapshot = AtlasJson.readObject(json, 'Snapshot');
    final manifest = AtlasJson.tryReadObject(snapshot, 'manifest') ?? {};

    return AtlasSnapshot(
      flow: AtlasJson.readString(snapshot, 'flow'),
      variant: AtlasJson.readString(snapshot, 'variant'),
      locale: AtlasJson.tryReadString(snapshot, 'locale') ?? fileLocale,
      ok: snapshot['ok'] == true,
      device: AtlasJson.readString(snapshot, 'device'),
      defHash: AtlasJson.readString(snapshot, 'defHash'),
      manifest: {
        for (final key in manifest.keys)
          key: AtlasJson.readString(manifest, key),
      },
      stages: AtlasJson.readObjects(
        snapshot,
        'stages',
      ).map(AtlasStage.fromJson).toList(),
      end: AtlasEnd.fromJson(snapshot['end']),
      headlessRenderer: AtlasJson.tryReadString(snapshot, 'headlessRenderer'),
      sourceCommit: AtlasJson.tryReadString(snapshot, 'sourceCommit'),
      sourceDirty: switch (snapshot['sourceDirty']) {
        final bool isDirty => isDirty,
        _ => null,
      },
    );
  }

  /// The run this snapshot holds, the way a report and a stale line name it.
  String get id => '$flow $variant';

  /// The snapshot as its file holds it, keys in the order of the contract.
  Map<String, Object?> toJson() {
    final paths = manifest.keys.toList()..sort();

    return {
      'flow': flow,
      'variant': variant,
      'locale': locale,
      'ok': ok,
      'device': device,
      'defHash': defHash,
      'manifest': {for (final path in paths) path: manifest[path]},
      'stages': stages.map((stage) => stage.toJson()).toList(),
      'end': end.toJson(),
      'headlessRenderer': ?headlessRenderer,
      'sourceCommit': ?sourceCommit,
      'sourceDirty': ?sourceDirty,
    };
  }

  /// The stage at [index] when it is the same action as [stage], `null`
  /// otherwise.
  AtlasStage? tryFindSameActionStage(int index, AtlasStage stage) {
    final candidate = stages.elementAtOrNull(index);

    if (candidate == null || !candidate.isSameAction(stage)) {
      return null;
    }

    return candidate;
  }

  /// The same snapshot holding [stages] and [end] instead.
  AtlasSnapshot copyWithStages({
    required List<AtlasStage> stages,
    required AtlasEnd end,
  }) {
    return AtlasSnapshot(
      flow: flow,
      variant: variant,
      locale: locale,
      ok: ok,
      device: device,
      defHash: defHash,
      manifest: manifest,
      stages: stages,
      end: end,
      headlessRenderer: headlessRenderer,
      sourceCommit: sourceCommit,
      sourceDirty: sourceDirty,
    );
  }

  /// The same snapshot recording that the capture ran on [commit], with the
  /// code tree changed outside the store when [isDirty] is set.
  AtlasSnapshot copyWithSource({
    required String commit,
    required bool isDirty,
  }) {
    return AtlasSnapshot(
      flow: flow,
      variant: variant,
      locale: locale,
      ok: ok,
      device: device,
      defHash: defHash,
      manifest: manifest,
      stages: stages,
      end: end,
      headlessRenderer: headlessRenderer,
      sourceCommit: commit,
      sourceDirty: isDirty,
    );
  }

  /// The same snapshot holding [stages], [end] and the headless [renderer]
  /// instead.
  AtlasSnapshot copyWithHeadlessWalk({
    required String renderer,
    required List<AtlasStage> stages,
    required AtlasEnd end,
  }) {
    return AtlasSnapshot(
      flow: flow,
      variant: variant,
      locale: locale,
      ok: ok,
      device: device,
      defHash: defHash,
      manifest: manifest,
      stages: stages,
      end: end,
      headlessRenderer: renderer,
      sourceCommit: sourceCommit,
      sourceDirty: sourceDirty,
    );
  }
}

/// {@category Utils}
///
/// One user action of a run and the steps after it up to the next one.
final class AtlasStage {
  static const _equality = DeepCollectionEquality();

  /// Label of the action step.
  final String label;

  /// Driver action of the action step: `tap`, `enterText` or `scroll`.
  final String action;

  /// Journal records the action and the steps after it produced.
  final List<Object?> journal;

  /// Whether every step of the stage passed.
  final bool ok;

  /// The manifest files the screen of the stage is built from, mapped to their
  /// content hash; empty when the stage logged no screen or the snapshot was
  /// captured before stages held it.
  final Map<String, String> sources;

  /// The texts the frame before the action showed, in tree order, then those
  /// read after the steps of the stage before that neither frame showed, such
  /// as a toast its action raised.
  final List<String> texts;

  /// The localization keys whose values render [texts], mapped to the hash of
  /// the value.
  final Map<String, String> localeKeys;

  /// The widget types the frame before the action showed, sorted; empty when
  /// the snapshot was captured before stages held them.
  final List<String> widgets;

  /// Finder of the action step as the flow file writes it, absent for an
  /// action addressing the focused element.
  final Map<String, Object?>? target;

  /// Block the action step comes from, absent for an inline step.
  final String? block;

  /// Bounds of the element the action step addressed, as `left`, `top`,
  /// `right` and `bottom` fractions of the screen, absent when the runner did
  /// not measure them.
  final Map<String, Object?>? targetRect;

  /// The `screen_name` logged before the action.
  final String? screen;

  /// The design screen name logged before the action.
  final String? designScreen;

  /// Content hash of the screenshot taken before the action.
  final String? shot;

  /// The first error of the stage's steps.
  final String? error;

  /// Hash of what a capture walks up to the end of the stage: the resolved
  /// steps before the next action and the merged mock, absent in a snapshot
  /// captured before stages held it.
  final String? stepHash;

  /// The anchor every date the mock served the stage is read off, as a UTC
  /// ISO 8601 moment, absent in a snapshot captured before stages held it.
  final String? anchor;

  /// The moment the app the stage was captured in launched, as a UTC ISO 8601
  /// moment, absent with [anchor].
  final String? launchedAt;

  /// Hash of the frame before the action the headless walk showed when the
  /// stage was written, absent while no walk wrote it.
  final String? headlessFrameHash;

  /// Hash of the journal the headless walk read for the stage when it was
  /// written, as `AtlasJournalComparison.hash` takes it, absent while no
  /// walk wrote it.
  final String? headlessJournalHash;

  const AtlasStage({
    required this.label,
    required this.action,
    required this.journal,
    required this.ok,
    required this.target,
    required this.block,
    required this.targetRect,
    required this.screen,
    required this.designScreen,
    required this.shot,
    required this.error,
    this.stepHash,
    this.anchor,
    this.launchedAt,
    this.headlessFrameHash,
    this.headlessJournalHash,
    this.sources = const {},
    this.texts = const [],
    this.localeKeys = const {},
    this.widgets = const [],
  });

  /// Reads a stage back out of a decoded snapshot.
  factory AtlasStage.fromJson(Map<String, Object?> json) {
    final sources = AtlasJson.tryReadObject(json, 'sources') ?? {};
    final localeKeys = AtlasJson.tryReadObject(json, 'localeKeys') ?? {};

    return AtlasStage(
      label: AtlasJson.readString(json, 'label'),
      action: AtlasJson.readString(json, 'action'),
      journal: AtlasJson.readList(json, 'journal'),
      ok: json['ok'] == true,
      target: AtlasJson.tryReadObject(json, 'target'),
      block: AtlasJson.tryReadString(json, 'block'),
      targetRect: AtlasJson.tryReadObject(json, 'targetRect'),
      screen: AtlasJson.tryReadString(json, 'screen'),
      designScreen: AtlasJson.tryReadString(json, 'designScreen'),
      shot: AtlasJson.tryReadString(json, 'shot'),
      error: AtlasJson.tryReadString(json, 'error'),
      stepHash: AtlasJson.tryReadString(json, 'stepHash'),
      anchor: AtlasJson.tryReadString(json, 'anchor'),
      launchedAt: AtlasJson.tryReadString(json, 'launchedAt'),
      headlessFrameHash: AtlasJson.tryReadString(json, 'headlessFrameHash'),
      headlessJournalHash: AtlasJson.tryReadString(json, 'headlessJournalHash'),
      sources: {
        for (final key in sources.keys) key: AtlasJson.readString(sources, key),
      },
      texts: AtlasJson.readList(json, 'texts').whereType<String>().toList(),
      localeKeys: {
        for (final key in localeKeys.keys)
          key: AtlasJson.readString(localeKeys, key),
      },
      widgets: AtlasJson.readList(json, 'widgets').whereType<String>().toList(),
    );
  }

  /// The stage as a snapshot file holds it, keys in the order of the contract.
  Map<String, Object?> toJson() {
    final paths = sources.keys.toList()..sort();
    final keys = localeKeys.keys.toList()..sort();

    return {
      'label': label,
      'action': action,
      'target': ?target,
      'block': ?block,
      'targetRect': ?targetRect,
      'screen': screen,
      'designScreen': designScreen,
      'shot': shot,
      'journal': journal,
      'ok': ok,
      'error': ?error,
      'stepHash': ?stepHash,
      'anchor': ?anchor,
      'launchedAt': ?launchedAt,
      'headlessFrameHash': ?headlessFrameHash,
      'headlessJournalHash': ?headlessJournalHash,
      if (paths.isNotEmpty)
        'sources': {for (final path in paths) path: sources[path]},
      if (texts.isNotEmpty) 'texts': texts,
      if (keys.isNotEmpty)
        'localeKeys': {for (final key in keys) key: localeKeys[key]},
      if (widgets.isNotEmpty) 'widgets': widgets,
    };
  }

  /// Whether [other] is the same action: equal label, action and target.
  bool isSameAction(AtlasStage other) {
    return label == other.label &&
        action == other.action &&
        _equality.equals(target, other.target);
  }

  /// Whether [other] logged the same screen before its action.
  bool hasSameScreen(AtlasStage other) {
    return screen == other.screen && designScreen == other.designScreen;
  }

  /// Whether [other] recorded the same journal.
  bool hasSameJournal(AtlasStage other) {
    return _equality.equals(journal, other.journal);
  }

  /// Whether [other] measured the same bounds of its target.
  bool hasSameTargetRect(AtlasStage other) {
    return _equality.equals(targetRect, other.targetRect);
  }

  /// The same stage holding [journal] instead.
  AtlasStage copyWithJournal(List<Object?> journal) {
    return AtlasStage(
      label: label,
      action: action,
      journal: journal,
      ok: ok,
      target: target,
      block: block,
      targetRect: targetRect,
      screen: screen,
      designScreen: designScreen,
      shot: shot,
      error: error,
      stepHash: stepHash,
      anchor: anchor,
      launchedAt: launchedAt,
      headlessFrameHash: headlessFrameHash,
      headlessJournalHash: headlessJournalHash,
      sources: sources,
      texts: texts,
      localeKeys: localeKeys,
      widgets: widgets,
    );
  }

  /// The same stage holding [stepHash], [sources] and [localeKeys] instead.
  AtlasStage copyWithHashes({
    required String? stepHash,
    required Map<String, String> sources,
    required Map<String, String> localeKeys,
  }) {
    return AtlasStage(
      label: label,
      action: action,
      journal: journal,
      ok: ok,
      target: target,
      block: block,
      targetRect: targetRect,
      screen: screen,
      designScreen: designScreen,
      shot: shot,
      error: error,
      stepHash: stepHash,
      anchor: anchor,
      launchedAt: launchedAt,
      headlessFrameHash: headlessFrameHash,
      headlessJournalHash: headlessJournalHash,
      sources: sources,
      texts: texts,
      localeKeys: localeKeys,
      widgets: widgets,
    );
  }

  /// The same stage holding [anchor] and [launchedAt] instead.
  AtlasStage copyWithLaunch({
    required String? anchor,
    required String? launchedAt,
  }) {
    return AtlasStage(
      label: label,
      action: action,
      journal: journal,
      ok: ok,
      target: target,
      block: block,
      targetRect: targetRect,
      screen: screen,
      designScreen: designScreen,
      shot: shot,
      error: error,
      stepHash: stepHash,
      anchor: anchor,
      launchedAt: launchedAt,
      headlessFrameHash: headlessFrameHash,
      headlessJournalHash: headlessJournalHash,
      sources: sources,
      texts: texts,
      localeKeys: localeKeys,
      widgets: widgets,
    );
  }

  /// The same stage holding [shot] instead.
  AtlasStage copyWithShot(String? shot) {
    return AtlasStage(
      label: label,
      action: action,
      journal: journal,
      ok: ok,
      target: target,
      block: block,
      targetRect: targetRect,
      screen: screen,
      designScreen: designScreen,
      shot: shot,
      error: error,
      stepHash: stepHash,
      anchor: anchor,
      launchedAt: launchedAt,
      headlessFrameHash: headlessFrameHash,
      headlessJournalHash: headlessJournalHash,
      sources: sources,
      texts: texts,
      localeKeys: localeKeys,
      widgets: widgets,
    );
  }

  /// The same stage holding the headless [frameHash] and [journalHash]
  /// instead.
  AtlasStage copyWithHeadlessHashes({
    required String? frameHash,
    required String? journalHash,
  }) {
    return AtlasStage(
      label: label,
      action: action,
      journal: journal,
      ok: ok,
      target: target,
      block: block,
      targetRect: targetRect,
      screen: screen,
      designScreen: designScreen,
      shot: shot,
      error: error,
      stepHash: stepHash,
      anchor: anchor,
      launchedAt: launchedAt,
      headlessFrameHash: frameHash,
      headlessJournalHash: journalHash,
      sources: sources,
      texts: texts,
      localeKeys: localeKeys,
      widgets: widgets,
    );
  }
}

/// {@category Utils}
///
/// The screen a run ended on.
final class AtlasEnd {
  static const _equality = ListEquality<String>();

  /// The texts the frame after the last step showed, in tree order, then
  /// those read after the steps of the last stage that neither its frame nor
  /// this one showed.
  final List<String> texts;

  /// The localization keys whose values render [texts], mapped to the hash of
  /// the value.
  final Map<String, String> localeKeys;

  /// The widget types the frame after the last step showed, sorted; empty
  /// when the snapshot was captured before the end held them.
  final List<String> widgets;

  /// The `screen_name` logged by the last step.
  final String? screen;

  /// The design screen name logged by the last step.
  final String? designScreen;

  /// Content hash of the screenshot taken after the last step.
  final String? shot;

  /// Hash of the frame after the last step the headless walk showed when the
  /// end was written, absent while no walk wrote it.
  final String? headlessFrameHash;

  const AtlasEnd({
    required this.screen,
    required this.designScreen,
    required this.shot,
    this.headlessFrameHash,
    this.texts = const [],
    this.localeKeys = const {},
    this.widgets = const [],
  });

  /// Reads the end back out of a decoded snapshot, empty when it is absent.
  factory AtlasEnd.fromJson(Object? json) {
    final end = json is Map<String, Object?> ? json : const <String, Object?>{};
    final localeKeys = AtlasJson.tryReadObject(end, 'localeKeys') ?? {};

    return AtlasEnd(
      screen: AtlasJson.tryReadString(end, 'screen'),
      designScreen: AtlasJson.tryReadString(end, 'designScreen'),
      shot: AtlasJson.tryReadString(end, 'shot'),
      headlessFrameHash: AtlasJson.tryReadString(end, 'headlessFrameHash'),
      texts: AtlasJson.readList(end, 'texts').whereType<String>().toList(),
      localeKeys: {
        for (final key in localeKeys.keys)
          key: AtlasJson.readString(localeKeys, key),
      },
      widgets: AtlasJson.readList(end, 'widgets').whereType<String>().toList(),
    );
  }

  /// The end as a snapshot file holds it.
  Map<String, Object?> toJson() {
    final keys = localeKeys.keys.toList()..sort();

    return {
      'screen': screen,
      'designScreen': designScreen,
      'shot': shot,
      'headlessFrameHash': ?headlessFrameHash,
      if (texts.isNotEmpty) 'texts': texts,
      if (keys.isNotEmpty)
        'localeKeys': {for (final key in keys) key: localeKeys[key]},
      if (widgets.isNotEmpty) 'widgets': widgets,
    };
  }

  /// Whether [other] logged the same screen.
  bool hasSameScreen(AtlasEnd other) {
    return screen == other.screen && designScreen == other.designScreen;
  }

  /// Whether [other] showed the same texts.
  bool hasSameTexts(AtlasEnd other) {
    return _equality.equals(texts, other.texts);
  }

  /// The same end holding [shot] instead.
  AtlasEnd copyWithShot(String? shot) {
    return AtlasEnd(
      screen: screen,
      designScreen: designScreen,
      shot: shot,
      headlessFrameHash: headlessFrameHash,
      texts: texts,
      localeKeys: localeKeys,
      widgets: widgets,
    );
  }

  /// The same end holding the headless [frameHash] instead.
  AtlasEnd copyWithHeadlessFrameHash(String? frameHash) {
    return AtlasEnd(
      screen: screen,
      designScreen: designScreen,
      shot: shot,
      headlessFrameHash: frameHash,
      texts: texts,
      localeKeys: localeKeys,
      widgets: widgets,
    );
  }
}
