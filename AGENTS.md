# AGENTS.md

## Maintenance

### The guide follows the packages

`docs/flutter_automation_guide.html` tells what the packages and the skills do.
It must agree with the code of the same commit.

A change to one of these items updates the guide in the same commit:

- the public API of a package: a class, a method, a parameter, a step or a finder;
- an option of the runner command or a field of its report;
- a key of the `flutter_automation:` section of `pubspec.yaml`;
- a build switch (`--dart-define`);
- a command between the runner and the app;
- the install steps, a package name or a dependency;
- a skill, a workflow or a field of `templates/AGENTS.automation.md`.

How to update the guide:

1. Find each section that tells about the changed item, on all four tabs.
2. Change the English text and the Ukrainian text together. Each `data-l="en"`
   element has a `data-l="uk"` element next to it.
3. Remove the text about a removed item. The guide gives only the current state.
4. Open the page in a browser. Check that the count of `[data-l=en]` elements
   equals the count of `[data-l=uk]` elements.
