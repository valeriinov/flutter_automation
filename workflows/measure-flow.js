export const meta = {
  name: 'measure-flow',
  description:
    'Walk one variant of an automation flow three times and spend exactly one fix on what the median says',
  whenToUse:
    'When a variant of a flow has to be walked on a device and its result has to be a number rather than an impression: a new variant proved for the first time, a variant that started failing, a variant slower than its target. Needs the app running on the device that the drive-device skill picks, launched as the Launch field of the Automation section in AGENTS.md says. Pass args {flow, variant, targetSeconds}; every one is optional.',
  phases: [
    { title: 'Configure', detail: 'the Automation section of AGENTS.md read into fields' },
    { title: 'Expand', detail: 'the variant resolved to steps without a device' },
    { title: 'Measure', detail: 'three runs on the device, median of commandMs' },
    { title: 'Diagnose', detail: 'two lenses, chosen by what actually went wrong' },
    { title: 'Fix', detail: 'exactly one durable change, verified by a rerun' },
  ],
}

// A caller can hand args over as an object or as the JSON text of one, and the
// difference is silent: every field reads as undefined and the defaults answer
// in its place, so a run reports a flow nobody asked for.
const input = typeof args === 'string' ? JSON.parse(args) : (args ?? {})
const targetSeconds = input.targetSeconds ?? 60
const RUNS = 3

const CONFIG_SCHEMA = {
  type: 'object',
  properties: {
    found: { type: 'boolean' },
    runCommand: { type: 'string' },
    launch: { type: 'string' },
    flowsFolder: { type: 'string' },
    targetsFolder: { type: 'string' },
    mockFile: { type: 'string' },
    defaultFlow: { type: 'string' },
    afterEdit: { type: 'string' },
    postEditSteps: { type: 'string' },
    formatChangePlaces: { type: 'string' },
    learnedRules: { type: 'string' },
  },
  required: [
    'found',
    'runCommand',
    'launch',
    'flowsFolder',
    'targetsFolder',
    'mockFile',
    'defaultFlow',
    'afterEdit',
    'postEditSteps',
    'formatChangePlaces',
    'learnedRules',
  ],
  additionalProperties: false,
}

const EXPAND_SCHEMA = {
  type: 'object',
  properties: {
    ok: { type: 'boolean' },
    variant: { type: 'string' },
    stepCount: { type: 'number' },
    scenarioKeys: { type: 'array', items: { type: 'string' } },
    problem: { type: 'string' },
  },
  required: ['ok', 'variant', 'stepCount', 'scenarioKeys', 'problem'],
  additionalProperties: false,
}

const RUN_SCHEMA = {
  type: 'object',
  properties: {
    ok: { type: 'boolean' },
    commandMs: { type: 'number' },
    setupMs: { type: 'number' },
    totalMs: { type: 'number' },
    failedSteps: {
      type: 'array',
      items: {
        type: 'object',
        properties: { label: { type: 'string' }, error: { type: 'string' } },
        required: ['label', 'error'],
        additionalProperties: false,
      },
    },
    slowestSteps: {
      type: 'array',
      items: {
        type: 'object',
        properties: { label: { type: 'string' }, ms: { type: 'number' } },
        required: ['label', 'ms'],
        additionalProperties: false,
      },
    },
  },
  required: ['ok', 'commandMs', 'setupMs', 'totalMs', 'failedSteps', 'slowestSteps'],
  additionalProperties: false,
}

const FINDING_SCHEMA = {
  type: 'object',
  properties: {
    findings: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          claim: { type: 'string' },
          evidence: { type: 'string' },
          fix: { type: 'string' },
          kind: { type: 'string' },
          blocking: { type: 'boolean' },
          savingSeconds: { type: 'number' },
        },
        required: ['claim', 'evidence', 'fix', 'kind', 'blocking', 'savingSeconds'],
        additionalProperties: false,
      },
    },
  },
  required: ['findings'],
  additionalProperties: false,
}

const FIX_SCHEMA = {
  type: 'object',
  properties: {
    applied: { type: 'boolean' },
    kind: { type: 'string' },
    files: { type: 'array', items: { type: 'string' } },
    change: { type: 'string' },
    reason: { type: 'string' },
    rerunOk: { type: 'boolean' },
    rerunCommandMs: { type: 'number' },
  },
  required: ['applied', 'kind', 'files', 'change', 'reason', 'rerunOk', 'rerunCommandMs'],
  additionalProperties: false,
}

