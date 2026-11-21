---
name: atlas
description: Maintain the atlas of the flows of a Flutter app. Capture the variants on a simulator or headless, name what is stale, render the page, bundle the Full or Lite edition and publish the screenshots and the page by the fields of the project. Use for "capture the atlas", "what is stale in the atlas", "render the atlas", "bundle the atlas", "publish the atlas", "обнови атлас", "что устарело в атласе", "опубликуй атлас", "зніми атлас", "що застаріло в атласі".
argument-hint: "[capture | stale | headless | check | render | bundle | publish] [flow]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

The atlas shows every flow of the app as a graph of screens. Each stage has a
screenshot, a journal and a design link. A snapshot holds one variant in one
locale. This skill keeps the snapshots in step with the app and turns them into
a page. The `flutter_automation_atlas` package holds the engine. The project
holds its own facts.

Read the `## Automation` section of the project `AGENTS.md` first. This skill
uses the fields **Atlas command**, **Atlas store** and **Atlas publish**. It
also uses **After an edit** and **Post-edit steps**.

- **Atlas command** is the one command that calls `runAtlas`. The skill appends
  a subcommand and flags to it. Below, `ATLAS` stands for this command.
- **Atlas store** is one path. It is the default of `--store`. Every command
  below uses it, unless **Atlas publish** names a document.
- **Atlas publish** names a project document with the publish procedure, or it
  holds `none`.
- A field that is empty or missing, or **Atlas command** or **Atlas store** that
  holds `none`: run the `setup-atlas` skill. In Claude Code with the plugin, the
  name is `flutter-automation:setup-atlas`.

The menu of the page and the groups of the QA panel follow
`references/flow-groups.md`. Read it before you change a group or add a flow.

## 1. Choose the work

| The request | Run |
| --- | --- |
| the state of the atlas | `stale` (section 2) |
| a fresh atlas after a code change | `capture --stale` (section 3) |
| one flow or variant | `capture <flow> [<variant>...]` (section 3) |
| a check with no device | `headless` (section 4) |
| page, published variants, snapshots and keys agree | `check` (section 4) |
| a page | `render`, then `bundle` (sections 5 and 6) |
| a publication | section 7 |

A capture needs one booted iOS simulator. Load the `drive-device` skill before
you touch the device.

## 2. Read what is stale

```bash
ATLAS stale [<flow>] [--locale <code>] [--store <folder>]
```

Each line names a variant and one reason, or `fresh`. The reasons:

| Line | Meaning |
| --- | --- |
| `new` | the variant has no snapshot |
| `definition` | the steps or the scenario changed |
| `manifest` | the snapshot stores no list of the source files its capture executed |
| `code <paths>` | a file the capture executed changed |
| `stage <kind> <stages>` | only those stages are stale |
| `locale <stages> <keys>` | a translation of a stage changed |
| `failed` | the snapshot holds a walk that did not pass |

`stale` compares content. It holds before a commit. The baseline of a headless
walk is the source commit of the snapshot. When that commit is not an ancestor
of `HEAD`, the baseline is the commit that git history holds for the stage
sources.
`stale --published` keeps to the published variants of the project.
`stale --no-walk` reads the headless reports that exist and walks nothing.

## 3. Capture

```bash
ATLAS capture <flow> [<variant>...]          # the named variants, or the whole flow
ATLAS capture <flow> <variant> --stages 4,5  # only those stages
ATLAS capture --stale                        # what stale names
```

1. Run `stale` first. Name the stale variants to the user.
2. Run the capture. It builds and launches the app itself, with the arguments
   of `AtlasProject.launchSettings`. It restarts the app before each variant.
3. Run `stale` again. Every line must read `fresh`. A `failed` line stops the
   work: fix the walk, then capture again.
4. A full capture of a flow in the QA catalogue also writes the QA recording of the flow.
   A partial capture and a capture in another locale write none.
5. `--locale <code>` stores one snapshot for each variant and locale. The first
   locale of the project is the default.
6. `--store <folder>` writes to another folder. Each snapshot holds the commit
   of the code it came from and a flag for uncommitted edits.

When **Atlas publish** names a document, do not capture into **Atlas store**.
Read the document and run the capture as it says. Its steps decide the folder,
the branch and the checks.

