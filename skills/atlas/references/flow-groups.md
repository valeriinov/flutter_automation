# Flow groups

One taxonomy builds two menus: the switcher of the atlas page and the groups of
the QA panel. Both read the same groups. The project declares one `groupOrder`
constant and passes it to `AtlasProject.groupOrder` and to
`AutomationRunnerConfig.read().withGroupOrder(...)`.

## Terms

- **Area**: a business area of the app. The first level of both menus.
- **Path**: one user path from the entry to the result. The second level. An
  `AutomationFlowGroup` is a path, and it names its `area`.
- **Flow**: the walks of one path. A variant is one way through the flow.

## Rules

1. **The switcher lists business areas.** An area names what the user wants to
   do. It never names a user role, a screen type or a technical layer.
2. **The first item is the app start.** The launch, the permissions and the
   first screen stand in the first area.
3. **No "other" bin.** A flow that fits no area means the areas are wrong. Fix
   the areas.
4. **A path is one user path from the entry to the result.** Its name holds the
   actor and the kind of path. Example: "Visitor, sign up with a code".
5. **The project path map gives the paths and their order.** A project without
   a map derives the paths from its screens and routes. The agent proposes the
   result to the user and waits for the answer before it writes any group.
6. **A flow belongs to one path.** A flow that crosses several paths splits
   into one flow for each path.
7. **Flows and variants follow the stages of the path.** The stages set the
   sequence of the flows. A variant follows the stage it changes.
8. **An entry from a push or a link is a variant.** It joins the flow of the
   path that the push or the link opens. It never forms a flow of its own.
9. **A thin item merges with a neighbour.** An item that holds one thin path
   joins the neighbour of the same nature.
10. **A step that has no new state and no branch stays in QA.** The atlas shows
    no stage for it. The QA panel keeps it as a step.

## Check

Run the check after each change of groups.

1. Every flow has one group. No group is empty.
2. Every area has two paths or more, or rule 9 merged it.
3. The first area holds the app start.
4. `render` runs. A flow that names a group missing from `groupOrder` stops it
   with the error "is not in AtlasProject.groupOrder".
