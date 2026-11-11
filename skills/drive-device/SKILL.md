---
name: drive-device
description: Drive the Flutter app yourself on a phone attached by cable, an Android emulator or an iOS simulator. Pick and boot the device, launch with Flutter Driver, tap, scroll and type through a flow, read runtime errors, take screenshots and video. Use for "run it on the simulator", "run it on the emulator", "walk the flow yourself", "reproduce the bug on a device", "запусти на симуляторе", "запусти на эмуляторе", "пройди флоу сам", "воспроизведи баг на девайсе", "запусти на симуляторі", "відтвори баг на пристрої", or any request to see or debug behaviour in the running app instead of in tests.
argument-hint: "<the flow or bug to walk through>"
allowed-tools: Bash, Read, Grep, Glob, mcp__dart__dtd, mcp__dart__widget_inspector, mcp__dart__flutter_driver_command, mcp__dart__get_runtime_errors, mcp__dart__hot_reload, mcp__dart__hot_restart
---

You drive the app. The user is not your hands. Asking the user to tap is a
fallback with two legitimate uses (see *The two manual steps*). Every other tap
is yours.

Read the `## Automation` section of the project `AGENTS.md` first. This skill
uses the fields **Launch**, **Targets folder**, **Mock configuration file**,
**After an edit** and **Learned rules** (bold names). A missing field: ask the user once and write the
answer into the section.

The driver commands of steps 3 to 5 are the same on both platforms: Flutter
Driver talks to the Dart VM, not to the OS. Booting, launching, native surfaces
and observation differ, and each of those steps carries both command sets.

## 1. Pick a device

A phone attached by cable comes first. An emulator or a simulator comes second.
A device over the network comes last, or when the user names it. Wireless
debugging puts a hop in front of every driver command and drops the connection
in the middle of a walk.

```shell
adb devices -l
```

| The line | What it is |
| --- | --- |
| carries `usb:<address>` | a phone on a cable: take this one |
| serial `emulator-<port>` | an emulator: the fallback |
| neither | a device over the network: last |

On iOS the same split is `xcrun devicectl list devices` against
`xcrun simctl list devices booted`. A physical iPhone needs signing, so the
simulator is the ordinary choice.

Boot the fallback only when no cable line answers:

```shell
# Android
fvm flutter emulators                  # pick an id it lists
fvm flutter emulators --launch <id>
adb wait-for-device shell getprop sys.boot_completed   # prints 1 when ready

# iOS
xcrun simctl list devices available    # pick a UDID
xcrun simctl boot <udid>               # already booted is not an error
open -a Simulator
```

Use `fvm flutter devices` for the id that `-d` takes. Every `adb` command takes
`-s <serial>` as soon as more than one device answers. Drop `fvm` when the
project does not use it.

A cabled phone that sleeps stays `mWakefulness=Dozing`. Every driver command
then times out on a screen nobody woke. `adb devices` proves the cable, not the
display. Read `adb -s <serial> shell dumpsys power | grep mWakefulness` before
the launch. Anything but `Awake` is one of the two things you can hand over.

## 2. Launch

```shell
fvm flutter run --debug -d <device-id> <Launch>
```

**Launch** holds the flavor, the entry point and the defines of the project. It
must include `--dart-define=ENABLE_FLUTTER_DRIVER=true`.

Run it detached and keep the log path: the log is the console. A foreground
command that waits for the build holds the session still. A background command
dies when its own timeout expires, and a `flutter run` killed that way leaves
the app on the device and takes `hotRestart` with it. Start it in a session of its
own so it outlives the shell: `subprocess.Popen(..., start_new_session=True)`
does it. `nohup` plus `disown` does not, and macOS has no `setsid`. Give the
Popen `stdin=PIPE`. `flutter run` reads key commands from it, so a hot restart is
one byte, and the Dart MCP `hot_restart` is not the only channel. The pipe stays
open only while the process that holds its write end lives. Keep the launcher
running in the new session, reading a FIFO line by line into the pipe, and send
a restart with `echo R > <fifo>`. Check that the pid is alive before a long walk.
Let the driver be the wait: `get_health` answers once the extension is up.

An install on a phone with Play Protect can stop at `Installing …apk...` for
good. The device asks `Send app for a security check?`, `adb install` waits for
the answer and `flutter run` prints nothing. `adb shell dumpsys window | grep
mCurrentFocus` naming `PlayProtectDialogsActivity` is the sign. The dialog is a
native surface (step 6): dump it and tap `Don't send`. `Send this time` uploads
the build to Google. A sweep that resets the app between runs relaunches the
installed app instead of reinstalling it.

