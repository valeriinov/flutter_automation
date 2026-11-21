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
| `check` | Runs the six checks of `AtlasChecks`: the page, the published variants, the stored variants, the snapshots, the translation key coverage and the shots. Exits with code 1 when one fails. |
| `normalize-manifests` | Rewrites the manifest hashes of the stored snapshots. |
| `source-commit --snapshot <file>` | Prints the commit `stale` takes as the baseline of the snapshot, or `not found`. |
| `render [--edition <name>]` | Writes `index.html` of the edition (`full` when absent) to the store, with the screenshots in `shots/` beside it. Deletes the screenshots and the declarations that no stored snapshot names, and writes the project reports. A declaration record holds the parts of a source file that a snapshot read. With a remote shot storage, the page reads its screenshots by the link template of the storage, and `render` deletes no screenshot. |
| `bundle --edition <name> --shots <files\|inline\|sheets\|urls> [--locale <code\|all>]` | Writes `index.html` of the edition into a folder of its own under the build folder, one per edition and locale. It first empties `shots/` beside the page. With `inline` or `urls` the page is the only file; `urls` puts the link template of the shot storage into the page and uploads nothing; with `files` the screenshots go to `shots/` beside it; with `sheets` the WebP sheets go to `shots/` beside it. It prints the bytes of the page, the bytes and the files of the whole bundle and its images. |
| `migrate-shots` | Renames each file of the shots folder of the store to the SHA-256 of its bytes and rewrites the `shot` fields of the snapshots. With a remote shot storage, it also puts the files into the storage. |
| `upload-shots` | Puts into the remote shot storage each screenshot file of the shots folder and of the cache folder that the storage does not hold. |
| `delete-shots <id>...` | Removes the named screenshots from the remote shot storage. It removes nothing when a file of the store repository names one of them. |
| `publish-version --site <folder> --version <label> --position <number> --edition <name> [--locale <code\|all>]` | Writes the folder of a version into the site folder, and updates `versions.json`, `atlas-config.json` and the `index.html` of the site folder. It needs a remote shot storage. |
| `open --site <folder> [--version <label>]` | Serves the site folder on `127.0.0.1` at a free port. It prints the address and opens the page of the version in the browser, or the `index.html` of the site folder. It runs until Ctrl+C. |
| `prune [--site <folder>...] [--repo-only \| --storage-only] [--apply]` | Prints what the repository of the store folder and the shot storage hold past their use. With `--apply`, it deletes that. |
| `tag-versions [--site <folder>...]` | Puts on `origin` the git tag of each row of `versions.json` whose folder the branch `origin/main` holds. The field `versionTagTemplate` of `atlas-config.json` gives the name of the tag. |

Every command takes `--store <folder>` and `--source-label <text>`.
`capture` and `stale` take `--locale <code>`.
With a remote shot storage, every command takes `--shots-cache <folder>`, the cache folder.

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
| `files` | `shots/<identifier>.png` beside the page. |
| `inline` | WebP sheets inside the page. |
| `sheets` | WebP sheets as files `shots/<sheet hash>.webp` beside the page, named by the hash of the sheet bytes. The page crops each screenshot from its sheet on a canvas, so the page and `shots/` stand on one http(s) origin. A page opened from disk takes `inline` or `files`. `bundle` deletes every other file and folder in `shots/`. |
| `urls` | The link template of `AtlasProject.shotStorage`, with the screenshot identifier in place of `{shot}`. |

The page takes the link before the sheet, and the sheet before the file.
`--locale all`, or no `--locale`, writes the series of every page locale into
one file.

## Screenshots in a viewer with a strict CSP

A viewer whose CSP blocks an `<img>` from another host needs `inline`, `files`
or `sheets`. A Claude artifact is one example. The `urls` source serves a page
that another host serves.

## Shot storage

