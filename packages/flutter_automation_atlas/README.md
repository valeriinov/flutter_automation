# flutter_automation_atlas

The atlas shows the screens that each automation flow walks. It holds one
snapshot per flow variant. Each stage of a snapshot has a screenshot, a journal
and a design link. The package keeps the atlas in step with the app.

## Use

A project extends `AtlasProject` and calls `runAtlas` from its own file:

```dart
Future<void> main(List<String> args) {
  return runAtlas(args, MyAtlasProject());
}
```

`AtlasProject` names what the engine cannot know. It names the paths, the launch
settings and the journal schema. It also names the stale and headless settings,
the locales and the groups. The tables, the translations, the screen
descriptions, the design links, the reports, the shot publisher and the
analytics check have defaults for a project without that data.
`AtlasStaleSettings.routes` is optional: a project with no routes file leaves it
`null`.

The library `flutter_automation_atlas.dart` gives the types a project writes.
The library `mock_replay.dart` gives `runAtlasMockReplay`, the body of the mock
replay test, and `AtlasMockSession`, the mock of a project as a replay asks it
again.
The library `headless.dart` gives `runAtlasHeadlessSuite`, the body of the
headless walk, and `AtlasHeadlessApp`, `AtlasHeadlessDevice` and
`AtlasHeadlessLaunch`, which hold what only the app knows.

## Commands

| Command | Does |
| --- | --- |
| `capture <flow> [<variant>...]` | Walks the variants on the booted iOS simulator and writes their snapshots and screenshots. |
| `capture --stale` | Captures what `stale` names. |
| `stale [<flow>]` | Prints one line per variant: `fresh`, or the reason the snapshot is stale. |
| `headless [<flow> [<variant>...]]` | Walks the variants under `flutter test`, without a device, and writes the frame hashes. |
| `check` | Runs the four checks of `AtlasChecks`: the page, the published variants, the snapshots and the translation key coverage. Exits with code 1 when one fails. |
| `normalize-manifests` | Rewrites the manifest hashes of the stored snapshots. |
| `source-commit --snapshot <file>` | Prints the commit `stale` takes as the baseline of the snapshot, or `not found`. |
| `render [--edition <name>]` | Writes `index.html` of the edition (`full` when absent) to the store, with the screenshots in `shots/` beside it. Deletes the screenshots and the declarations that no stored snapshot names, and writes the project reports. A declaration record holds the parts of a source file that a snapshot read. |
| `bundle --edition <name> --shots <files\|inline\|sheets\|urls> [--locale <code\|all>]` | Writes `index.html` of the edition into a folder of its own under the build folder, one per edition and locale. It first empties `shots/` beside the page. With `inline` or `urls` the page is the only file; with `files` the screenshots go to `shots/` beside it; with `sheets` the WebP sheets go to `shots/` beside it. It prints the bytes of the page, the bytes and the files of the whole bundle and its images. |

Every command takes `--store <folder>` and `--source-label <text>`.
`capture` and `stale` take `--locale <code>`.

## Editions

An edition is a named list of page parts. The `full` edition holds every
`AtlasPagePart`. The `lite` edition holds `flowStages` and
`screenDescriptions`. The project replaces either list, or adds one, in its
`pubspec.yaml`:

```yaml
flutter_automation:
  atlas:
    maxBundleBytes: 15728640
    maxBundleImages: 254
    editions:
      lite: [flowStages, screenDescriptions, designLinks]
```

The renderer puts into the page data, and into its search, only the parts of
the edition. The page hides every section that has no data.

`bundle` needs both limits and has no default for them: a missing limit stops
the command with the name of its key. A bundle over a limit stops the command
with its size. `maxBundleBytes` limits the page, `index.html`.
`maxBundleImages` limits the images of a bundle: the inline sheets, the sheet
files or the shot files. A viewer that takes at most 255 files in one publish
takes `index.html` and 254 images.

## Screenshot sources

| Source | The page reads a screenshot from |
| --- | --- |
| `files` | `shots/<hash>.png` beside the page. |
| `inline` | WebP sheets inside the page. |
| `sheets` | WebP sheets as files `shots/<sheet hash>.webp` beside the page, named by the hash of the sheet bytes. The page crops each screenshot from its sheet on a canvas, so the page and `shots/` stand on one http(s) origin. A page opened from disk takes `inline` or `files`. `bundle` deletes every other file and folder in `shots/`. |
| `urls` | The link `AtlasProject.shotPublisher` returns for the screenshot hash. |

The page takes the link before the sheet, and the sheet before the file.
`--locale all`, or no `--locale`, writes the series of every page locale into
one file.

## Screenshots in a viewer with a strict CSP

A viewer whose CSP blocks an `<img>` from another host needs `inline`, `files`
or `sheets`. A Claude artifact is one example. The `urls` source serves a page
that another host serves.