A fresh install raises system dialogs at launch. A Flutter Driver tap goes to the
Flutter tree, not the screen, so it goes through such a dialog. A permission
request sent while a permission dialog is up fails at once with
`ERROR_ALREADY_REQUESTING_PERMISSIONS`. That is a walk defect, not an app
defect. Answer the launch dialogs first. An install grants no runtime
permission: grant it before the walk with `adb shell pm grant <package>
android.permission.<NAME>`. A relaunch without a reinstall keeps the grant.

On the iOS simulator, an App Tracking Transparency alert that nobody answered
stays after `xcrun simctl uninstall`. Answer it, or reboot the simulator, before
a run that watches when the alert comes up.

A fresh install starts in the language of the device. On Android the app
language stands in for the device language: `adb shell pm clear <package>`, then
`adb shell cmd locale set-app-locales <package> --locales <code>`, then launch.
`--locales ""` gives the language back to the system.

A debug build can show an in-app overlay, such as a logger button, over the
screen. A driver tap lands on the centre of its target, so a target that the
overlay covers takes no tap, and the step times out. Hide the overlay before the
walk, with driver taps and not `adb shell input tap`, which is too slow for a
multi-tap window.

Swap `--debug` for `--profile` when a bug renders as it does in release. The
defines survive a profile build.

`ENABLE_FLUTTER_DRIVER` makes the app drivable. Without it, every driver command
fails and the automation ids are absent from the tree.
`ENABLE_AUTOMATION_SEMANTICS=false` drops the semantics tree. Use it for a frame
statistics walk only: production never pays for that pass. The native finders
(AXe, `uiautomator dump`) read their ids from that tree, so a walk that reads a
screen dump keeps the default. `ENABLE_AUTOMATION_FRAME_PROFILING=true` makes a
frame summary name the widgets that a wide frame stood in. The spans cost what
they measure, so read such a run for the shares between rows and take a baseline
with it off. `MARK_LOCALE_KEYS=true` ends each translation string in an
invisible mark of its locale key. A hand launch leaves it out and drives with
`ByText` as the copy reads. The flow runner sends `ByText` as a finder that
matches the copy with its marks stripped in either build.

A toast lives about two seconds. Read its text right after the action that raised
it. A `--capture` run reads the texts of the frame before every action. By hand,
the `journal.read` command with `"texts": true` answers them and empties the
journal, so read it once per frame.

## 3. Connect

`dtd listDtdUris`, then `connect`, then `listConnectedApps`. Pass `appUri`
explicitly when more than one app is connected.

The driver extension does not live forever. After a long session of hot
restarts it stops answering, `flutter_driver` reports "taking a long time to
become available" and every connect burns 20 seconds. The cure is a relaunch,
not another restart. Before a long sweep, prove drivability with one short flow.
Three refusals in a row mean a dead extension, not three failing variants.

## 4. Walk a flow

A journey that is already written down walks in one command, not one turn per
tap. The `run-flow` skill owns that walk (in Claude Code with the plugin:
`flutter-automation:run-flow`). It does not repeat here.

Drive by hand to reach a state no variant covers, to find why a step started to
fail, or to work out the walk of a new variant. Then leave the variant behind,
so the next walk costs one command. A walk that also records what the app did at
each step is a `run-flow` run with `--capture <dir>`.

What the device teaches about walking:

- **Restart before every repeated walk, a flow run included.** A mock scenario
  re-seeds the backend and leaves the route stack where the last walk parked it.
  The restart drops what the last walk wrote and unparks the app after a walk
  that stopped inside a pushed route. Skipping it works until the walk writes
  something the app counts, such as a creation limit. The walk that reaches the
  limit parks the app there, and every later walk dies on its first step.
- **A state the app reads on start is reached by a launch, never by taps.** A
  signed-out launch and a launch by a link or a push are keys of a mock scenario.
  Walk a variant that starts where you need to be.
- **A row under a pinned header is reached with `scroll`, not
  `scrollIntoView`.** `ensureVisible` aligns the row to the top of the viewport,
  where the pinned header covers it. A drag of a few hundred points on the screen
  root brings the row into the open. The same drag reaches a field that the
  sliver has not built yet.
- **Bookend a walk with `waitFor`** on the screen it starts from and on the
  screen it returns to. The opening one turns "the device was left somewhere
  else" into a named failure. The closing one makes a walk that parks the app
  fail itself.