A screenshot identifier is the SHA-256 of the PNG bytes, 64 lowercase hex
digits. The identifier names the PNG file and the `shot` field of a snapshot.
`AtlasProject.shotStorage` sets where the PNG files live.

| Mode | `shotStorage` | The PNG files live in |
| --- | --- | --- |
| Folder | `null` (the default) | `<store>/shots/<identifier>.png`, the shots folder of the store. |
| Remote | an `AtlasShotStorage` | The remote storage only. The snapshots name the identifiers. |

`AtlasShotStorage` has four members:

- `urlTemplate` is the public link of a screenshot. It holds `{shot}` in place
  of the identifier.
- `upload(List<AtlasShot>)` puts the shots into the storage.
- `delete(List<String>)` removes the shots that the identifiers name.
- `list()` returns each file that the storage holds as an `AtlasStoredShot`:
  the identifier in `shot` and the upload time in `uploadedAt`. `prune` reads
  it.

In remote mode `capture` puts each new screenshot into the storage before it
writes the snapshot. A failed upload fails that variant and keeps its previous
snapshot.

The atlas reads a screenshot with a public `GET` of the link template. A 2xx or
3xx code means the storage holds the screenshot. The code 404 means it does not.
Another code stops the command.

The commands keep the screenshots that they read and shoot in the cache folder
`shots/` under the build folder. `--shots-cache <folder>` names another cache
folder. With a remote storage, `files`, `inline` and `sheets` read the cache
folder, and read each missing file from the storage.

## Versions

A site folder holds the versions of the atlas. A version is one page of an
edition under a label, such as a release number. `publish-version` writes it.

| Path | Holds |
| --- | --- |
| `<site>/<version>/index.html` | The page without data. Each version from one template has the same bytes. |
| `<site>/<version>/data.json.gz` | The data of the edition, the page meta, the label and the link template of the shot storage, as a gzip of JSON. It names each screenshot by its identifier. |
| `<site>/versions.json` | One row per version in the order of the positions: `version`, `position`, `builtAt` and `sourceLabel`. |
| `<site>/atlas-config.json` | The settings that each version page reads: `shotUrlTemplate`, `keptVersions` and `versionTagTemplate`. |
| `<site>/index.html` | A page that sends the reader to the version with the largest position. |

`publish-version` takes these options:

- `--version <label>` names the version folder. A label is one path segment of
  letters, digits and the characters `.`, `_`, `+` and `-`.
- `--position <number>` is a whole number. It sets the place of the version in
  `versions.json`. The version with the largest position is the latest one.
- `--edition <name>` and `--locale <code|all>` work as they do for `bundle`.
- `--source-label <text>` goes into the row of the version.

The command replaces a folder and a row with the same label. It stops when the
branch `origin/main` of the repository holds the folder of the version: a
published version keeps its bytes. It writes `shotUrlTemplate` into
`atlas-config.json` and keeps each other field of the file.

The page of a version reads `./data.json.gz`, `../atlas-config.json` and
`../versions.json` with `fetch`. It takes the link template from
`atlas-config.json`, so a new `shotUrlTemplate` moves the screenshots of every
version to another host. Without that file, the page takes the template from
`data.json.gz`. The version switch of the page lists the rows of
`versions.json`. A failed read of the data shows an error state.

A browser blocks `fetch` for a page opened from disk. `open` serves the site
folder over HTTP, so the page of a version opens on the computer of the reader.
A page for a reader with no server is a `bundle`.

## Prune

`prune` prints a report. With `--apply`, it deletes what the report names. The
command first runs `git fetch --prune --no-tags origin` in the repository of
the store folder. It then fetches the refspec
`+refs/heads/*:refs/remotes/origin/*`. It stops when a fetch fails or when the
repository has no branch `origin/main`. The storage part stops when no file of
the repository names a screenshot.

`--site <folder>` names a site folder, and the option repeats. Without it, the
command takes each folder `site/<name>/` of the repository that holds an
`atlas-config.json`. `--repo-only` keeps to the repository part, and
`--storage-only` keeps to the storage part.

