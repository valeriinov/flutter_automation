import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_declarations_store.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_groups.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_page_blobs.dart';
import 'package:flutter_automation_atlas/src/atlas_page_part.dart';
import 'package:flutter_automation_atlas/src/atlas_published_variants.dart';
import 'package:flutter_automation_atlas/src/atlas_series.dart';
import 'package:flutter_automation_atlas/src/atlas_shot.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_encoder.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_source.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_table.dart';
import 'package:flutter_automation_atlas/src/atlas_translations.dart';

typedef _RenderedVariant = ({
  AtlasVariantDefinition definition,
  AtlasSnapshot snapshot,
  Map<String, AtlasSeriesSnapshot> translatedSeries,
});

typedef _GatheredPage = ({
  Map<String, Object?> data,
  Map<String, Object?> meta,
  Set<String> shots,
  Map<String, Object?> totals,
  List<String> unlistedSnapshots,
  List<String> missingShots,
  List<AtlasSnapshot> snapshots,
});

/// {@category Utils}
///
/// Writes the atlas page from the snapshots, the texts of the flow files and
/// the data of the project.
///
/// A variant is shown when [AtlasPublishedVariants] names it and the shown
/// locale holds its own snapshot of it, in the order its flow file lists it;
/// the snapshots of every other variant stay stored with their shots. The page
/// shows the default locale; a bundle shows the one locale it is written for,
/// or every page locale when it names none. The variant carries its `entry`
/// and `stateOf` when its flow file names them, the shown locale series itself
/// and, on a page of every locale, every other page locale series under
/// `series`: its own stages, or only the `fallbackLocale` whose stages it
/// shows.
///
/// The page data holds only the [AtlasPagePart]s of the [AtlasEdition]:
///
/// - [AtlasPagePart.flowStages]: the `flows`, the `groups` of
///   [AtlasGroups], the `totals`, and on each stage its screenshot, the place
///   of the tap, its step `title` and, for a `scroll`, its distances;
/// - [AtlasPagePart.screenDescriptions]: the `screenDescriptions` of every
///   design screen a shown stage or end names;
/// - [AtlasPagePart.designLinks]: the `designUrl` of a stage and of an end,
///   the [AtlasProject.designLink] of its design screen;
/// - [AtlasPagePart.tables]: the rows of every [AtlasTable] but the table of
///   the translation keys, under the `id` of the table;
/// - [AtlasPagePart.localeKeys]: the `keys` of a stage and the rows of the
///   table [AtlasTable.localeKeysId] as `localeKeys`;
/// - [AtlasPagePart.translations]: the values of every page locale once, as
///   `locales`;
/// - [AtlasPagePart.journalRecords]: the journal of a stage, split by
///   [AtlasJournalStages.split]: what the action produced stays on the stage
///   as `afterAction`, what the screen it opened produced goes to the next
///   stage, or to the end, as `onScreenOpen`;
/// - [AtlasPagePart.mockScenario]: the `scenario` of a variant;
/// - [AtlasPagePart.recordSearch]: the lowercase texts of the journal
///   records the page searches.
///
/// A second script of the page, `atlas-meta`, holds what the page needs to
/// draw itself: the project name, the source label, the build time of a
/// bundle as `builtAt`, the parts,
/// the menu of the tables with their columns, the locales and the journal
/// kinds. The page data replaces the placeholder inside the template's JSON
/// script, so every `</` in it is written as `<\/` to keep a text from closing
/// that script.
///
/// Every long string the page data repeats is stored once, as
/// [AtlasPageBlobs] writes it.
///
/// [build] reads every source and returns the page text, writing nothing;
/// [render] writes that text and deletes the shots no stored snapshot names;
/// [renderBundle] writes the page for one shot source outside the repository.
/// The shots script of the template holds `shotSheets`, `shotCells` and
/// `shotUrls`, empty on the page; with [AtlasShotSource.inline] a bundle
/// holds the data URI of each sheet of up to 16 shots in `shotSheets` and the
/// sheet index, left, top, width and height of each shot by its content hash
/// in `shotCells`; with [AtlasShotSource.urls] it holds the link of each shot
/// in `shotUrls`; and its page data is one string, the base64 of its gzip.
/// With [AtlasShotSource.sheets] a bundle writes each sheet as the file
/// `shots/<hash>.webp` beside the page. It holds that relative path in
/// `shotSheets` instead of a data URI.
final class AtlasPageRenderer {
  static const _templateUri =
      'package:flutter_automation_atlas/template/index.html';
  static const _packageName = 'flutter_automation_atlas';
  static const _templatePathInPackage = 'lib/template/index.html';
  static const _packageConfigPath = '.dart_tool/package_config.json';
  static const _dataPlaceholder = '/*ATLAS_DATA*/';
  static const _shotsPlaceholder = '/*ATLAS_SHOTS*/';
  static const _metaPlaceholder = '/*ATLAS_META*/';
  static const _reservedTableIds = {
    'flows',
    'groups',
    'screenDescriptions',
    'locales',
    'totals',
    'seriesLocale',
    AtlasPageBlobs.blobsKey,
    'shotSheets',
    'shotCells',
    'shotUrls',
  };
  static const _shotsPerSheet = 16;
  static const _shotsDirectory = 'shots';
  static const _pngType = 'image/png';
  static const _designLinkKey = 'designUrl';
  static const _journalKey = 'journal';
  static const _stepHashKey = 'stepHash';
  static const _sourcesKey = 'sources';
  static const _textsKey = 'texts';
  static const _localeKeysKey = 'localeKeys';
  static const _scrollAction = 'scroll';
  static const _localeKeyFinderPrefix = 'localeKey';
  static final _pathIdPattern = RegExp(r'\d+');