- **A drag-and-drop reorder is a `scroll` slow enough that its first 500 ms stay
  inside the 18 px touch slop.** `ReorderableDelayedDragStartListener` starts the
  drag on a long-press timer. It drops the gesture if the finger leaves the slop
  first. A `dy` of -70 over 3000 ms clears both bounds. Flutter reports a downward
  drop as `newIndex = oldIndex + 2`, so move a row up. A `ProbeCenter` on each
  side of the scroll proves that the row moved.

A burst of `ProbeCenter` steps measures an **animation** and replaces video for
anything the app itself can name. Send the driver command `set_frame_sync` with
`enabled: false` first. With frame sync on, `tap` returns only after frames
settle, so the curve is over before the first probe. With it off, 70 probe pairs
walk a 350 ms curve in about two seconds and answer in logical points. Walk the
`dy` series with a 0.01 pt threshold and report the worst step with the probe
interval that paid for it. A flow writes that burst as one `ProbeSeries` step per
phase. The step cycles its nodes until its own duration has elapsed. A node that
the movement brings on screen joins with a delay.

`ProbeCenter` reads the centre of what it finds. A probe on an element that
resizes while it moves states two motions at once. Measure the edge that the
content is held against, and take the heights from the id dump, which states the
frame, not the centre.

A traced window (`TraceStart` and `TraceStop`) measures frames over the same
walk. It carries no probes, so geometry and frames are measured in separate runs.
The raster numbers of an Android emulator are the host GPU emulation. Read them
against the earlier runs of that emulator, never against a phone.

## 5. Address widgets

Read the **Targets folder** first. It holds one enum per flow, and reading it is
cheaper than dumping a tree. Then call `flutter_driver_command tap` with
`finderType: ByValueKey` and the `id` of the target.

An id reads `<scope>.<type>.<name>`. The middle segment tells what the element
takes:

- `button`: a tap. `field`: typed text. `toggle`: a two-state switch.
- `tab`: a section change. `chip`: a narrowed list. `tile`: a row that opens an
  entity.
- `screen`: the root of a screen. `sheet`: a surface that covers the one below.
- `panel`: an area whose bounds are the answer. `label`: a line of copy to read or
  measure.

For everything else, run `widget_inspector get_widget_tree` with
`summaryOnly: true` and use the real text or type you see. Never guess a finder.

A finder you assembled by hand (a `Descendant` chain, a `ByType`, a piece of copy)
marks a missing target. Stop driving, cover the flow with `add-automation-targets`
and address the element by its id. One id feeds three finders: the driver
`ByValueKey`, `resource-id` in an Android `uiautomator dump`, and the
accessibility identifier that AXe reports on iOS.

Walk a flow as `tap`, then `waitFor` on the root of the next screen, both with a
4000 ms timeout. That pair is deterministic: no sleep, no screenshot, no polling.
A tab shell that keeps every tab mounted exposes every tab root at once. Ask the
id dump which one shows (step 7).

**One action costs two calls.** `waitFor` returns the moment the widget appears,
so it is the wait and the proof that the tap worked. Three things break the
budget:

- `sleep` as a wait. It returns before the frame or burns seconds after it. Use
  `sleep` only for a stopwatch you run on purpose.
- A screenshot to find out where you are. Step 7 ranks what answers that, and an
  image is the last rung.
- Reading a `.png` back into the conversation. Every image stays in context and
  slows every turn after it.

`enter_text` writes into the focused editable. Tap the field first, then call
`enter_text` with no finder. A finder on `enter_text` does not focus the field. A
search field then holds the query as its own text, so a `ByText` finder on the
full name matches the result and the field. Search by a prefix.

**One driver command per turn.** The extension is not re-entrant. Two
`flutter_driver_command` calls at once answer `Guarded function conflict`, and
only the loser reports it. The winner already ran, so the tree moved under the
command you are about to retry.

**A `tap` timeout is not a failed tap.** The driver waits for frames to settle
after the pointer lands. A tap that pushes an animated route can therefore time
out after it worked. Never re-tap on a timeout, because it double-fires. Dump the ids
and read where you are.

A hot restart tears the driver extension down. Every command then answers
`Unknown method "ext.flutter.driver"`. A second `hot_restart` reinstalls it only
some of the time. Reconnecting DTD never does, because the app registers the
extension, not the daemon. `<vm-http-uri>/getIsolate?isolateId=<main>` lists
`ext.flutter.driver` under `extensionRPCs` while the driver is installed. If it
is absent after the second restart, relaunch instead of restarting a third time.

