# Changelog

## 0.14.0

- Breaking: `AtlasPaths.uncoveredLocaleKeys` is a path relative to the store
  folder, not to the project root. Each store keeps the list of its own
  snapshots, and a `--store` option reads the list of that store. Move the
  list into the store folder and give its path from there.

## 0.13.3

- `AtlasStoreReader.storePath`: the folder of the store, the output folder
  of the project or the one a `--store` option names.

## 0.13.2

- Version bump with `flutter_automation_runner` 0.13.2.

## 0.13.1

- `mock_replay.dart` exports `runAtlasMockReplayFiles`: the replay with the
  paths of the input and the output file, for a test.
- `AtlasDefinition.holdsProbeSeries` reads `AutomationFlow.holdsProbeSeries`.

## 0.13.0

- Breaking: `AtlasProject.tables` and `AtlasProject.writeReports` take an
  `AtlasStoreReader` instead of the store path. `AtlasStoreReader.open` opens
  the store of a project outside `runAtlas`.
- Breaking: `AtlasRunnerCatalogue` is gone. The atlas reads the flows through
  `AutomationFlowCatalogue` of `flutter_automation_runner`.
- New `AtlasProject.localeKeyUsagePattern` and the `AtlasPaths` files
  `translations`, `screenDescriptions` and `uncoveredLocaleKeys`. A missing
  `translations` file of the default locale throws an `AtlasException`.
- New built-in table of the translation keys and its coverage report. The atlas
  builds the table when `tables` returns none with the id
  `AtlasTable.localeKeysId`.
- New `AtlasRequestsTable` and `AtlasDeclaredRequest`, and
  `AtlasTable.stagesData` for a table of the records of each stage.
- New `AtlasChecks` and the `check` command of `runAtlas`: the page, the
  published variants, the snapshots and the translation key coverage.
  `AtlasChecks` takes a `sourceLabel`, and `check --source-label` gives it.
- New library `mock_replay.dart` with `runAtlasMockReplay`,
  `isAtlasMockReplayRun`, `AtlasMockApisBuilder` and the session types. The mock
  replay test of a project calls it with its journal schema and either a
  `session` or its mock `sections` and `apis`. A `session` is an
  `AtlasMockSessionFactory` that builds an `AtlasMockSession` from an
  `AtlasMockSessionContext`. The built-in form asks each endpoint once per input
  and replays the stored responses. A responder that throws fails only its own
  answer: the outcome says `failed:` and the replay goes on. The replay runs the
  pending microtasks after the factory returns. A synchronous throw of
  `AtlasMockSession.ask` counts as a failed answer. The package cleans the
  records of `AtlasMockSession.impliedAnswers` as it cleans the journal.
- New library `headless.dart` with `runAtlasHeadlessSuite`, `AtlasHeadlessApp`,
  `AtlasHeadlessDevice` and `AtlasHeadlessLaunch`: the walk of a headless test.
  The project supplies the app hooks. `AtlasHeadlessLaunch` is not `const`. It
  has `launchedAt`, which the walk sets at creation and `runMain` sets again
  right before `main`. The patched `main` calls `AtlasHeadlessLaunch.runApp`
  in place of `runApp`. The `launch` hook starts `main` with `runMain(tester,
  main, {afterMain})`, which returns the widget that `main` handed to `runApp`.
  A project imports or re-exports `AtlasHeadlessLaunch` in the file that
  `AtlasHeadlessSettings.entryImports` names, because that setting takes
  relative paths.
- New dependencies: `fake_async`, `flutter_test` and
  `flutter_automation_driver`.
- `stale` finds `package_config.json` in the nearest `.dart_tool` folder at or
  above the project root, so a workspace member needs no folder of its own.
- Breaking: `AtlasProject` is an abstract class with defaults. A project
  extends it. `tables`, `translations`, `screenDescriptions`, `designLink`,
  `sourceDirtyIgnores`, `writeReports`, `shotPublisher` and
  `isCataloguedAnalytics` have a body for a project without that data.
- Breaking: `AtlasProject.launch` is `AtlasProject.launchSettings`.
- Breaking: `flutter_automation_atlas.dart` exports only the types a project
  writes: `runAtlas`, `AtlasProject`, the settings, the journal schema, the
  tables, the checks, the store reader, the page parts and the shot source,
  publisher and shot. The engine classes stay internal. The barrel has no
  `AtlasHeadless`, `AtlasHeadlessInput` or `AtlasHeadlessReport`.
- Breaking: `AtlasHeadlessSettings.tryReadRecordedValues` reads any values a
  walk takes from the journal of a snapshot. It returns `null` when the
  records hold none. The `launch` hook finds them in
  `AtlasHeadlessLaunch.recordedValues`. `tryReadUploads`,
  `AtlasHeadlessUpload` and `AtlasHeadlessUploads` are gone.
