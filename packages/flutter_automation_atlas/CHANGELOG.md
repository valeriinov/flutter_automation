# Changelog

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