// A workflow script reads no file. The first agent reads the project section and
// every later prompt takes its values from the answer.
const configPrompt = `Read the section "## Automation" of the AGENTS.md file at the repository root.

Make exactly ONE tool call: read that file. Do not run anything, do not explore.

Each bullet of the section is one field. Copy each value verbatim, without the backticks, into the matching key:
- Flow run command → runCommand
- Launch → launch
- Flows folder → flowsFolder
- Targets folder → targetsFolder
- Mock configuration file → mockFile
- Default flow → defaultFlow
- After an edit → afterEdit
- Post-edit steps → postEditSteps
- Format-change places → formatChangePlaces
- Learned rules → learnedRules

Set found false, and every other key to an empty string, when the file or the section does not exist. Set one key to an empty string when its bullet is missing or empty.`

const expandPrompt = (dryRunCommand, target) => `Expand the ${target} automation flow variant without touching a device.

Make exactly ONE tool call, Bash, this command verbatim:

${dryRunCommand}

Do not explore the repository, do not read files, do not retry, do not launch anything. The command answers everything, and it needs no device.

The last line of stdout is one line of JSON: either the resolved variant, or {"error": "..."} when the flow, the variant, a block reference or a placeholder is malformed. Parse from the first "{" of that line.

Report:
- ok: true when the JSON holds "steps", false when it holds "error"
- variant: the "variant" it resolved to, empty when it errored
- stepCount: how many steps it expanded to, 0 when it errored
- scenarioKeys: the top-level keys of the "scenario" object, empty when there is none
- problem: the "error" text verbatim, empty string when ok`

const runPrompt = (runCommand, target) => `Walk the ${target} automation flow variant once on the connected device and report what it cost.

Make exactly TWO tool calls, in this order and nothing else:

1. mcp__dart__hot_restart, no arguments unless more than one app is connected.
2. Bash, this command verbatim:

${runCommand}

Do not explore the repository, do not read files, do not retry, do not take a screenshot. The two calls answer everything.

Report, straight off the JSON the command prints (parse from the first "{"):
- ok, commandMs, setupMs and totalMs as they are
- failedSteps: every step whose "ok" is false, as {label, error} with the error text verbatim
- slowestSteps: the five steps with the largest ms, as {label, ms}

When the command printed {"error": "..."} instead of a report, set ok false, every number 0, and put the text into a single failedSteps entry labelled "runner".`

// The median run itself rather than the median number: its slowest steps are
// the ones a fix has to shorten, and the fastest run's are not.
function medianRun(runs) {
  const sorted = [...runs].sort((a, b) => a.commandMs - b.commandMs)

  return sorted[Math.floor(sorted.length / 2)]
}

function kindsFor(config, flow) {
  return `- product: the app misbehaves the same way for a live user doing the step by hand (a race, lost input, a wrong state); the fix is in the app and the user's to choose, so it is never applied here: a list that holds one gets no change at all, report applied false, kind "product", and name the product defect in reason
- flowVariant: the step, its timeout or its order in the flow file of ${flow} in ${config.flowsFolder}
- mockScenario: the state the step needed, in the variant's own scenario (${config.mockFile})
- automationTarget: a hand-assembled finder becomes an id, through the add-automation-targets skill (targets in ${config.targetsFolder})
- block: a stretch a second variant now shares, extracted into a block
- runner: a step kind or an option the flutter_automation_runner package lacks

A runner or mock-configuration change lands in every place of this list: ${config.formatChangePlaces || 'none'}. A change to a flow, a block, a target or a mock key also runs these steps: ${config.postEditSteps || 'none'}.`
}

async function measure(config, runCommand, target) {
  const runs = []

  // Serial on purpose: one device, one app, one driver connection.
  for (let index = 0; index < RUNS; index += 1) {
    const run = await agent(runPrompt(runCommand, target), {
      label: `run ${index + 1}`,
      phase: 'Measure',
      schema: RUN_SCHEMA,
    })

    if (run) {
      runs.push(run)
    }
  }

  return runs
}

function describeRuns(runs) {
  return runs
    .map(
      (run, index) =>
        `run ${index + 1}: ok ${run.ok}, commandMs ${run.commandMs}, setupMs ${run.setupMs}` +
        `, totalMs ${run.totalMs}` +
        `, failed [${run.failedSteps.map((step) => `${step.label}: ${step.error}`).join(' | ')}]` +
        `, slowest ${run.slowestSteps.map((step) => `${step.label} ${step.ms}ms`).join(' | ')}`,
    )
    .join('\n')
}