  final AtlasLocations _paths;
  final AtlasShotEncoder? _shotEncoder;
  final String? _template;
  final String? _sourceLabel;
  final DateTime Function() _clock;

  /// The [shotEncoder] parameter turns shots into the sheets the bundle
  /// inlines or writes, an [AtlasShotWebpEncoder] when absent; the [template]
  /// parameter replaces the page template of the package; the [sourceLabel]
  /// parameter is the label of the source the page header and footer show;
  /// the [clock] parameter gives the build time of a bundle, which its footer
  /// shows as a date, [DateTime.now] when absent.
  AtlasPageRenderer(
    this._paths, {
    AtlasShotEncoder? shotEncoder,
    String? template,
    String? sourceLabel,
    DateTime Function()? clock,
  }) : _shotEncoder = shotEncoder,
       _template = template,
       _sourceLabel = sourceLabel,
       _clock = clock ?? DateTime.now;

  /// Reads every source and returns the page of [edition], the `full` one
  /// when absent, its snapshots make now.
  Future<AtlasPageRendering> build({AtlasEdition? edition}) async {
    final shownEdition = edition ?? _resolveFullEdition();
    final gathered = _gather(shownEdition);
    final page = _assemble(
      template: await _readTemplate(),
      gathered: gathered,
      shotsData: const {},
      isPacked: false,
    );

    return AtlasPageRendering(
      page: page,
      totals: gathered.totals,
      deletedShots: const [],
      deletedDeclarations: const [],
      unlistedSnapshots: gathered.unlistedSnapshots,
      missingShots: gathered.missingShots,
    );
  }

  /// Writes the page of [edition], the `full` one when absent, to
  /// [AtlasLocations.pagePath], deletes the shots and the declarations
  /// records no snapshot names and returns what was written.
  Future<AtlasPageRendering> render({AtlasEdition? edition}) async {
    final shownEdition = edition ?? _resolveFullEdition();
    final gathered = _gather(shownEdition);
    final page = _assemble(
      template: await _readTemplate(),
      gathered: gathered,
      shotsData: const {},
      isPacked: false,
    );

    File(_paths.pagePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(page);

    return AtlasPageRendering(
      page: page,
      totals: gathered.totals,
      deletedShots: _deleteUnreferencedShots(gathered.snapshots),
      deletedDeclarations: _deleteUnreferencedDeclarations(gathered.snapshots),
      unlistedSnapshots: gathered.unlistedSnapshots,
      missingShots: gathered.missingShots,
    );
  }

  /// Writes the page of [edition] for the shot [source] to
  /// [AtlasLocations.resolveBundlePagePath], leaving the page and the shots
  /// of the store in place, over the limits or not, and returns its byte
  /// size and image count.
  ///
  /// The [locale] parameter names the one series the bundle shows; the
  /// bundle holds every page locale when it is absent. For
  /// [AtlasShotSource.urls] the shot publisher of the project puts the shots
  /// where a browser reads them. For [AtlasShotSource.sheets] the folder
  /// `shots/` beside the page holds the sheet files the page reads.
  /// [renderBundle] deletes every other file and folder in it.
  ///
  /// Throws an [AtlasException] when [locale] is none of
  /// [AtlasLocations.pageLocales], when [source] is [AtlasShotSource.urls]
  /// and [AtlasProject.shotPublisher] is absent, or when the publisher fails
  /// or leaves a shot without a link.
  Future<AtlasBundleRendering> renderBundle({
    required AtlasEdition edition,
    required AtlasShotSource source,
    String? locale,
  }) async {
    if (locale != null && !_paths.pageLocales.contains(locale)) {
      throw AtlasException(
        'The page shows no $locale series: a bundle is written for '
        '${_paths.pageLocales.join(', ')}.',
      );
    }

    final gathered = _gather(edition, bundleLocale: locale, builtAt: _clock());
    final shots = gathered.shots.whereNot(_isShotMissing).toList();
    final path = _paths.resolveBundlePagePath(edition.name, locale: locale);

    final (:shotsData, :images) = await _prepareShots(
      source,
      shots,
      _paths.resolveBundleShotsPath(path),
    );

    final page = _assemble(
      template: await _readTemplate(),
      gathered: gathered,
      shotsData: shotsData,
      isPacked: true,
    );
    final bytes = utf8.encode(page);

    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes);

    if (source == AtlasShotSource.files) {
      _copyShots(shots, _paths.resolveBundleShotsPath(path));
    }

    return AtlasBundleRendering(
      path: path,
      bytes: bytes.length,
      images: images,
    );
  }