An element that renders in two variants needs the id on both. A navigation bar
mounts one icon at a time, and an id on the unselected one vanishes when the tab
is selected.

## 6. Native surfaces

Flutter Driver sees the Flutter tree only. Web sign-in sheets, permission
dialogs, the system keyboard and share sheets are native.

The software keyboard does not rise while text entry emulation is on, and that is
the default once the driver extension is registered. The driver installs a
`TestTextInput` that answers the engine, so the engine never asks the OS for a
keyboard. Send `set_text_entry_emulation` with `enabled: false` before the tap,
and the OS keyboard rises on both platforms. The driver `enterText` fails while
emulation is off, so type with emulation on and turn it off again. A hot restart
restores the default, so send the flag again after every restart, as with
`set_frame_sync`. On the iOS simulator a keyboard also needs the
`AutomaticMinimizationEnabled` preference set to `NO`, because a simulator that
has seen a hardware keyboard minimizes its software keyboard. The runner flag
`--system-keyboard` walks a flow with the keyboard up.

A driver tap lands through a risen keyboard on whatever widget stands under it.
No user can make that touch. Close the keyboard before you tap what it covers.

**iOS.** AXe ships in the XcodeBuildMCP bundle. Call it through a project script
when the project has one. Never call it by a path that contains a cache directory.
That directory is renamed on every reinstall, and a command with such a path
matches no permission rule.

```shell
axe describe-ui --udid <udid>          # every node with its frame and id
axe tap -x <x> -y <y> --udid <udid>
axe type "<text>" --udid <udid>
```

Frames are in points and match the coordinates of a tap. A screenshot is in
pixels and does not. Take numbers from the dump, never from an image. A physical
iPhone has no AXe. iPhone Mirroring on the Mac shows its screen in a window that a
desktop-control tool can read and tap.

A slow drag reorders a list. The item needs a 500 ms hold. A finger that moves
further than the touch slop before that reads as a scroll. Six seconds across 60
steps keeps the start of the movement inside the slop. A handle
that is a bare icon has no semantics, so no dump holds its frame. Measure from the
labelled control beside it.

**Android.** `adb`, with no extra tooling:

```shell
adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml
adb shell input tap <x> <y>
adb shell input text '<text>'          # no spaces; use %s for a space
adb shell input swipe <x1> <y1> <x2> <y2> <ms>
```

`uiautomator dump` gives `bounds="[l,t][r,b]"` in **pixels**, the unit that
`input tap` takes. The centre is `((l+r)/2, (t+b)/2)`.

The rest of the device is the platform command line.
`xcrun simctl openurl booted <uri>` and
`adb shell am start -a android.intent.action.VIEW -d '<uri>'` open a deep link.
`xcrun simctl privacy` and `adb shell pm grant` set a permission.
`xcrun simctl status_bar` cleans an iOS screenshot.

## 7. Observe after every action

Climb this ladder and stop at the rung that answers the question. A screenshot
costs 650 KB that stays in context. The id dump answers "where am I, what can I
touch, what covers it" in a few hundred bytes.

1. **Id dump**: the default. The `*.screen.root` line names the screen. The rest
   names everything addressable. A `*.sheet.*` line is why a tap resolves and does
   nothing. A modal drops everything beneath it from the native tree, so a dump
   that holds only that line means the screen below is unreachable, not that its
   targets are missing. A `*.panel.*` line is an area to measure.

   ```shell
   # Android
   adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml \
     | tr '>' '>\n' | grep -o 'resource-id="[a-z_]*\.[a-z]*\.[a-zA-Z]*"' | sort -u

   # iOS: AXe describe-ui, filtered to the lines that carry an AXUniqueId
   axe describe-ui --udid <udid>
   ```

   Do not use `snapshot_ui` here: it reports labels only, so every id column
   comes back empty.

   A dump that holds the ids of another app means a tap opened an external URL
   and the OS moved focus. `adb shell dumpsys window | grep mCurrentFocus` names
   the foreground activity, and `adb shell monkey -p <package> -c
   android.intent.category.LAUNCHER 1` brings the app back.
2. **Labels from the same dump**: `grep -oE 'content-desc="[^"]{3,40}"'` names an
   unmarked screen without an image.
3. **`get_runtime_errors`**: after every step, not when a screenshot looks wrong.
   An exception explains a symptom that pixels only describe.