function lensesFor(hasFailure, config) {
  if (hasFailure) {
    return [
      {
        key: 'failure',
        prompt: `Lens: why the run stopped. Read the flow file and the block the failing step comes from. For that step say which of these it is, and prove it from the file: the finder addresses an id no enum in ${config.targetsFolder} declares (grep the id), the step runs before the screen it addresses is mounted, its timeout is shorter than the latency the variant's scenario asked for, or the app never reached that state because the variant's scenario does not set it up. Every step after the failing one is absent from the report, not passed. Do not read its silence as working.`,
      },
      {
        key: 'setup',
        prompt: `Lens: what the variant walked into. Read the variant's scenario, ${config.mockFile} and the settings class of every section the variant names. Report a key or a field the settings class does not read (it is dropped in silence, so the run proves something other than what was asked), a setting that contradicts what the variant name claims to prove, and anything a previous run leaves behind that makes the next one start elsewhere. A setupMs of zero with a scenario written means the scenario never reached the variant.`,
      },
    ]
  }

  return [
    {
      key: 'timing',
      prompt: `Lens: where the seconds are. Read the flow file, the blocks it walks and the runner. For each of the slowest steps say what the app is actually doing during it: an animation, a mocked answer under the variant's latency profile, a driver settle, a deliberately slow drag. Name the ones that can be shortened without losing what the variant proves, and say by how much. A latency profile the variant could drop to the fast one counts only when the variant does not exist to prove a loader.`,
    },
    {
      key: 'reliability',
      prompt: `Lens: what is fragile. Compare the runs against each other. Report steps whose ms swings between runs, finders that break the moment copy or seeded data changes (a text finder, a hard-coded id), a timeout so tight that a slower answer fails it, and anything the variant leaves behind that makes the next run start differently. Say what each would cost when it breaks.`,
    },
  ]
}

async function diagnose(config, flow, runs, expansion) {
  const shared = `Flows folder: ${config.flowsFolder}
Flow: ${flow}
Variant: ${expansion.variant}, ${expansion.stepCount} steps, scenario keys [${expansion.scenarioKeys.join(', ')}]
Target: a median commandMs of ${targetSeconds}s or less, every step ok.

Measurements:
${describeRuns(runs)}

Report findings only. Do not edit anything, do not run anything on the device. A finding without a number or an error string from the measurements above is not a finding.

Each finding names the kind of fix it asks for, one of:
${kindsFor(config, flow)}

Set blocking true for a finding that is why a run failed, false for one that only costs seconds. savingSeconds is the wall clock the fix returns, 0 when it returns none.`

  const reports = await parallel(
    lensesFor(runs.some((run) => !run.ok), config).map((lens) => () =>
      agent(`${shared}\n\n${lens.prompt}`, {
        label: `lens:${lens.key}`,
        phase: 'Diagnose',
        schema: FINDING_SCHEMA,
      }),
    ),
  )

  return reports.filter(Boolean).flatMap((report) => report.findings)
}

// Blocking first, then by what the fix returns: a run that fails has no median
// worth shortening.
function rank(findings) {
  return [...findings].sort(
    (a, b) => Number(b.blocking) - Number(a.blocking) || b.savingSeconds - a.savingSeconds,
  )
}

async function applyOneFix(config, flow, commands, findings) {
  const listed = rank(findings)
    .map(
      (finding, index) =>
        `${index + 1}. [${finding.kind}${finding.blocking ? ', blocking' : ''}] ${finding.claim}\n` +
        `   evidence: ${finding.evidence}\n` +
        `   fix: ${finding.fix} (~${finding.savingSeconds}s)`,
    )
    .join('\n')

  return agent(
    `Apply exactly ONE change from this list, a blocking one if the list holds any, otherwise the best saving-to-risk ratio. Leave the rest alone: two changes in one round and the next median cannot say which of them moved it.

${listed}

The change has to be one of these kinds, and it has to land in a tracked file:
${kindsFor(config, flow)}

Then, in this order:
1. Expand it again: ${commands.dryRun}. It has to hold "steps" and not "error".
2. mcp__dart__hot_restart, then walk it once: ${commands.run}
3. Only when the change touched Dart: run ${config.afterEdit || 'the format and analyze commands of the project'}. It must be clean before you report. Do not commit.
4. When a rule was learned that the next agent needs, write it as one sentence in ${config.learnedRules || 'the document the user names (none is set: skip this)'}. Never write it into an installed skill.

Report which kind you applied, the files you touched, what you changed, why that one over the others, and the ok and commandMs of the rerun. Set applied false, with rerunOk false and rerunCommandMs 0, when nothing in the list is worth the risk.`,
    { label: 'fix', phase: 'Fix', schema: FIX_SCHEMA },
  )
}

