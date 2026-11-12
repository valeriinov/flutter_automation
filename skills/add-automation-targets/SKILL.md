---
name: add-automation-targets
description: Cover a flow with UI automation targets. Collect its interactive elements, declare the ones a text finder cannot reach in a target enum, and mark them with automationTarget(). Use for "cover the flow with automation ids", "add automation targets", "make the screen drivable", "покрой флоу семантикой", "добавь automation id", "сделай экран драйвабельным", "покрий флоу таргетами", "зроби екран керованим", or before you drive or write a flow for a screen that has no targets yet.
argument-hint: "<flow directory or screen path>"
allowed-tools: Bash, Read, Edit, Write, Grep, Glob
---

Cover one flow at a time. The goal is not "an id on everything". An id that
duplicates what a text finder already reaches is dead weight that the next reader
must check. The target count grows only where the tree cannot be addressed as it
is.

Read the `## Automation` section of the project `AGENTS.md` first. This skill
uses the fields **Targets folder**, **After an edit**, **Post-edit steps**,
**Format-change places** and **Learned rules** (bold names). A missing field: ask
the user once and write the answer into the section.

Two skills consume the result: `drive-device` addresses the ids by hand, and
`run-flow` writes them into the steps of a flow variant. In Claude Code with the
plugin, the names are `flutter-automation:drive-device` and
`flutter-automation:run-flow`.

## 1. Collect the elements of the flow

Take the path you were given as the flow root: a screen directory, or the feature
directory that holds several screens. Read every widget file under it and the
shared widgets it composes.

```shell
grep -rn "onPressed\|onTap\|onChanged\|onSubmitted" <flow root>
```

List what a user can act on: buttons, text fields, checkboxes, switches, radio
groups, tabs, tappable cards and tiles, bottom-sheet actions. Note the screen
root and every modal that the flow opens. Those always earn a target.

## 2. Keep only what needs a target

An element that accepts typed text always gets a `field` target. A driver reaches
it by id alone. The copy around it is a heading or a placeholder, and `ByType`
holds only until the screen grows a second field of the same class.

Every other control that a flow acts on gets a target too. An id survives a copy
edit, a translation and a second widget of the same type. A text finder survives
none of them. An id is the cheaper default even where `ByText` reaches the
element today.

An element that no flow acts on gets none. Use `ByText` only where the text is
what the walk checks: a value it just picked, a status the screen has to show.
Copy that a flow must find in every locale is found by its locale key
(`ByLocaleKey`, `ByLocaleKeyTooltip`). That finder matches the mark that a launch
with `ENABLE_AUTOMATION_LOCALE_KEYS=true` writes into each translation string. An action
control still takes a target.

An element that a shared widget already marks from inside (app chrome such as a
back button) needs nothing.

## 3. Declare the targets

One enum per flow in the **Targets folder**, one file per enum. The enum uses
`AutomationIdComposer`, so the id is `<scope>.<type>.<name>`. Copy the shape of
the neighbouring file. Import `package:flutter_automation/automation_target.dart`:
it has no Flutter import, so a flow that runs on the host can name the target.

```dart
import 'package:flutter_automation/automation_target.dart';

/// Elements of the login screen.
enum LoginTarget with AutomationIdComposer {
  /// Root of the screen.
  root(AutomationTargetType.screen),

  /// Sends the credentials.
  submit(AutomationTargetType.button);

  @override
  final AutomationTargetType type;

  const LoginTarget(this.type);

  @override
  String get scope => 'login';
}
```

- `scope` is the flow in snake_case and is unique across the folder.
- The member name is the last id segment. Name it after the element, not after the
  widget class (`weight`, not `weightInputField`). Never repeat the type that the
  constructor carries (`back`, not `backButton`).
- Pick `type` by what the element accepts:
  - `button`: a tap. `field`: typed text. `toggle`: a two-state switch.
  - `tab`: a section change. `chip`: a narrowed list.
  - `tile`: a row that opens or acts on an entity.
  - `panel`: an area whose size or presence is the answer.
  - `label`: a line of copy that an agent reads or measures.
- Every flow gets a `root(AutomationTargetType.screen)` on its screen root, every
  modal a `sheet`, and every area that a flow measures a `panel`. Those three turn
  "where am I", "what covers this" and "how much space is left" into one line of
  the id dump instead of a screenshot.

An element that the app renders once per value (a calendar cell, one per date)
takes a class that implements `AutomationTarget` and builds its id from the value.
A flow then needs a finder that rebuilds the value. A project declares that finder
under `finders:` in the `flutter_automation:` section of `pubspec.yaml`, and a
flow uses it as `ByDeclaredDate`.

