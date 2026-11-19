# Changelog

## 0.12.1

- Breaking: `AtlasProject` is an abstract class with defaults. A project
  extends it. `tables`, `translations`, `screenDescriptions`, `designLink`,
  `sourceDirtyIgnores`, `writeReports`, `shotPublisher` and
  `isCataloguedAnalytics` have a body for a project without that data.
- Breaking: `AtlasProject.launch` is `AtlasProject.launchSettings`.
- Breaking: `flutter_automation_atlas.dart` exports only the types a project
  writes: `runAtlas`, `AtlasProject`, the settings, the journal schema, the
  headless input and report, the tables, the page parts and the shot source,
  publisher and shot. The engine classes stay internal.
- New library `mock_replay.dart` with `runAtlasMockReplay`. The mock replay
  test of a project calls it with its mock sections, its mock apis and its
  journal schema. The package depends on `flutter_automation_mock`.
- Breaking: `AtlasHeadlessSettings.tryReadRecordedValues` reads any values a
  walk takes from the journal of a snapshot. The walk finds them in
  `AtlasHeadlessInput.recordedValues`. `tryReadUploads`,
  `AtlasHeadlessUpload` and `AtlasHeadlessUploads` are gone.
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