phase('Configure')

const config = await agent(configPrompt, {
  label: 'configure',
  phase: 'Configure',
  schema: CONFIG_SCHEMA,
})

if (!config || !config.found || !config.runCommand) {
  return {
    verdict: 'noAutomationSection',
    problem:
      'AGENTS.md has no "## Automation" section with a Flow run command. Run the setup-automation skill.',
  }
}

const flow = input.flow || config.defaultFlow
// The runner takes the variant as a positional argument, so an empty one has to
// leave no gap in the command line.
const variant = input.variant ?? ''
const target = variant ? `${flow} ${variant}` : flow
const commands = {
  dryRun: `${config.runCommand} ${target} --dry-run 2>/dev/null`,
  run: `${config.runCommand} ${target} 2>/dev/null`,
}

phase('Expand')
log(`${target}: expanding without a device`)

const expansion = await agent(expandPrompt(commands.dryRun, target), {
  label: 'expand',
  phase: 'Expand',
  schema: EXPAND_SCHEMA,
})

if (!expansion) {
  return { flow, variant, targetSeconds, verdict: 'noExpansion' }
}

// A malformed variant cannot be measured, and it costs no device to know that.
// The one fix of this run goes to the format error instead of to the median.
if (!expansion.ok) {
  phase('Fix')
  log(`${target}: does not expand: ${expansion.problem}`)

  const fix = await applyOneFix(config, flow, commands, [
    {
      claim: `${target} does not expand: ${expansion.problem}`,
      evidence: `${commands.dryRun} printed {"error": "${expansion.problem}"}`,
      fix: 'make the flow, its block references and its placeholders resolve',
      kind: 'flowVariant',
      blocking: true,
      savingSeconds: 0,
    },
  ])

  return {
    flow,
    variant,
    targetSeconds,
    verdict: fix?.applied ? 'expansionFixed' : 'expansionBroken',
    expansion,
    fix,
  }
}

log(
  `${target}: ${expansion.variant}, ${expansion.stepCount} steps, scenario [${expansion.scenarioKeys.join(', ')}]`,
)

phase('Measure')
log(`${RUNS} runs on the device, target ${targetSeconds}s`)

const runs = await measure(config, commands.run, target)

if (runs.length === 0) {
  return { flow, variant: expansion.variant, targetSeconds, verdict: 'noRuns', expansion }
}

const median = medianRun(runs)
const medianSeconds = median.commandMs / 1000
const failedRuns = runs.filter((run) => !run.ok).length
const measurement = {
  runs: runs.length,
  medianSeconds,
  failedRuns,
  setupMs: median.setupMs,
  slowestSteps: median.slowestSteps,
}

log(`median ${medianSeconds}s, ${failedRuns}/${runs.length} runs with a failed step`)

if (medianSeconds <= targetSeconds && failedRuns === 0) {
  return { flow, variant: expansion.variant, targetSeconds, verdict: 'met', expansion, measurement }
}

phase('Diagnose')
const findings = await diagnose(config, flow, runs, expansion)

if (findings.length === 0) {
  return {
    flow,
    variant: expansion.variant,
    targetSeconds,
    verdict: 'noFindings',
    expansion,
    measurement,
  }
}

phase('Fix')
const fix = await applyOneFix(config, flow, commands, findings)

if (fix?.applied) {
  log(`applied ${fix.kind}: ${fix.change}; rerun ok ${fix.rerunOk}, ${fix.rerunCommandMs}ms`)
}

return {
  flow,
  variant: expansion.variant,
  targetSeconds,
  verdict: fix?.applied ? 'fixApplied' : 'noFixWorthApplying',
  expansion,
  measurement,
  findings: rank(findings),
  fix,
  ledger: '.dart_tool/automation_runner_runs.jsonl',
}
