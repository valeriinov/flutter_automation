import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:collection/collection.dart';
import 'package:flutter_automation_mock/mock_catalogue.dart';
import 'package:flutter_automation_runner/flutter_automation_runner.dart';
import 'package:path/path.dart' as p;

import 'package:flutter_automation_atlas/src/atlas_declarations_store.dart';
import 'package:flutter_automation_atlas/src/atlas_definitions.dart';
import 'package:flutter_automation_atlas/src/atlas_exception.dart';
import 'package:flutter_automation_atlas/src/atlas_groups.dart';
import 'package:flutter_automation_atlas/src/atlas_json.dart';
import 'package:flutter_automation_atlas/src/atlas_journal_stages.dart';
import 'package:flutter_automation_atlas/src/atlas_locations.dart';
import 'package:flutter_automation_atlas/src/atlas_page_part.dart';
import 'package:flutter_automation_atlas/src/atlas_published_variants.dart';
import 'package:flutter_automation_atlas/src/atlas_remote_shots.dart';
import 'package:flutter_automation_atlas/src/atlas_series.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_encoder.dart';
import 'package:flutter_automation_atlas/src/atlas_shot_source.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot.dart';
import 'package:flutter_automation_atlas/src/atlas_snapshot_store.dart';
import 'package:flutter_automation_atlas/src/atlas_table.dart';
import 'package:flutter_automation_atlas/src/atlas_store_reader.dart';
import 'package:flutter_automation_atlas/src/atlas_locale_keys_table.dart';
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
/// A page shows a variant when [AtlasPublishedVariants] names it. The shown
/// locale must hold its own snapshot of the variant. The variants appear in
/// the order of the flow file. The snapshots of all other variants stay in
/// the store with their shots. The page shows the default locale. A bundle
/// shows the one locale that its command names, or all page locales when it
/// names none. The variant carries its `entry` and `stateOf` when its flow
/// file names them. It carries the series of the shown locale itself. On a
/// page of all locales, it carries the series of each other page locale
/// under `series`. Such a series has its own stages, or only the
/// `fallbackLocale` whose stages it shows.
///
/// The page data holds only the [AtlasPagePart]s of the [AtlasEdition]:
///
/// - [AtlasPagePart.flowStages]: the `flows`, the `areas` of [AtlasGroups]
///   with their `groups`, the `totals`, and on each stage its screenshot, the
///   place of the tap, its step `title` and, for a `scroll`, its distances;
/// - [AtlasPagePart.screenDescriptions]: the `screenDescriptions` of each
///   design screen that a shown stage or end names;
/// - [AtlasPagePart.designLinks]: the `designUrl` of a stage and of an end,
///   the [AtlasProject.designLink] of its design screen;
/// - [AtlasPagePart.tables]: the rows of each [AtlasTable] except the table
///   of the translation keys, under the `id` of the table;
/// - [AtlasPagePart.localeKeys]: the `keys` of a stage and the rows of the
///   table [AtlasTable.localeKeysId] as `localeKeys`;
/// - [AtlasPagePart.translations]: the values of each page locale once, as
///   `locales`;
/// - [AtlasPagePart.journalRecords]: the journal of a stage, split by
///   [AtlasJournalStages.split]. What the action produced stays on the stage
///   as `afterAction`. What the screen it opened produced goes to the next
///   stage, or to the end, as `onScreenOpen`;
/// - [AtlasPagePart.mockScenario]: the `scenario` of a variant;
/// - [AtlasPagePart.recordSearch]: the lowercase texts of the journal
///   records that the page searches.
///
/// A second script of the page, `atlas-meta`, holds what the page needs to
/// draw itself. It holds the project name, the source label and the build
/// time of a bundle as `builtAt`. It holds the parts, the menu of the tables
/// with their columns, the locales and the journal kinds. The page data
/// replaces the placeholder inside the JSON script of the template. The
/// renderer writes each `</` in the data as `<\/`, so that no text can close
/// that script.
///
/// The page data repeats some long strings. [CatalogueBlobs] stores each of
/// them once.
///
/// [build] reads each source and returns the page text. It writes nothing.
/// [render] writes that text and deletes the shots that no stored snapshot
/// names. [renderBundle] writes the page for one shot source outside the
/// repository.
///
/// The shots script of the template holds `shotSheets`, `shotCells` and
/// `shotUrlTemplate`. The first two are empty on the page. With a remote
/// shot storage ([AtlasProject.shotStorage]), the page holds the link
/// template of the storage in `shotUrlTemplate` and reads each shot by it.
/// [render] then deletes no shot. The page data holds no `shotsBytes` total,
/// and no shot counts as missing. A bundle fills the script by the shot
/// source:
///
/// - With [AtlasShotSource.inline], a bundle holds the data URI of each sheet
///   of up to 16 shots in `shotSheets`. It holds the sheet index, left, top,
///   width and height of each shot by its content hash in `shotCells`.
/// - With [AtlasShotSource.urls], a bundle holds the link template of the
///   storage in `shotUrlTemplate`, and nothing goes to the storage. The page
///   data of a bundle is one string, the base64 of its gzip.
/// - With [AtlasShotSource.sheets], a bundle writes each sheet as the file
///   `shots/<sheet hash>.webp` beside the page. The hash of the sheet bytes
///   names the file. The bundle holds that relative path in `shotSheets`
///   instead of a data URI.
///
/// With a remote shot storage, a bundle of [AtlasShotSource.files],
/// [AtlasShotSource.inline] or [AtlasShotSource.sheets] reads the shots from
/// the cache folder. It first reads from the storage each shot that the
/// cache does not hold.
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
    'areas',
    'screenDescriptions',
    'locales',
    'totals',
    'seriesLocale',
    CatalogueBlobs.blobsKey,
    'shotSheets',
    'shotCells',
    'shotUrlTemplate',
  };
  static const _shotsPerSheet = 16;
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
  final AtlasRemoteShots? _remoteShots;

  /// The [shotEncoder] parameter turns shots into the sheets that the bundle
  /// inlines or writes. It is an [AtlasShotWebpEncoder] by default. The
  /// [template] parameter replaces the page template of the package. The
  /// [sourceLabel] parameter is the label of the source that the page footer
  /// shows. The [clock] parameter gives the build time of a bundle, which its
  /// footer shows as a date. It is [DateTime.now] by default.
  AtlasPageRenderer(
    this._paths, {
    AtlasShotEncoder? shotEncoder,
    String? template,
    String? sourceLabel,
    DateTime Function()? clock,
  }) : _shotEncoder = shotEncoder,
       _template = template,
       _sourceLabel = sourceLabel,
       _clock = clock ?? DateTime.now,
       _remoteShots = AtlasRemoteShots.tryCreate(_paths);

  /// Reads each source and returns the page of [edition] that the snapshots
  /// make now. The default [edition] is `full`.
  Future<AtlasPageRendering> build({AtlasEdition? edition}) async {
    final shownEdition = edition ?? _resolveFullEdition();
    final gathered = _gather(shownEdition);
    final page = _assemble(
      template: await _readTemplate(),
      gathered: gathered,
      shotsData: _buildStorageShotsData(),
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

  /// Writes the page of [edition] to [AtlasLocations.pagePath]. The default
  /// [edition] is `full`. It deletes the shots and the declaration records
  /// that no snapshot names. It returns what it wrote.
  Future<AtlasPageRendering> render({AtlasEdition? edition}) async {
    final shownEdition = edition ?? _resolveFullEdition();
    final gathered = _gather(shownEdition);
    final page = _assemble(
      template: await _readTemplate(),
      gathered: gathered,
      shotsData: _buildStorageShotsData(),
      isPacked: false,
    );

    File(_paths.pagePath)
      ..createSync(recursive: true)
      ..writeAsStringSync(page);

    return AtlasPageRendering(
      page: page,
      totals: gathered.totals,
      deletedShots: _paths.hasShotStorage
          ? const []
          : _deleteUnreferencedShots(gathered.snapshots),
      deletedDeclarations: _deleteUnreferencedDeclarations(gathered.snapshots),
      unlistedSnapshots: gathered.unlistedSnapshots,
      missingShots: gathered.missingShots,
    );
  }

  /// Writes the page of [edition] for the shot [source] to
  /// [AtlasLocations.resolveBundlePagePath]. The page and the shots of the
  /// store stay in place, over the limits or not. It returns the sizes, the
  /// file count and the image count of the bundle.
  ///
  /// The [locale] parameter names the one series that the bundle shows. When
  /// [locale] is `null`, the bundle holds all page locales. For
  /// [AtlasShotSource.urls], the page reads the shots by the link template of
  /// the shot storage of the project. The folder `shots/` beside the page holds
  /// the sheet files of [AtlasShotSource.sheets] or the shot files of
  /// [AtlasShotSource.files]. For each source, [renderBundle] first deletes
  /// each file and folder in it.
  ///
  /// Throws an [AtlasException] in these cases:
  /// - [locale] is none of [AtlasLocations.pageLocales].
  /// - [source] is [AtlasShotSource.urls] and [AtlasProject.shotStorage] is
  ///   `null`.
  /// - The shot storage does not hold a shot that another source reads.
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
    final shotsDirectory = _paths.resolveBundleShotsPath(path);

    _deleteDirectory(shotsDirectory);

    final (:shotsData, :images) = await _prepareShots(
      source,
      shots,
      shotsDirectory,
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
      _copyShots(shots, shotsDirectory);
    }

    final bundleFiles = _listFiles(p.dirname(path));

    return AtlasBundleRendering(
      path: path,
      pageBytes: bytes.length,
      bundleBytes: bundleFiles.map((file) => file.lengthSync()).sum,
      files: bundleFiles.length,
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
        .expand((snapshot) => snapshot.shots)
        .toSet();
    final totals = {
      'flows': flows.length,
      'variants': renderedVariants.length,
      'stages': renderedVariants
          .map((variant) => variant.snapshot.stages.length)
          .sum,
      'shots': shots.length,
      if (!_paths.hasShotStorage) 'shotsBytes': shots.map(_readShotBytes).sum,
    };
    final groups = AtlasGroups(definitions, project);
    final projectTables = project.tables(AtlasLocationsStore(_paths));

    _checkTableIds(projectTables);

    final tables = _addLocaleKeysTable(edition, projectTables);
    final data = {
      'flows': [
        for (final flow in flows)
          _buildFlowData(edition, flow.flow, flow.variants),
      ],
      'areas': groups.buildPageData(
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
    final dataText = jsonEncode(CatalogueBlobs.extract(gathered.data));
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

  void _deleteDirectory(String path) {
    final directory = Directory(path);

    if (directory.existsSync()) {
      directory.deleteSync(recursive: true);
    }
  }

  Future<({Map<String, Object?> shotsData, int images})> _prepareShots(
    AtlasShotSource source,
    List<String> shots,
    String shotsDirectory,
  ) async {
    switch (source) {
      case AtlasShotSource.files:
        await _remoteShots?.ensureCached(shots);

        return (shotsData: const <String, Object?>{}, images: shots.length);
      case AtlasShotSource.inline:
        await _remoteShots?.ensureCached(shots);

        final sheets = _encodeShotSheets(shots);

        return (
          shotsData: _buildShotSheetData(sheets, (sheet) => sheet.dataUri),
          images: sheets.length,
        );
      case AtlasShotSource.sheets:
        await _remoteShots?.ensureCached(shots);

        final sheets = _encodeShotSheets(shots);
        final sheetFiles = {
          for (final sheet in sheets) sheet.fileName: sheet.bytes,
        };

        _writeSheets(sheetFiles, shotsDirectory);

        return (
          shotsData: _buildShotSheetData(
            sheets,
            (sheet) => '${AtlasLocations.shotsDirectory}/${sheet.fileName}',
          ),
          images: sheetFiles.length,
        );
      case AtlasShotSource.urls:
        if (!_paths.hasShotStorage) {
          throw const AtlasException(
            'The shot source urls needs AtlasProject.shotStorage, and the '
            'project returns none.',
          );
        }

        return (shotsData: _buildStorageShotsData(), images: 0);
    }
  }

  Map<String, Object?> _buildStorageShotsData() {
    final remoteShots = _remoteShots;

    return remoteShots == null
        ? const {}
        : {'shotUrlTemplate': remoteShots.urlTemplate};
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
    for (final MapEntry(key: name, value: bytes) in sheetFiles.entries) {
      File(p.join(directory, name))
        ..createSync(recursive: true)
        ..writeAsBytesSync(bytes);
    }
  }

  List<File> _listFiles(String path) {
    return Directory(path).listSync(recursive: true).whereType<File>().toList();
  }

  List<String> _deleteUnreferencedShots(List<AtlasSnapshot> snapshots) {
    final directory = Directory(_paths.shotsPath);

    if (!directory.existsSync()) {
      return const [];
    }

    final referencedFileNames = snapshots
        .expand((snapshot) => snapshot.shots)
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

  List<AtlasTable> _addLocaleKeysTable(
    AtlasEdition edition,
    List<AtlasTable> tables,
  ) {
    if (!edition.has(AtlasPagePart.localeKeys)) {
      return tables;
    }

    final localeKeysTable = AtlasLocaleKeysTable(_paths);

    if (tables.any((table) => table.id == AtlasTable.localeKeysId) ||
        !localeKeysTable.hasKeys) {
      return tables;
    }

    return [localeKeysTable.build(), ...tables];
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
    final descriptions = _paths.readScreenDescriptions();
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
    return !_paths.hasShotStorage &&
        !File(_paths.resolveShotPath(shot)).existsSync();
  }
}

/// {@category Utils}
///
/// The atlas page as its sources make it, and what the write did.
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

  /// Shots a rendered snapshot names that the shots directory does not hold;
  /// empty with a remote shot storage.
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
  /// The page of the bundle, `index.html`.
  final String path;

  /// Bytes of the page.
  final int pageBytes;

  /// Bytes of each file of the bundle: the page and the files in `shots/`.
  final int bundleBytes;

  /// Files of the bundle: the page and the files in `shots/`.
  final int files;

  /// Images the bundle holds: the sheets it inlines or writes as files, or
  /// the shots it copies as files; none for [AtlasShotSource.urls].
  final int images;

  const AtlasBundleRendering({
    required this.path,
    required this.pageBytes,
    required this.bundleBytes,
    required this.files,
    required this.images,
  });

  /// The text that tells a reader about each limit that the bundle passes.
  /// It is `null` while the bundle fits.
  String? tryDescribeOverLimit({
    required int maxBytes,
    required int maxImages,
  }) {
    final messages = [
      if (pageBytes > maxBytes)
        'The page $path takes $pageBytes bytes, over the $maxBytes byte '
            'limit.',
      if (images > maxImages)
        'The bundle $path holds $images images, over the $maxImages image '
            'limit.',
    ];

    return messages.isEmpty ? null : messages.join(' ');
  }
}