- `AtlasHeadlessSettings.copiedDirectories` and `entryImports` hold paths
  relative to the project root.
- Breaking: `AtlasSourceHash` takes `AtlasStaleSettings`. The hash skips the
  imports of `automationDirectory` and `targetsDirectory` of the project. The
  stored manifest hashes of a project change when it imports these folders.
  `AtlasLocations.sourceHash` gives the hash of a project.
- Breaking: `normalize-manifests` reads no legacy hash.
  `AtlasSourceHash.hashLegacySource` is gone.
- Breaking: a flow is a probe series when a variant holds a `probeSeries`
  step, not by the suffix of its name. `AtlasDefinitions.read` takes no
  `includeProbeSeries`, and `AtlasDefinition.isProbeSeries` is
  `holdsProbeSeries`.
- Breaking: the page data lists `areas`, and each area holds its `groups`.
- Breaking: `AtlasBundleRendering` gives `pageBytes`, `bundleBytes`, `files`
  and `images`. `bundle` prints the bytes of the page and the bytes and the
  files of the whole bundle. `maxBundleBytes` limits the page.
  `maxBundleImages` also counts the shot files of a `files` bundle.
- `bundle` deletes every file and folder in `shots/` beside the page first, for
  every source.
- The page hides its footer when the footer has no text.
- The page reads no `artifactUrl` or `artifactUrls`.
- A run report whose end frame failed builds its snapshot: the step of the end
  frame opens no stage.
- `AtlasLocations.shotsDirectory` and `AtlasShotSheet.fileExtension` name the
  shots folder and the sheet extension once.
- Breaking: the page data stores its repeated long strings through
  `CatalogueBlobs` of `flutter_automation_mock`. `AtlasPageBlobs` is gone.

## 0.12.0

- Version bump with `flutter_automation_runner` 0.12.0.

## 0.11.0

- New screenshot source `sheets`. `bundle --shots sheets` writes the WebP sheets
  as files `shots/<sheet hash>.webp` beside the page, named by the hash of the
  sheet bytes. The page crops each screenshot from its sheet. `bundle` deletes
  every other file and folder in `shots/`. A host serves the page together with
  its files.
- `maxBundleImages` limits the images of a bundle, inline or as sheet files.
  `maxBundleBytes` limits the bundle page.
- Breaking: `AtlasShotSheet` takes the WebP `bytes` of the sheet instead of
  `dataUri`. It gives `dataUri` and `fileName` as getters.
- Breaking: `AtlasPageRenderer` takes `clock` instead of `command`. The page
  footer shows the source label and, on a bundle page, the build date in the
  page language.
- Breaking: a bundle page is `index.html` in a folder of its own for each
  edition and locale under the build folder: `bundle.<edition>[.<locale>]/`.
- Breaking: `AtlasPageRenderer` has no `const` constructor.
- Fix: the page shows the switch of the shot series on every variant that holds
  the series of another locale, the default locale included.

## 0.10.0

- New package. It is the atlas engine of an automation flow project. `runAtlas`
  has the commands `capture`, `stale`, `headless`, `normalize-manifests`,
  `source-commit`, `render` and `bundle`. A project implements `AtlasProject`
  and passes it to `runAtlas`.
- `--store <folder>` sets the folder of the snapshots, the declarations and the
  screenshots. `--source-label <text>` sets the label of the source.
- `render` and `bundle` write the page. The page takes the style of
  flutter_automation. The project name is the page title and the prefix of its
  browser keys. The page lists its flows under an Area switcher.
- An edition is a named list of `AtlasPagePart`s in
  `flutter_automation: atlas: editions:`. `full` holds every part. `lite` holds
  the flows and the screen descriptions.
- A screenshot comes from `files`, from `inline` WebP sheets or from `urls`
  that `AtlasShotPublisher` returns. `maxBundleBytes` and `maxBundleImages` of
  `flutter_automation: atlas:` have no default.
- `render` deletes the screenshots and the declarations that no stored snapshot
  names.
- `AtlasStaleSettings.routes` is optional. A project with no routes file leaves
  it `null`.
- `AtlasLaunchSettings.commandPrefix` holds the words put before `flutter` and
  `dart` in every command the atlas starts, such as `['fvm']`. Every headless
  comparison reads the Flutter version with `flutter --version --machine` run
  with that prefix. `headless --baseline` copies `.fvmrc` into the baseline
  worktree when the file exists.
- Each snapshot records `sourceCommit` and `sourceDirty`. The headless
  baseline takes `sourceCommit` while it is an ancestor of `HEAD`. Otherwise it
  searches the first-parent commits of `HEAD` for the commit that holds every
  stage source as recorded. `source-commit --snapshot <file>` prints that
  commit.
- A full capture of a variant of a flow in the QA catalogue, in the default
  locale, runs the runner with `--record <paths.recordings>`.
