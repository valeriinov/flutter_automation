export const meta = {
  name: 'optimize-flow',
  description:
    'Walk one automation flow until its median run meets a time target, fixing one thing per round',
  whenToUse:
    'When a flow has to get faster or stop failing, and every fix should land in the repository rather than in the conversation. Needs the app running on a booted device, launched as the Launch field of the Automation section in AGENTS.md says. Pass args {flow, targetSeconds, maxRounds}; every one is optional.',
  phases: [
    { title: 'Configure', detail: 'the Automation section of AGENTS.md read into fields' },
    { title: 'Measure', detail: 'three sequential runs of the flow on the device' },
    { title: 'Diagnose', detail: 'a timing lens and a reliability lens over the runs' },
    { title: 'Fix', detail: 'exactly one durable change, then format and analyze' },
  ],
}

// A caller can hand args over as an object or as the JSON text of one, and the
// difference is silent: every field reads as undefined and the defaults answer
// in its place, so a run reports a target nobody asked for.
const input = typeof args === 'string' ? JSON.parse(args) : (args ?? {})
const targetSeconds = input.targetSeconds ?? 60
const maxRounds = input.maxRounds ?? 2
const RUNS_PER_ROUND = 3
const PLATEAU_RATIO = 0.95

const CONFIG_SCHEMA = {
  type: 'object',
  properties: {
    found: { type: 'boolean' },
    runCommand: { type: 'string' },
    flowsFolder: { type: 'string' },
    targetsFolder: { type: 'string' },
    mockFile: { type: 'string' },
    defaultFlow: { type: 'string' },
    afterEdit: { type: 'string' },
    postEditSteps: { type: 'string' },
    learnedRules: { type: 'string' },
  },
  required: [
    'found',
    'runCommand',
    'flowsFolder',
    'targetsFolder',
    'mockFile',
    'defaultFlow',
    'afterEdit',
    'postEditSteps',
    'learnedRules',
  ],
  additionalProperties: false,
}

const RUN_SCHEMA = {
  type: 'object',
  properties: {
    commandMs: { type: 'number' },
    totalMs: { type: 'number' },
    ok: { type: 'boolean' },
    failedSteps: { type: 'array', items: { type: 'string' } },
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
  required: ['commandMs', 'totalMs', 'ok', 'failedSteps', 'slowestSteps'],
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
          savingSeconds: { type: 'number' },
        },
        required: ['claim', 'evidence', 'fix', 'savingSeconds'],
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
  },
  required: ['applied', 'kind', 'files', 'change', 'reason'],
  additionalProperties: false,
}

// A workflow script reads no file. The first agent reads the project section and
// every later prompt takes its values from the answer.
const configPrompt = `Read the section "## Automation" of the AGENTS.md file at the repository root.

Make exactly ONE tool call: read that file. Do not run anything, do not explore.

Each bullet of the section is one field. Copy each value verbatim, without the backticks, into the matching key:
- Flow run command → runCommand
- Flows folder → flowsFolder
- Targets folder → targetsFolder
- Mock configuration file → mockFile
- Default flow → defaultFlow
- After an edit → afterEdit
- Post-edit steps → postEditSteps
- Learned rules → learnedRules

Set found false, and every other key to an empty string, when the file or the section does not exist. Set one key to an empty string when its bullet is missing or empty.`

function median(numbers) {
  const sorted = [...numbers].sort((a, b) => a - b)

  return sorted[Math.floor(sorted.length / 2)]
}

function buildRunPrompt(runCommand, flow) {
  return `Walk the ${flow} automation flow once on the booted device and report what it cost.

Make exactly TWO tool calls, in this order and nothing else:

1. mcp__dart__hot_restart, no arguments unless more than one app is connected.
2. Bash, this command verbatim:

${runCommand}

Do not explore the repository, do not read files, do not retry, do not take a screenshot. The two calls answer everything.

Report, straight off the JSON the command prints (parse from the first "{"):
- commandMs and totalMs as they are
- ok as it is
- failedSteps: the labels of steps whose "ok" is false, empty when none
- slowestSteps: the five steps with the largest ms, as {label, ms}`
}