4. **The background run log**: build failures, `print`, framework warnings.
5. **Screenshot**: `flutter_driver_command screenshot`,
   `xcrun simctl io booted screenshot <absolute path>` or
   `adb exec-out screencap -p > shot.png`. Use it only for a visual question:
   layout, colour, overlap, an artefact. Never use it to find which screen shows.

What a run left on the device is a question that no screen answers. The data
directory answers it: `adb shell run-as <package> ls -la /data/data/<package>/{shared_prefs,app_flutter,files}`
on a debuggable build, and `xcrun simctl get_app_container booted <bundle id> data`
on iOS. The modification times separate what this run wrote from an earlier run.

Beyond the ladder: `adb logcat` and
`xcrun simctl spawn booted log stream --predicate 'process == "Runner"'` for
native lifecycle, and `xcrun simctl io booted recordVideo "<absolute path>.mp4"`
or `adb shell screenrecord /sdcard/v.mp4` for animation.

`simctl io` resolves the output path in the simulator service, so it refuses a
relative path. `recordVideo` then fails with `Error Domain=SimRenderServer`
`Code=2`, which reads as a dead render server. A file written to an absolute path
proves the render server is alive. A real Code=2 is an idle display that put the
render server to sleep. `caffeinate -dimsu` in front of the command prevents it.

The simulator recorder writes about 26 fps, so a 350 ms transition gets nine
frames and reads as a jump. Slow the app, not the capture:

```shell
curl -s "<vm-http-uri>/ext.flutter.timeDilation?isolateId=<main>&timeDilation=2.0"
```

Take the isolate id from `<vm-http-uri>/getVM`. Reset the factor to `1.0` before a
recording that ships. A mock that answers on a real timer can outrun a flow
`waitFor` at a high factor, so keep it small.

Read frames as numbers. A row-brightness profile is one byte per row per frame:
`ffmpeg -vf "fps=60,format=gray,scale=1:<height>:flags=area" -f rawvideo`. A shift
that such a profile reports is the best match of a correlator, not a distance. A
strip of repeating rows offers several equal matches. Three readings mean that the
match failed:

- a step larger than the whole movement, or at the edge of the search window;
- the same frame reported by two strips one repeat apart;
- one value repeated to the tenth of a point over five frames, at a speed that
  nothing can hold.

Exclude a bottom sheet and a route transition from a strip. Budget a shift against
the curve over the time since the movement began, not against its steepest
single-frame slope. Stretch the duration by the time dilation of the capture.

## The two manual steps

Unlocking a cabled phone and signing in are the only things you can hand over. A
phone that answers anything but `mWakefulness=Awake` is out of reach of adb. Ask
in one line for an unlock. Then the walk is yours.

Sign-in is the other step. When a login screen needs an account, accept what the
screen asks first, then read the native sheet. If the web session of the device
already holds an account, finish the flow yourself. Ask the user to sign in once
only when it holds none. The session then survives restarts. A walk against a
mock scenario seeds its own session and needs no sign-in.

## Reading what you see

- Reproduce through the **real** chain, never a shortened trigger. A trigger that
  reaches the symptom skips the side effects that cause it.
- A flat grey rectangle in a non-debug build is `ErrorWidget`. Its size is the
  slot of the failed subtree and means nothing alone.
- One defect wears two faces: a red screen in debug, a grey block in profile and
  release. Check both builds before you decide that a fix worked.
- State what you observed. A flow you drove and a flow you reasoned about are
  different claims.

## Write down what you learned

A device teaches by costing a timeout. Before the session ends, write the finding
into the document that **Learned rules** names. One sentence, true now.

A finding earns a line when it is:

- how to reach a flow start state: the scenario, the deep link, the gates on the
  way in;
- a command that fails or hangs for a reason the obvious explanation misses;
- a surface that the driver cannot reach, and what does reach it;
- an assumption that the device disproved, written as the corrected fact;
- a cheaper way to answer a question that you answered at a high price.

A route through a flow, written as a list of ids, is not a finding. The target
enums hold every id. A hand-assembled finder is not a finding either: it names a
missing target, and the flow enum is where it goes.

A finding about marking widgets goes to the learned-rules document under the
marking heading, and the work follows `add-automation-targets`. A finding about a
variant, a scenario or the run loop follows `run-flow`. Never write a finding into
this skill: the skill is installed from the package, and a local edit is lost on
the next update.

## Verify

Run the **After an edit** commands for any file you edited. A widget you marked
with an id keeps its regression test green.