A capture exits with code 1 when a walk failed. Report the failed variant and
its first error. Do not retry in a loop: after three failures name the doubtful
assumption.

A flow that fails with `frameDefect` needs a fix of the walk. A stage that is
meant to show a loading state gets `showsLoading` on the last step before the
user action.

## 4. Check with no device

```bash
ATLAS headless [<flow> [<variant>...]]
ATLAS headless --baseline
ATLAS headless --record
```

`headless` walks the variants under `flutter test`, on the mock, with no
device. `stale --published` and `capture --stale --published` use it to save
device walks. `--record` writes the frame and journal hashes into the fresh
snapshots. A stage whose frame and journal did not change stays fresh.

```bash
ATLAS check [--store <folder>]
```

`check` reads no device. It runs the four checks of `AtlasChecks`: `page` (the
committed page against its sources), `publishedVariants` (the list against the
flow files and the snapshots), `snapshots` (the published snapshots against the
variants) and `localeKeyCoverage` (the translation keys against the frames and
the uncovered keys file of the store). It prints one line per check and exits with code 1
when a check fails.

## 5. Render the page

```bash
ATLAS render [--edition <name>] [--store <folder>]
```

`render` writes the page next to the snapshots, in **Atlas store**. It deletes
the screenshots and the declarations that no stored snapshot names. A declaration
record holds the parts of a source file that a snapshot read. `--edition` takes
`full`, `lite` or a name the project adds under `editions:`. The project lists
the parts of each edition in `flutter_automation: atlas: editions:` of
`pubspec.yaml`.

- **Full** is for the team. It holds all parts the project lists: keys,
  translations, requests, the mock scenario and the journal.
- **Lite** is for people outside the team. It holds the flows, the screens, the
  place of the tap and the description of the logic. It holds no key, no
  request and no scenario.

A part that the edition lacks is missing from the page data and from the search.
To add a part to Lite, add its name to the list and render again.

## 6. Bundle the page

```bash
ATLAS bundle --edition <name> --shots files|inline|sheets|urls --locale <code|all>
```

A bundle is a page `index.html` in a folder of its own for the edition and the
locale. The bundle first deletes every file and folder in `shots/` beside the
page. With `inline` or `urls` the page is the only file. With `files` the
bundle copies the screenshots to `shots/`. With `sheets` the bundle writes the
WebP sheets to `shots/`. The `--shots` value sets where a screenshot comes
from:

| Value | Source of the image | Use |
| --- | --- | --- |
| `files` | `shots/<hash>.png` beside the page | a folder or a site that holds many files |
| `inline` | sheets of WebP in the page | one file with no host |
| `sheets` | `shots/<sheet hash>.webp` beside the page, named by the hash of the sheet bytes and cropped by the page on a canvas | a host that serves the page and `shots/` from one http(s) origin; never a page opened from disk |
| `urls` | a link for each hash, from the project publisher | a page that must stay small |

The limits come from the `atlas:` section of `pubspec.yaml`. `maxBundleBytes`
limits the page. `maxBundleImages` limits the images: the inline sheets, the
sheet files or the shot files. `bundle` prints the bytes of the page, the bytes
and the files of the whole bundle and its images. A bundle over a limit fails
and prints its size. A viewer that takes at most 255 files in one publish takes
`index.html` and 254 images.
`urls` calls the publisher of the project. A publisher error stops the bundle
and prints its text.

A viewer whose CSP blocks an `<img>` from another host needs `inline`, `files`
or `sheets`. Never use `urls` for such a viewer. A Claude artifact is one
example.

`--locale all` puts every locale of the project into one page.

## 7. Publish

1. Read **Atlas publish**.
2. With a document: follow its procedure. It names where the screenshots go,
   where the page goes and which checks gate the publication. This skill adds
   the commands of sections 2 to 6 and adds nothing else.
3. With `none`: run `stale`, then `render`, then `bundle` with `inline` or
   `files`, and give the user the path of the page.
4. Publish only after `stale` prints `fresh` for every line the procedure
   gates. A publication of a stale page is a defect.
5. Name each command and its result in the report.

## 8. After the work

- Run the **After an edit** commands after any Dart edit.
- Run the **Post-edit steps** of the project.
- Report the stale lines before and after, the files changed and the page path.