An element that the app can mount more than once at a time needs one id per copy.
A shared id resolves to several widgets, and every driver command on it fails.
When each copy shows a record with a key of its own (a notification id, a message
id, a country code), mark it with `<Flow>Target.<name>.withKey(record.key)`. The
key is a string or an int and becomes the last id segment. A flow names one copy
with `ByTarget(<Flow>Target.<name>.withKey(42))` and imports
`package:flutter_automation/automation_target.dart` for `withKey`. In a mocked
run the scenario sets the keys, so the flow knows them.

An element without a stable record key must not get a target. A list position is
not a record key: it moves to another copy when the list sorts or drops a row.
Parameterize the surrounding widget, or address the element by text.

"At a time" means present in the tree, not on screen. A screen that the navigator
keeps alive under a pushed route is missing from the `ByValueKey` finder and from
the native tree. A widget that renders once per screen therefore carries a scope of
its own, marked from within. Its id then resolves to wherever the agent stands. A
shell that keeps every visited tab mounted answers a finder in all of them, so
what the tabs share carries one scope per tab.

## 4. Mark the call sites

Append `.automationTarget(<Flow>Target.<name>)` to the widget expression. Never
add a parameter to a widget for it. Never wrap a subtree by hand. Never write a
`Semantics` or a `ValueKey` for automation.

```dart
Checkbox(value: isAccepted, onChanged: onToggled)
    .automationTarget(LoginTarget.agreement),
```

Rules of placement:

- Mark at the call site inside the flow, not inside a shared component. A
  component marked from within carries the same id wherever it renders.
- An element that renders in two variants needs the call on both. A navigation bar
  mounts one icon at a time.
- A slot that shows one action out of many takes one target per arm of the
  resolver that picks the action, never one on the slot. A flow then states which
  action the slot stands on.

A control that cannot act carries no id. `automationTarget()` takes a nullable
target. A `_resolve<Element>Target()` that returns null while the callback is null
leaves the widget untouched. The id then appears exactly when the tap does
something, so `tap` waits for the gate to open instead of hitting an inert button.
A disabled button is still hit-testable, so without this the walk fails one step
later, on a screen that never opened.

A modal that a `show*` launcher builds has no widget expression at the call site,
so it cannot take a flow id. When the launcher is shared, the sheet is app chrome:
mark it inside its own widget with an app-wide scope. Give a flow scope only to a
sheet that the flow builds. Inside a card sheet, the confirming action is often a
widget argument. Its trailing call goes on that argument, and it nests under the id
that the sheet carries on its own `build`. A flow asserts that the sheet is up
before it taps the button.

A shared widget that holds one instance per screen is marked inside the widget.
App chrome joins an app-wide scope. A component with a shape of its own takes a
scope named after the component, not after a flow that mounts it.

A shared component that builds its children from a list of models carries the
target as data. The call site has no widget expression for a child, so the target
joins the model, next to its label and value, and the component appends the call.
The flow still names every target, because the flow builds the models. Use it
only when the component owns its children.

A widget that the shell mounts once per tab takes one scope per tab and resolves it
from a variant. Named constructors set a private variant field, and a
`_resolve<Element>Target()` switches on it.

## 5. Verify

Run the **After an edit** commands. Then prove that the targets resolve on a
device. This step catches a target attached above a semantics boundary, where the
id reaches the driver and not the native tree. Launch through `drive-device`, then
for each new target:

- `flutter_driver_command waitFor` with `finderType: ByValueKey`: the widget is
  found.
- `flutter_driver_command tap` on one of them. A `waitFor` that passes while `tap`
  times out is a hit-test problem, not a missing widget.
- `adb shell uiautomator dump /sdcard/ui.xml && adb shell cat /sdcard/ui.xml`, or
  AXe `describe-ui` on iOS: the id appears as `resource-id` or as the
  accessibility identifier.

An id that the driver reports an offset for while the dump stays silent is usually
a control that the screen keeps collapsed. An expandable section builds its button
at zero size until it opens. Expand the section and dump again before you look for
a semantics boundary.

Report which targets you added and which elements you left to a text finder.

## 6. Post-edit steps

Run every item of **Post-edit steps**. Some changes touch the target module itself:
a new `AutomationTargetType`, a renamed call, a new rule about where a target can
live. Such a change lands in every place that **Format-change places** lists, in one
commit, or nowhere. Renaming or dropping an enum value carries the same duty for the id:
`grep -rn '<id>'` over the project documents and fix every quote. A document that
names an id which no longer exists costs the next agent a timeout.

## 7. Write down what you learned

A rule that you had to discover by failing goes into the document that **Learned
rules** names, before the session ends. Never write it into this skill: the skill
is installed from the package, and a local edit is lost on the next update. Write
one sentence where it will be read, and state what is true now. Examples:

- a marking that resolved for the driver and never reached the native tree;
- a widget family where the trailing call has to sit somewhere non-obvious;
- a naming decision that you had to reverse, and the reason.