  AtlasEdition _resolveFullEdition() {
    return _paths.pageConfig.resolveEdition(AtlasEdition.fullName);
  }

  Future<String> _readTemplate() async {
    final template = _template ?? await _readPackageTemplate();

    for (final placeholder in [
      _dataPlaceholder,
      _shotsPlaceholder,
      _metaPlaceholder,
    ]) {
      if (!template.contains(placeholder)) {
        throw AtlasException(
          'The page template holds no $placeholder placeholder.',
        );
      }
    }

    return template;
  }

  Future<String> _readPackageTemplate() async {
    final file = File.fromUri(await _resolveTemplateUri());

    if (!file.existsSync()) {
      throw AtlasException('No page template at ${file.path}.');
    }

    return file.readAsStringSync();
  }

  // `flutter test` cannot resolve a package URI in its isolate, so the
  // package configuration found above the working directory answers instead.
  Future<Uri> _resolveTemplateUri() async {
    final uri = await _tryResolvePackageUri() ?? _tryResolveFromPackageConfig();

    if (uri == null) {
      throw const AtlasException('No page template: $_templateUri is unknown.');
    }

    return uri;
  }

  Future<Uri?> _tryResolvePackageUri() async {
    try {
      return await Isolate.resolvePackageUri(Uri.parse(_templateUri));
    } on UnsupportedError {
      return null;
    }
  }

  Uri? _tryResolveFromPackageConfig() {
    for (final directory in _listAncestors(Directory.current)) {
      final config = File(p.join(directory.path, _packageConfigPath));

      if (!config.existsSync()) {
        continue;
      }

      final packages = AtlasJson.readObject(
        jsonDecode(config.readAsStringSync()),
        config.path,
      );
      final package = AtlasJson.readObjects(
        packages,
        'packages',
      ).firstWhereOrNull((package) => package['name'] == _packageName);

      if (package == null) {
        continue;
      }

      final root = config.uri.resolve('${package['rootUri']}/');

      return root.resolve(_templatePathInPackage);
    }

    return null;
  }

  Iterable<Directory> _listAncestors(Directory directory) sync* {
    Directory current = directory.absolute;

    while (true) {
      yield current;

      if (current.parent.path == current.path) {
        return;
      }

      current = current.parent;
    }
  }

