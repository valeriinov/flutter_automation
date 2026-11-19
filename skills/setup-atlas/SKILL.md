---
name: setup-atlas
description: Connect the atlas of the flows to a Flutter app that already has flutter_automation flows. Add the atlas dependency, the AtlasProject file with stubs, the published variants file, the mock replay test, the atlas section of pubspec.yaml and the three Automation fields, then capture one flow and render the page. Safe to run twice. Use for "add the atlas", "set up the atlas", "подключи атлас", "настрой атлас", "підключи атлас".
argument-hint: "[flow to capture first]"
allowed-tools: Bash, Read, Write, Edit, Grep, Glob
---

The atlas shows every flow as a graph of screens, each with a screenshot, a
journal and a design link. This skill connects the `flutter_automation_atlas`
package to a project. The project writes one `AtlasProject` class, one JSON
file, one test file and a few fields. The package holds all other code.

Every step starts with a check of the current state. It changes a file only when
the check fails. A second run changes no file and says so. Never overwrite a real
value: report it.

## 1. Read the fields

Read the `## Automation` section of the project `AGENTS.md`. This skill uses the
fields **Flow run command**, **Launch**, **Flows folder**, **After an edit** and
**Post-edit steps**. It sets the fields **Atlas command**, **Atlas store** and
**Atlas publish**.

- A project with no flows: run the `setup-automation` skill first. In Claude
  Code with the plugin, the name is `flutter-automation:setup-automation`.
- A project with no mock: run the `setup-automation` skill with the mock first.
  The atlas replays the answers of the mock.
- Tell the user the tag from `skills-lock.json` or from the installed plugin
  (`setup-automation` step 1 describes both). Use it for every `ref`.
- A field that is empty or missing: ask the user one question and write the
  answer into the section.

## 2. Add the dependency

Add `flutter_automation_atlas` to `dev_dependencies` in `pubspec.yaml`, in the
form of the other packages (a git dependency with the tag as `ref`, or a `path:`
in a workspace). Run `fvm flutter pub get`. Drop `fvm` when the project has no
`.fvmrc`.

## 3. Write the project files

Read `references/atlas-project-stub.md`. It holds the stubs of the files below.

1. `tool/<project>_atlas_project.dart`: a class that extends
   `AtlasProject`. When `tool/atlas.dart` exists, find the class by the import
   in that file, and edit it.
   - `paths.runnerEntry` is the file that calls `runFlows`. `paths.output`
     equals **Atlas store**.
   - `launchSettings` and `locales` come from the **Launch** field and from
     the `flutter_automation:` section. The first locale is the default. Set
     `launchSettings.commandPrefix` to `['fvm']` when the project has `.fvmrc`.
   - `journalSchema`, `staleSettings` and `headlessSettings` start with the
     smallest values that compile.
   - The class overrides no member that has a default: the tables, the
     translations, the screen descriptions, the design links, the reports,
     the shot publisher and the analytics check. It overrides one only when
     the project has that data.
   - `projectName` is the name the page shows.
   - `groupOrder` and `defaultGroup` follow `references/flow-groups.md` of the
     `atlas` skill. Without a path map, derive the groups from the screens and
     the routes, and propose them to the user before you write them.
   - Each stub carries a short comment that names the value to fill in.
2. `tool/atlas.dart`: one call, `runAtlas(args, <Project>AtlasProject())`.
3. The file that `paths.publishedVariants` names, for example
   `tool/atlas_published_variants.json`: a JSON object that maps a flow name to
   the list of the variant names the page shows. `render` stops when the file is
   missing.
4. The file that `mockReplayEntry` names, for example
   `test/mock_replay_test.dart`. `stale` and `capture` run it with `flutter
   test` to ask the mock of the app again for every answer a snapshot holds. A
   missing replay test stops `stale` with "The mock replay failed" once a
   snapshot holds a mock answer. The test calls `runAtlasMockReplay` of
   `package:flutter_automation_atlas/mock_replay.dart` with the mock sections,
   the mock apis and the journal schema of the project.

`staleSettings.routes` is optional. A project whose router generates no routes
file sets it to `null`. No stage then names route sources. A project with a
routes file sets `routes` to an `AtlasRouteSettings` with `routesPath`,
`routerPath` and `routePattern`.

The `headless` command runs a test harness that the project owns.
`headlessSettings` names its files. The test file imports `entryImports`, takes
the `main` file of the app at `mainPath` with the `mainPatch` replacements as
its body, and ends with `entryMain`. The harness reads the inputs with
`AtlasHeadlessInput.readAll` from the file that the `ATLAS_HEADLESS_INPUT`
define names. It walks the `steps` of each input and writes an
`AtlasHeadlessReport` to its `reportPath`. Keep the stub while the project has
no harness. Say in the report that `headless` and `stale --published` need the
harness first.

## 4. Add the pubspec section

Add `atlas:` under the top-level `flutter_automation:` key of `pubspec.yaml`.
Keep every key that exists.

```yaml
flutter_automation:
  atlas:
    maxBundleBytes: <bytes>
    maxBundleImages: <count>
```

- The limits have no default. Ask the user for them, or take the limit of the
  place where the page goes. A viewer that hosts the page sets its own limits;
  a Claude artifact is one example.
- The editions `full` and `lite` exist without a key. Add `editions:` only to
  change a list or to add an edition. The part names come from the
  `AtlasPagePart` enum of the package. `lite` lists no part with keys,
  requests, translations or the mock scenario.

## 5. Write the fields

Write these three fields into `## Automation`. Replace only a field that is
empty, missing or `none` where the project has a real value.

- **Atlas command**: the command that runs `tool/atlas.dart`, for example
  `fvm dart run tool/atlas.dart`.
- **Atlas store**: one path for the snapshots, the declarations, the
  screenshots and the page, for example `docs/atlas`. A declaration record holds
  the parts of a source file that a snapshot read. Ask the user where it goes.
- **Atlas publish**: the project document that holds the publish procedure, or
  `none`.

## 6. Group the flows

Read `references/flow-groups.md` of the `atlas` skill. Give each flow a group
with an `area`. Propose the groups to the user in one question. Declare one
`groupOrder` constant. Pass it to `AtlasProject.groupOrder` and to
`AutomationRunnerConfig.read().withGroupOrder(...)`.

## 7. Capture and render

1. Run **Atlas command** `stale`. A variant with no snapshot reads `new`.
2. Run **Atlas command** `capture <flow>` for one flow, the one the user names
   or the **Default flow**, only when `stale` prints a line that is not
   `fresh`. The `atlas` skill owns the device rules.
3. Run **Atlas command** `render`, then `bundle --edition lite --shots inline`.
4. Open the page. The flow must show its stages with screenshots.

## 8. Verify

- Run the **After an edit** commands.
- Run **Atlas command** `stale <flow>`. The line must read `fresh`.
- Run the **Post-edit steps**.
- A second run of this skill changes no file. Compare `git status` and `git
  diff` before and after. Say so in the report.
- Say plainly which steps nobody ran, such as the capture on a device.
