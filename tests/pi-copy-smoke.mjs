import assert from "node:assert/strict"
import { cpSync, mkdtempSync, readFileSync, rmSync } from "node:fs"
import { tmpdir } from "node:os"
import { dirname, join, resolve } from "node:path"
import { createRequire } from "node:module"
import { fileURLToPath } from "node:url"
import test from "node:test"

const root = resolve(dirname(fileURLToPath(import.meta.url)), "..")
const require = createRequire(import.meta.url)
const { createJiti } = require(process.env.JITI_PATH)
const jiti = createJiti(import.meta.url)

async function copiedSetup(t) {
  const destination = mkdtempSync(join(tmpdir(), "pi-copy-"))
  t.after(() => rmSync(destination, { recursive: true, force: true }))
  cpSync(join(root, "AGENTS.md"), join(destination, "AGENTS.md"))
  cpSync(join(root, "docs"), join(destination, "docs"), { recursive: true })
  cpSync(join(root, ".pi"), join(destination, ".pi"), { recursive: true })
  const extension = await jiti.import(join(destination, ".pi/extensions/hooks.ts"), { default: true })
  let handler
  extension({ on: (event, callback) => {
    assert.equal(event, "tool_call")
    handler = callback
  } })
  return { destination, handler }
}

for (const [name, toolName, input, blocked] of [
  ["benign Bash", "bash", { command: "pwd" }, false],
  ["ordinary read", "read", { path: "AGENTS.md" }, false],
  ["dangerous Bash", "bash", { command: "git reset --hard" }, true],
  ["protected file", "read", { path: ".env" }, true],
  ["uppercase protected file", "read", { path: ".ENV" }, true],
  ["schema file", "read", { path: ".env.example" }, false],
]) {
  test(`copied Pi setup ${blocked ? "blocks" : "allows"} ${name} without other tool setups`, async (t) => {
    const { handler } = await copiedSetup(t)

    const result = await handler({ toolName, input })

    assert.equal(result?.block === true, blocked)
  })
}

test("copied Pi setup fails closed when its local safety gate is missing", async (t) => {
  const { destination, handler } = await copiedSetup(t)
  rmSync(join(destination, ".pi/hooks/safety-gate.sh"))

  const result = await handler({ toolName: "bash", input: { command: "pwd" } })

  assert.equal(result.block, true)
})

for (const skill of ["code-walkthrough", "focused-responses", "grilling", "test-generation-skill"]) {
  test(`copied Pi setup includes the ${skill} skill locally`, async (t) => {
    const { destination } = await copiedSetup(t)

    const content = readFileSync(join(destination, ".pi/skills", skill, "SKILL.md"), "utf8")

    assert.match(content, new RegExp(`name: ${skill}`))
  })
}

test("copied Pi settings do not load skills from another setup", async (t) => {
  const { destination } = await copiedSetup(t)

  const settings = JSON.parse(readFileSync(join(destination, ".pi/settings.json"), "utf8"))

  assert.deepEqual(settings.skills ?? [], [])
})