  _GatheredPage _gather(
    AtlasEdition edition, {
    String? bundleLocale,
    DateTime? builtAt,
  }) {
    final project = _paths.project;
    final definitions = AtlasDefinitions.read(_paths);
    final publishedVariants = AtlasPublishedVariants.read(_paths, definitions);
    final snapshots = AtlasSnapshotStore(_paths).readEveryLocale();
    final shownLocale = bundleLocale ?? _paths.defaultLocale;
    final seriesLocales = bundleLocale == null
        ? _paths.pageLocales
        : [bundleLocale];
    final seriesByLocale = {
      for (final locale in seriesLocales)
        locale: AtlasSeries.resolve(
          snapshots,
          locale: locale,
          defaultLocale: _paths.defaultLocale,
        ),
    };
    final flows = [
      for (final flow in definitions.flows)
        (
          flow: flow,
          variants: _readRenderedVariants(
            flow,
            publishedVariants,
            seriesByLocale,
            shownLocale,
          ),
        ),
    ].where((flow) => flow.variants.isNotEmpty).toList();
    final renderedVariants = flows.expand((flow) => flow.variants).toList();
    final shots = renderedVariants
        .expand(_readRenderedSnapshots)
        .expand(_readShots)
        .toSet();
    final totals = {
      'flows': flows.length,
      'variants': renderedVariants.length,
      'stages': renderedVariants
          .map((variant) => variant.snapshot.stages.length)
          .sum,
      'shots': shots.length,
      'shotsBytes': shots.map(_readShotBytes).sum,
    };
    final groups = AtlasGroups(definitions, project);
    final tables = project.tables(_paths.storePath);

    _checkTableIds(tables);

    final data = {
      'flows': [
        for (final flow in flows)
          _buildFlowData(edition, flow.flow, flow.variants),
      ],
      'groups': groups.buildPageData(
        shownFlows: flows.map((flow) => flow.flow.name).toList(),
      ),
      if (edition.has(AtlasPagePart.screenDescriptions))
        'screenDescriptions': _buildScreenDescriptions(
          _readDesignScreens(renderedVariants),
        ),
      if (edition.has(AtlasPagePart.translations))
        'locales': {
          for (final locale in _paths.pageLocales)
            locale: AtlasTranslations.read(_paths, locale).values,
        },
      for (final table in tables)
        if (_isTableShown(edition, table)) table.id: table.rows,
      'totals': totals,
      'seriesLocale': ?bundleLocale,
    };

    return (
      data: data,
      meta: _buildMeta(edition, tables, builtAt),
      shots: shots,
      totals: totals,
      unlistedSnapshots: _findUnlistedSnapshots(snapshots, definitions),
      missingShots: shots.where(_isShotMissing).toList(),
      snapshots: snapshots,
    );
  }

  String _assemble({
    required String template,
    required _GatheredPage gathered,
    required Map<String, Object?> shotsData,
    required bool isPacked,
  }) {
    final dataText = jsonEncode(AtlasPageBlobs.extract(gathered.data));
    final shotsText = jsonEncode({
      'shotSheets': <Object?>[],
      'shotCells': <String, Object?>{},
      ...shotsData,
    });

    return template
        .replaceFirst(
          _dataPlaceholder,
          _escapeScriptText(
            isPacked ? jsonEncode(_packText(dataText)) : dataText,
          ),
        )
        .replaceFirst(_shotsPlaceholder, _escapeScriptText(shotsText))
        .replaceFirst(
          _metaPlaceholder,
          _escapeScriptText(jsonEncode(gathered.meta)),
        );
  }

  Future<({Map<String, Object?> shotsData, int images})> _prepareShots(
    AtlasShotSource source,
    List<String> shots,
    String shotsDirectory,
  ) async {
    switch (source) {
      case AtlasShotSource.files:
        return (shotsData: const <String, Object?>{}, images: 0);
      case AtlasShotSource.inline:
        final sheets = _encodeShotSheets(shots);

        return (
          shotsData: _buildShotSheetData(sheets, (sheet) => sheet.dataUri),
          images: sheets.length,
        );
      case AtlasShotSource.sheets:
        final sheets = _encodeShotSheets(shots);
        final sheetFiles = {
          for (final sheet in sheets) sheet.fileName: sheet.bytes,
        };

        _writeSheets(sheetFiles, shotsDirectory);

        return (
          shotsData: _buildShotSheetData(
            sheets,
            (sheet) => '$_shotsDirectory/${sheet.fileName}',
          ),
          images: sheetFiles.length,
        );
      case AtlasShotSource.urls:
        final links = await _publish(shots);

        return (
          shotsData: {
            'shotUrls': {
              for (final MapEntry(:key, :value) in links.entries) key: '$value',
            },
          },
          images: 0,
        );
    }
  }

  Future<Map<String, Uri>> _publish(List<String> shots) async {
    final publisher = _paths.project.shotPublisher;

    if (publisher == null) {
      throw const AtlasException(
        'The shot source urls needs AtlasProject.shotPublisher, and the '
        'project returns none.',
      );
    }

    final Map<String, Uri> links;

    try {
      links = await publisher.publish([
        for (final shot in shots)
          AtlasShot(
            hash: shot,
            bytes: File(_paths.resolveShotPath(shot)).readAsBytesSync(),
            type: _pngType,
          ),
      ]);
    } on AtlasException {
      rethrow;
    } on Object catch (error) {
      throw AtlasException('The shot publisher failed: $error');
    }

    final unlinked = shots.where((shot) => !links.containsKey(shot)).toList();

    if (unlinked.isNotEmpty) {
      throw AtlasException(
        'The shot publisher returned no link for ${unlinked.join(', ')}.',
      );
    }

    return {for (final shot in shots) shot: ?links[shot]};
  }