The repository part reads the retention from the `atlas-config.json` of each
site folder:

| Field | Meaning | Without the field |
| --- | --- | --- |
| `keptVersions` | The count of the latest versions by position that stay. A whole number above zero. | Each version stays. |
| `versionTagTemplate` | The name of the git tag of a version, with `{version}` in place of the label. | Each tag stays. |

- The part deletes, in the working tree, the folder and the `versions.json` row
  of each version past the retention. The project commits that change.
- The part deletes the tag of a version on `origin` and in the repository.
  It does this when `origin/main` held the folder once, and no site folder of
  the repository holds it on the branch or in the working tree.

The storage part reads the needed set of `AtlasShotReferences`: each identifier
that a file of the working tree or of a remote branch names. The set covers the
snapshots, the pages and the `data.json.gz` file of each version folder. The
part deletes each file of `AtlasShotStorage.list()` outside the set that the
storage took more than 7 days ago. A project in folder mode has no storage
part, and the report says so.

## Version tags

`tag-versions` puts on `origin` the git tag of each row of `versions.json`
whose folder the branch `origin/main` holds. It works on each site folder
whose `atlas-config.json` holds `versionTagTemplate`. The command fetches the
branches of `origin` and takes the site folders as `prune` does.

- The tag of a version names the commit of `origin/main` that last added the
  `data.json.gz` file of the version folder.
- The command skips a version whose folder `origin/main` does not hold.
- The command skips a tag that `origin` holds.
- Two site folders with the same template and label give one tag.
- One `git push --atomic` puts the tags on `origin`. The command creates no
  tag in the repository.
- The command refuses a shallow clone: it needs the full history of
  `origin/main`.

The command prints one line `Tagged <tag> at <commit>` per tag and a last line
`Tagged <n> versions`.

## Read the atlas in code

The library exports `AtlasVersions` and `AtlasStoreReader` for a script of the
project.

`AtlasVersions(<site folder>)` reads a site folder:

| Member | Gives |
| --- | --- |
| `read()` | The rows of `versions.json` in the order of the positions, each an `AtlasVersion`. |
| `readKeptVersions()` | The value of `keptVersions`, or `null` without the field. |
| `keepsPosition(position)` | Whether a version with that position is inside the retention of the site folder after its publication. It is `true` without `keptVersions`. With the field, it is `true` when fewer than `keptVersions` rows of `versions.json` have a larger position. |
| `hasVersionTagTemplate` | Whether `atlas-config.json` holds `versionTagTemplate`. |
| `resolveVersionTag(label)` | The name of the git tag of the version, or `null` without `versionTagTemplate`. |
| `tryReadTaggedLabel(tag)` | The label of the version that the tag names, or `null` when the template does not give the tag. |
| `tryReadVersionTagTemplate()` | The field `versionTagTemplate` as an `AtlasVersionTagTemplate`, or `null` without the field. Its `tryResolveLabel(tag)` gives the label of each tag from one read of the file. |

A malformed retention field stops each of these members with an
`AtlasException`.

`AtlasStoreReader.open(project, {rootPath, store})` reads a store folder:

| Member | Gives |
| --- | --- |
| `snapshots()` | Each snapshot of the store folder, in every locale, in the order of flow, variant and locale. An `AtlasSnapshot` holds its `flow`, `variant`, `locale` and `sourceDirty`, its `stages` (`AtlasStage`) and its `end` (`AtlasEnd`). A stage and the end hold the `texts` of their frame. |
| `recordsOf(kind)` | Each journal record of that kind that a published variant logged, in the default locale, with its stage. |
| `walkersByScreen()` | The `<flow> <variant>` of each snapshot in the default locale that walks a screen, by screen name. |
| `rootPath`, `storePath`, `isDefaultStore` | The root of the project, the folder of the store, and whether the store is the output folder of the project. |
