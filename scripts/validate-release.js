#!/usr/bin/env bun

const fs = require("node:fs")
const { spawnSync } = require("node:child_process")
const model = require("../WorkspaceModel.js")

function fail(message) {
  console.error(`release metadata: ${message}`)
  process.exit(1)
}

function readJson(path) {
  return JSON.parse(fs.readFileSync(path, "utf8"))
}

const manifest = readJson("manifest.json")
const compatibility = model.normalizeCompatibility(readJson("compatibility.json"))
const semver = /^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)$/

if (!semver.test(String(manifest.version || ""))) fail("manifest version must be semantic")
if (!semver.test(compatibility.minimum_boomux)) fail("minimum Boomux version must be semantic")

const readme = fs.readFileSync("README.md", "utf8")
const agents = fs.readFileSync("AGENTS.md", "utf8")
const panel = fs.readFileSync("Panel.qml", "utf8")
const deploy = fs.readFileSync("deploy-local.sh", "utf8")

if (!readme.includes(`Boomux ${compatibility.minimum_boomux} or newer`))
  fail("README minimum Boomux version does not match compatibility.json")
if (!readme.includes(`[\`compatibility.json\`](compatibility.json)`))
  fail("README does not identify compatibility.json as the source of truth")
if (!agents.includes(`Required Boomux daemon protocol: ${compatibility.minimum_protocol}`))
  fail("AGENTS protocol does not match compatibility.json")
if (!panel.includes('Qt.resolvedUrl("compatibility.json")'))
  fail("Panel.qml does not load compatibility.json")
if (!deploy.includes("compatibility.json"))
  fail("deploy-local.sh does not install compatibility.json")
for (const capability of compatibility.required_capabilities) {
  if (!panel.includes(`"${capability}"`))
    fail(`Panel.qml does not consume required capability ${capability}`)
}

const base = process.argv[2]
if (base) {
  const result = spawnSync("git", ["show", `${base}:manifest.json`], { encoding: "utf8" })
  if (result.status !== 0) fail(`could not read manifest.json from base ${base}`)
  const baseVersion = JSON.parse(result.stdout).version
  if (baseVersion === manifest.version) fail("manifest version must change in every pull request")
  if (model.versionDirection(manifest.version, baseVersion) !== "newer")
    fail(`manifest version ${manifest.version} must be newer than base ${baseVersion}`)
}

console.log(`release metadata valid for plugin ${manifest.version} and Boomux ${compatibility.minimum_boomux}+`)