  void _copyShots(List<String> shots, String directory) {
    for (final shot in shots) {
      File(_paths.resolveShotPath(shot)).copySync(
        (File(
          p.join(directory, '$shot.png'),
        )..createSync(recursive: true)).path,
      );
    }
  }

  void _writeSheets(Map<String, Uint8List> sheetFiles, String directory) {
    final folder = Directory(directory);

    if (folder.existsSync()) {
      for (final entity in folder.listSync()) {
        if (!sheetFiles.containsKey(p.basename(entity.path))) {
          entity.deleteSync(recursive: true);
        }
      }
    }

    for (final MapEntry(key: name, value: bytes) in sheetFiles.entries) {
      File(p.join(directory, name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
  }

  List<String> _deleteUnreferencedShots(List<AtlasSnapshot> snapshots) {
    final directory = Directory(_paths.shotsPath);

    if (!directory.existsSync()) {
      return const [];
    }

    final referencedFileNames = snapshots
        .expand(_readShots)
        .map((shot) => p.basename(_paths.resolveShotPath(shot)))
        .toSet();
    final unreferencedFiles = directory
        .listSync()
        .whereType<File>()
        .where((file) => !referencedFileNames.contains(p.basename(file.path)))
        .toList();

    for (final file in unreferencedFiles) {
      file.deleteSync();
    }

    return unreferencedFiles.map((file) => p.basename(file.path)).toList();
  }

  List<String> _deleteUnreferencedDeclarations(List<AtlasSnapshot> snapshots) {
    return AtlasDeclarationsStore(_paths).deleteUnreferenced({
      for (final snapshot in snapshots) ...snapshot.manifest.values,
    });
  }

  List<_RenderedVariant> _readRenderedVariants(
    AtlasDefinition flow,
    AtlasPublishedVariants publishedVariants,
    Map<String, Map<String, AtlasSeriesSnapshot>> seriesByLocale,
    String shownLocale,
  ) {
    final shownSeries = seriesByLocale[shownLocale];

    return [
      for (final variant in publishedVariants.filter(flow.variants))
        if (shownSeries?[variant.id] case AtlasSeriesSnapshot(
          :final snapshot,
          fallbackLocale: null,
        ))
          (
            definition: variant,
            snapshot: snapshot,
            translatedSeries: {
              for (final MapEntry(key: locale, value: series)
                  in seriesByLocale.entries)
                if (locale != shownLocale) locale: ?series[variant.id],
            },
          ),
    ];
  }

  Iterable<AtlasSnapshot> _readRenderedSnapshots(_RenderedVariant variant) {
    return [
      variant.snapshot,
      for (final translated in variant.translatedSeries.values)
        if (translated.fallbackLocale == null) translated.snapshot,
    ];
  }

  int _readShotBytes(String shot) {
    final file = File(_paths.resolveShotPath(shot));

    return file.existsSync() ? file.lengthSync() : 0;
  }

  void _checkTableIds(List<AtlasTable> tables) {
    final reserved = tables
        .map((table) => table.id)
        .where(_reservedTableIds.contains)
        .toList();

    if (reserved.isNotEmpty) {
      throw AtlasException(
        'The table ids ${reserved.join(', ')} are names of the page data; '
        'AtlasProject.tables needs other ids.',
      );
    }
  }

  bool _isTableShown(AtlasEdition edition, AtlasTable table) {
    final part = table.id == AtlasTable.localeKeysId
        ? AtlasPagePart.localeKeys
        : AtlasPagePart.tables;

    return edition.has(part);
  }

  Map<String, Object?> _buildMeta(
    AtlasEdition edition,
    List<AtlasTable> tables,
    DateTime? builtAt,
  ) {
    final project = _paths.project;
    final schema = project.journalSchema;

    return {
      'projectName': project.projectName,
      'sourceLabel': ?_sourceLabel,
      'builtAt': ?builtAt?.toUtc().toIso8601String(),
      'locales': project.locales,
      'parts': [for (final part in edition.parts) part.name],
      'tables': [
        for (final table in tables)
          if (_isTableShown(edition, table))
            {
              'id': table.id,
              'title': table.title,
              'columns': [
                for (final column in table.columns)
                  {'key': column.key, 'title': column.title},
              ],
              'journalKind': ?table.journalKind,
            },
      ],
      'journal': {
        'analytics': schema.analyticsKind,
        'state': schema.stateKind,
        'requests': schema.requestKinds.toList(),
        'stateKey': schema.stateKey,
        'createdKey': schema.createdKey,
        'parametersKey': schema.parametersKey,
      },
    };
  }

  Map<String, Object?> _buildScreenDescriptions(Set<String> designScreens) {
    final descriptions = _paths.project.screenDescriptions;
    final undescribed = designScreens
        .where((screen) => !descriptions.containsKey(screen))
        .toList();

    if (undescribed.isNotEmpty) {
      throw AtlasException(
        'The screen descriptions describe no ${undescribed.join(', ')}; '
        'each shown design screen takes its prose.',
      );
    }

    return {for (final screen in designScreens) screen: descriptions[screen]};
  }

  Set<String> _readDesignScreens(List<_RenderedVariant> variants) {
    return variants
        .map((variant) => variant.snapshot)
        .expand(
          (snapshot) => [
            ...snapshot.stages.map((stage) => stage.designScreen),
            snapshot.end.designScreen,
          ],
        )
        .nonNulls
        .toSet();
  }

  Map<String, Object?> _buildFlowData(
    AtlasEdition edition,
    AtlasDefinition flow,
    List<_RenderedVariant> variants,
  ) {
    return {
      'name': flow.name,
      'title': flow.title?.toJson(),
      'variants': [
        for (final variant in variants) _buildVariantData(edition, variant),
      ],
    };
  }

  String _escapeScriptText(String text) => text.replaceAll('</', r'<\/');

  String _packText(String text) {
    return base64Encode(GZipCodec(level: 9).encode(utf8.encode(text)));
  }

  List<AtlasShotSheet> _encodeShotSheets(List<String> shots) {
    final shotEncoder = _shotEncoder ?? AtlasShotWebpEncoder(_paths);

    return shots.slices(_shotsPerSheet).map(shotEncoder.encodeSheet).toList();
  }

  Map<String, Object?> _buildShotSheetData(
    List<AtlasShotSheet> sheets,
    String Function(AtlasShotSheet sheet) reference,
  ) {
    return {
      'shotSheets': [for (final sheet in sheets) reference(sheet)],
      'shotCells': {
        for (final (index, sheet) in sheets.indexed)
          for (final MapEntry(key: shot, value: cell) in sheet.cells.entries)
            shot: [index, ...cell.toPageData()],
      },
    };
  }

  List<String> _findUnlistedSnapshots(
    List<AtlasSnapshot> snapshots,
    AtlasDefinitions definitions,
  ) {
    final listedIds = definitions.variants.map((variant) => variant.id).toSet();

    return snapshots
        .map((snapshot) => snapshot.id)
        .where((id) => !listedIds.contains(id))
        .toSet()
        .toList();
  }

  Iterable<String> _readShots(AtlasSnapshot snapshot) {
    return [
      ...snapshot.stages.map((stage) => stage.shot),
      snapshot.end.shot,
    ].nonNulls;
  }

  Map<String, Object?> _buildVariantData(
    AtlasEdition edition,
    _RenderedVariant variant,
  ) {
    final definition = variant.definition;

    return {
      'name': definition.name,
      'title': definition.automationFlow.variantTitle?.toJson(),
      'proves': definition.automationFlow.proves?.toJson(),
      'entry': ?definition.automationFlow.entry?.toJson(),
      'stateOf': ?definition.automationFlow.stateOf,
      'isDefault': definition.isDefault,
      if (edition.has(AtlasPagePart.mockScenario))
        'scenario': definition.scenario,
      ..._buildSeriesData(edition, definition, variant.snapshot),
      'series': {
        for (final MapEntry(key: locale, value: translated)
            in variant.translatedSeries.entries)
          locale: _buildTranslatedSeriesData(edition, definition, translated),
      },
    };
  }

  Map<String, Object?> _buildTranslatedSeriesData(
    AtlasEdition edition,
    AtlasVariantDefinition definition,
    AtlasSeriesSnapshot translated,
  ) {
    if (translated.fallbackLocale case final fallbackLocale?) {
      return {'fallbackLocale': fallbackLocale};
    }

    return _buildSeriesData(edition, definition, translated.snapshot);
  }

  Map<String, Object?> _buildSeriesData(
    AtlasEdition edition,
    AtlasVariantDefinition definition,
    AtlasSnapshot snapshot,
  ) {
    final actionSteps = definition.automationFlow.steps
        .where((step) => step.isUserAction)
        .toList();
    final journalSplits = AtlasJournalStages(_paths).split(snapshot);
    final end = snapshot.end;
    final endOnScreenOpen = journalSplits.lastOrNull?.onScreenOpen ?? const [];

    return {
      'ok': snapshot.ok,
      'device': snapshot.device,
      'stages': [
        for (final (index, stage) in snapshot.stages.indexed)
          _buildStageData(
            edition,
            stage,
            step: _tryFindActionStep(stage, actionSteps.elementAtOrNull(index)),
            afterAction: journalSplits[index].afterAction,
            onScreenOpen: index == 0
                ? const []
                : journalSplits[index - 1].onScreenOpen,
          ),
      ],
      'end': {
        ..._withoutHiddenEndParts(edition, end.toJson()),
        ..._buildDesignLinkData(edition, end.designScreen),
        'onScreenOpen': _shownRecords(edition, endOnScreenOpen),
        'search': {
          'frame': _buildFrameSearchData(
            edition,
            screen: end.screen,
            designScreen: end.designScreen,
            onScreenOpen: endOnScreenOpen,
          ),
        },
      },
    };
  }

  Map<String, Object?> _withoutHiddenEndParts(
    AtlasEdition edition,
    Map<String, Object?> end,
  ) {
    return {
      for (final MapEntry(:key, :value) in end.entries)
        if (!(key == _localeKeysKey &&
                !edition.has(AtlasPagePart.localeKeys)) &&
            !(key == _textsKey && !edition.has(AtlasPagePart.translations)))
          key: value,
    };
  }

  Map<String, Object?> _buildStageData(
    AtlasEdition edition,
    AtlasStage stage, {
    required AutomationStep? step,
    required List<Object?> afterAction,
    required List<Object?> onScreenOpen,
  }) {
    final keys = _buildStageKeysData(stage.localeKeys);
    final target = _readShownTarget(edition, stage.target);
    final json = stage.toJson()
      ..remove(_journalKey)
      ..remove(_stepHashKey)
      ..remove(_sourcesKey)
      ..remove(_textsKey)
      ..remove(_localeKeysKey);

    if (target == null) {
      json.remove('target');
    }

    return {
      ...json,
      ..._buildActionStepData(step),
      ..._buildDesignLinkData(edition, stage.designScreen),
      'afterAction': _shownRecords(edition, afterAction),
      'onScreenOpen': _shownRecords(edition, onScreenOpen),
      if (keys.isNotEmpty && edition.has(AtlasPagePart.localeKeys))
        'keys': keys,
      'search': {
        'frame': _buildFrameSearchData(
          edition,
          screen: stage.screen,
          designScreen: stage.designScreen,
          onScreenOpen: onScreenOpen,
        ),
        'arrow': _buildArrowSearchData(
          edition,
          stage,
          step,
          target,
          afterAction,
        ),
      },
    };
  }

  List<Object?> _shownRecords(AtlasEdition edition, List<Object?> records) {
    return edition.has(AtlasPagePart.journalRecords) ? records : const [];
  }

  Map<String, Object?> _buildDesignLinkData(
    AtlasEdition edition,
    String? designScreen,
  ) {
    if (!edition.has(AtlasPagePart.designLinks)) {
      return const {};
    }

    return {
      _designLinkKey: designScreen == null
          ? null
          : _paths.project.designLink(designScreen),
    };
  }

  Map<String, Object?>? _readShownTarget(
    AtlasEdition edition,
    Map<String, Object?>? target,
  ) {
    if (target == null || edition.has(AtlasPagePart.localeKeys)) {
      return target;
    }

    return _isLocaleKeyFinder(target) ? null : target;
  }

  bool _isLocaleKeyFinder(Object? finder) {
    return switch (finder) {
      {'by': final String by} when by.startsWith(_localeKeyFinderPrefix) =>
        true,
      Map<String, Object?>() => finder.values.any(_isLocaleKeyFinder),
      _ => false,
    };
  }

  AutomationStep? _tryFindActionStep(AtlasStage stage, AutomationStep? step) {
    if (step == null || !_hasSameLabelAndAction(stage, step)) {
      return null;
    }

    return step;
  }

  List<Map<String, Object?>> _buildStageKeysData(
    Map<String, String> localeKeys,
  ) {
    return [
      for (final key in localeKeys.keys.sorted()) {'k': key},
    ];
  }

  Map<String, Object?> _buildActionStepData(AutomationStep? step) {
    if (step == null) {
      return const {};
    }

    return {
      'title': ?step.title?.toJson(),
      if (step.action == _scrollAction)
        'scroll': {'dx': step.dx, 'dy': step.dy},
    };
  }

  Map<String, Object?> _buildFrameSearchData(
    AtlasEdition edition, {
    required String? screen,
    required String? designScreen,
    required List<Object?> onScreenOpen,
  }) {
    return {
      'screen': [?screen, ?designScreen].join(' · ').toLowerCase(),
      ..._buildRecordsSearchData(edition, onScreenOpen),
    };
  }

  Map<String, Object?> _buildArrowSearchData(
    AtlasEdition edition,
    AtlasStage stage,
    AutomationStep? step,
    Map<String, Object?>? target,
    List<Object?> afterAction,
  ) {
    final title = step?.title;
    final locales = _paths.pageLocales;
    final caption = [stage.label, ?title?.read(locales.first)].join(' · ');
    final value = target?['value'];

    return {
      'step': [
        caption,
        for (final locale in locales.skip(1)) ?title?.read(locale),
        if (value is Map<String, Object?>) ...value.values else ?value,
      ].join(' ').toLowerCase(),
      ..._buildRecordsSearchData(edition, afterAction),
    };
  }

  bool _hasSameLabelAndAction(AtlasStage stage, AutomationStep step) {
    return step.label == stage.label && step.action == stage.action;
  }

  Map<String, Object?> _buildRecordsSearchData(
    AtlasEdition edition,
    List<Object?> records,
  ) {
    if (!edition.has(AtlasPagePart.recordSearch)) {
      return const {};
    }

    final schema = _paths.project.journalSchema;
    final searchedKinds = {...schema.requestKinds, schema.analyticsKind};
    final searchedRecords = records.whereType<Map<String, Object?>>().where(
      (record) => searchedKinds.contains(record['kind']),
    );

    return searchedRecords
        .groupListsBy((record) => '${record['kind']}')
        .map(
          (kind, kindRecords) =>
              MapEntry(kind, kindRecords.map(_buildRecordSearchText).toList()),
        );
  }

  String _buildRecordSearchText(Map<String, Object?> record) {
    final path = record['path'];

    if (path is! String) {
      return '${record['name'] ?? ''}'.toLowerCase();
    }

    final normalizedPath = path.replaceAll(_pathIdPattern, '{id}');

    return [?record['method'], path, normalizedPath].join(' ').toLowerCase();
  }

  bool _isShotMissing(String shot) {
    return !File(_paths.resolveShotPath(shot)).existsSync();
  }
}

/// {@category Utils}
///
/// The atlas page as its sources make it, and what writing it did.
final class AtlasPageRendering {
  /// The page text.
  final String page;

  /// The totals the page data carries.
  final Map<String, Object?> totals;

  /// File names of the shots deleted because no snapshot names them, empty
  /// for a build that wrote nothing.
  final List<String> deletedShots;

  /// File names of the declarations records deleted because no snapshot
  /// manifest names their source hash, empty for a build that wrote nothing.
  final List<String> deletedDeclarations;

  /// Snapshots whose variant no flow file lists any more, left off the page.
  final List<String> unlistedSnapshots;

  /// Shots a rendered snapshot names that the shots directory does not hold.
  final List<String> missingShots;

  const AtlasPageRendering({
    required this.page,
    required this.totals,
    required this.deletedShots,
    required this.deletedDeclarations,
    required this.unlistedSnapshots,
    required this.missingShots,
  });
}

/// {@category Utils}
///
/// The bundle [AtlasPageRenderer.renderBundle] wrote.
final class AtlasBundleRendering {
  /// The file of the bundle.
  final String path;

  /// Bytes of the bundle.
  final int bytes;

  /// Images the bundle holds: the sheets it inlines or writes as files.
  final int images;

  const AtlasBundleRendering({
    required this.path,
    required this.bytes,
    required this.images,
  });

  /// What a reader is told for each limit the bundle passes, `null` while it
  /// fits.
  String? tryDescribeOverLimit({
    required int maxBytes,
    required int maxImages,
  }) {
    final messages = [
      if (bytes > maxBytes)
        'The bundle $path takes $bytes bytes, over the $maxBytes byte limit.',
      if (images > maxImages)
        'The bundle $path holds $images images, over the $maxImages image '
            'limit.',
    ];

    return messages.isEmpty ? null : messages.join(' ');
  }
}