async function measure(runPrompt, round) {
  const runs = []

  // Serial on purpose: one device, one app, one driver connection.
  for (let index = 0; index < RUNS_PER_ROUND; index += 1) {
    const run = await agent(runPrompt, {
      label: `run ${round}.${index + 1}`,
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
        `run ${index + 1}: commandMs ${run.commandMs}, totalMs ${run.totalMs}, ok ${run.ok}` +
        `, failed [${run.failedSteps.join(', ')}]` +
        `, slowest ${run.slowestSteps.map((step) => `${step.label} ${step.ms}ms`).join(' | ')}`,
    )
    .join('\n')
}

async function diagnose(config, flow, runs, round) {
  const shared = `Flow: ${flow} in ${config.flowsFolder}
Target: a median run of ${targetSeconds}s or less.

Measurements from round ${round}:
${describeRuns(runs)}

Report findings only. Do not edit anything. A finding without a number from the measurements above is not a finding.`

  const lenses = [
    {
      key: 'timing',
      prompt: `${shared}

Lens: where the seconds are. Read the flow file and the runner. For each of the slowest steps say what the app is actually doing during it: an animation, a mock request, a driver settle, a deliberately slow drag. Name the ones that can be shortened without losing what the step proves, and say by how much.`,
    },
    {
      key: 'reliability',
      prompt: `${shared}

Lens: what is fragile. Compare the runs against each other. Report steps that failed, steps whose ms swings between runs, finders that would break the moment copy or data changes (a text finder, a hard-coded id), and anything the flow leaves behind that makes the next run start differently. Say what each would cost when it breaks.`,
    },
  ]

  const reports = await parallel(
    lenses.map((lens) => () =>
      agent(lens.prompt, {
        label: `lens:${lens.key}`,
        phase: 'Diagnose',
        schema: FINDING_SCHEMA,
      }),
    ),
  )

  return reports.filter(Boolean).flatMap((report) => report.findings)
}

async function applyOneFix(config, flow, findings, round) {
  const ranked = [...findings].sort((a, b) => b.savingSeconds - a.savingSeconds)
  const listed = ranked
    .map(
      (finding, index) =>
        `${index + 1}. ${finding.claim}\n   evidence: ${finding.evidence}\n   fix: ${finding.fix} (~${finding.savingSeconds}s)`,
    )
    .join('\n')

  return agent(
    `Apply exactly ONE change from this list, the one with the best saving-to-risk ratio. Leave the rest alone.

${listed}

The change has to be one of these kinds, and it has to land in a tracked file:
- flowStep: edit the flow ${flow} in ${config.flowsFolder}
- automationTarget: add a target through the add-automation-targets skill, so a hand-assembled finder becomes an id (targets in ${config.targetsFolder})
- mock: close a gap in the mock (${config.mockFile}) that makes a path untestable or slow
- runner: add a step kind or an option the flutter_automation_runner package lacks
- rule: write a rule the next agent needs, as one sentence, into ${config.learnedRules || 'the document the user names (none is set: skip this kind)'}; never into an installed skill

Then run: ${config.afterEdit || 'the format and analyze commands of the project'}
It must be clean before you report. Then run these steps: ${config.postEditSteps || 'none'}. Do not commit.

Report which kind you applied, the files you touched, what you changed, and why that one over the others. Set applied:false when nothing in the list is worth the risk.`,
    { label: `fix round ${round}`, phase: 'Fix', schema: FIX_SCHEMA },
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
// The runner times itself, so a run is one command. The restart before it is
// what makes runs comparable: it drops the mock state a previous run wrote, and
// it unparks the app when a previous run failed halfway.
const runPrompt = buildRunPrompt(`${config.runCommand} ${flow} 2>/dev/null`, flow)

const history = []
let verdict = 'plateau'

for (let round = 1; round <= maxRounds; round += 1) {
  phase('Measure')
  log(`round ${round}: ${RUNS_PER_ROUND} runs of ${flow}, target ${targetSeconds}s`)

  const runs = await measure(runPrompt, round)
  if (runs.length === 0) {
    verdict = 'noRuns'
    break
  }

  const medianSeconds = median(runs.map((run) => run.commandMs)) / 1000
  const failed = runs.filter((run) => !run.ok).length
  history.push({ round, medianSeconds, failed, runs: runs.length })
  log(`round ${round}: median ${medianSeconds}s, ${failed}/${runs.length} runs with a failed step`)

  if (medianSeconds <= targetSeconds && failed === 0) {
    verdict = 'met'
    break
  }

  const previous = history.length > 1 ? history[history.length - 2] : null
  if (previous && medianSeconds > previous.medianSeconds * PLATEAU_RATIO && failed === 0) {
    verdict = 'plateau'
    log(`round ${round}: ${previous.medianSeconds}s to ${medianSeconds}s is under 5%, stopping`)
    break
  }

  if (round === maxRounds) {
    verdict = 'roundsSpent'
    break
  }

  phase('Diagnose')
  const findings = await diagnose(config, flow, runs, round)
  if (findings.length === 0) {
    verdict = 'noFindings'
    break
  }

  phase('Fix')
  const fix = await applyOneFix(config, flow, findings, round)
  history[history.length - 1].fix = fix
  if (!fix?.applied) {
    verdict = 'noFixWorthApplying'
    break
  }

  log(`round ${round}: applied ${fix.kind}: ${fix.change}`)
}

return {
  flow,
  targetSeconds,
  verdict,
  history,
  ledger: '.dart_tool/automation_runner_runs.jsonl',
}
