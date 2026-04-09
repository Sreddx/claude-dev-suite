#!/usr/bin/env node
/**
 * merge-claude-agents.js — Claude Code agent installer.
 *
 * Installs .claude/agents/*.md from the SDD Dev Suite into a target repo.
 * Uses a version marker comment to track managed agents:
 *   <!-- sdd-dev-suite:agent:<name>:<version> -->
 *
 * Rules:
 *   - Agent file doesn't exist           → install (copy + add marker)
 *   - Agent file exists WITH marker      → always override (force reinstall)
 *   - Agent file exists WITHOUT marker   → skip (user-created, never touch)
 *
 * Usage:
 *   node merge-claude-agents.js --source <agents-dir> --target <target-dir> \
 *     --version <semver> [--dry-run true]
 */

const fs = require('fs');
const path = require('path');

// All 14 agents — used by coordination, monorepo, and standalone
const ALL_AGENTS = [
  'orchestrator', 'planner', 'researcher', 'team-leader',
  'validator', 'agent-prep', 'agent-sync', 'devstart',
  'frontend', 'tester-front', 'backend', 'database',
  'tester-back', 'github-ops',
];

const ROLE_AGENTS = {
  // Full suite — coordinator hub delegates to sub-repos and needs awareness of all agent capabilities
  coordination: ALL_AGENTS,
  // Full suite — monorepo orchestrates all domains internally
  monorepo:     ALL_AGENTS,
  // Frontend-only repo: orchestrator (receives delegation) + planning + fe implementation + quality gate
  frontend:     ['orchestrator', 'planner', 'researcher', 'frontend', 'tester-front', 'github-ops', 'validator'],
  // Backend-only repo: orchestrator (receives delegation) + planning + be implementation + quality gate
  backend:      ['orchestrator', 'planner', 'researcher', 'backend', 'database', 'tester-back', 'github-ops', 'validator'],
  standalone:   null, // null = all agents
};

const args = process.argv.slice(2);
let sourceDir = '';
let targetDir = '';
let version = '1.0.0';
let dryRun = false;
let role = 'standalone';

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--source':  sourceDir = args[++i]; break;
    case '--target':  targetDir = args[++i]; break;
    case '--version': version   = args[++i]; break;
    case '--dry-run': dryRun    = args[++i] === 'true'; break;
    case '--role':    role      = args[++i]; break;
  }
}

if (!sourceDir || !targetDir) {
  console.error('Usage: merge-claude-agents.js --source <dir> --target <dir> --version <semver> [--dry-run true] [--role standalone|coordination|monorepo|frontend|backend]');
  process.exit(1);
}

const allowedAgents = ROLE_AGENTS[role] ?? ROLE_AGENTS.standalone;

const MARKER_RE = /^<!-- sdd-dev-suite:agent:([\w-]+):(\d+\.\d+\.\d+) -->/;

const SEMVER_STRICT = /^\d+\.\d+\.\d+$/;

function addMarker(content, name, ver) {
  return `<!-- sdd-dev-suite:agent:${name}:${ver} -->\n${content}`;
}

function stripMarker(content) {
  return content.replace(/^<!-- sdd-dev-suite:agent:[\w-]+:\d+\.\d+\.\d+ -->\n/, '');
}

// --- Main ---

if (!SEMVER_STRICT.test(version)) {
  console.error(`Invalid --version "${version}" — expected MAJOR.MINOR.PATCH (e.g. 1.2.3)`);
  process.exit(1);
}

if (!fs.existsSync(sourceDir)) {
  console.error(`Source directory not found: ${sourceDir}`);
  process.exit(1);
}

if (!dryRun) {
  fs.mkdirSync(targetDir, { recursive: true });
}

const allSourceFiles = fs.readdirSync(sourceDir).filter(f => f.endsWith('.md'));
const sourceFiles = allowedAgents
  ? allSourceFiles.filter(f => allowedAgents.includes(path.basename(f, '.md')))
  : allSourceFiles;

if (allowedAgents) {
  console.log(`Role: ${role} — installing agents: ${allowedAgents.join(', ')}`);
}

const installed = [];
const updated = [];
const skipped = [];
const userOwned = [];

for (const file of sourceFiles) {
  const agentName = path.basename(file, '.md');
  const srcPath = path.join(sourceDir, file);
  const tgtPath = path.join(targetDir, file);
  const srcContent = fs.readFileSync(srcPath, 'utf8');

  if (!fs.existsSync(tgtPath)) {
    // New install
    const markedContent = addMarker(srcContent, agentName, version);
    if (!dryRun) {
      fs.writeFileSync(tgtPath, markedContent);
    }
    installed.push(agentName);
    continue;
  }

  // File exists — check for managed marker
  const tgtContent = fs.readFileSync(tgtPath, 'utf8');
  const firstLine = tgtContent.split('\n')[0].trimEnd();
  const match = firstLine.match(MARKER_RE);

  if (!match) {
    // No marker → user-created file, never overwrite
    userOwned.push(agentName);
    continue;
  }

  // Has managed marker → always force override
  const existingVersion = match[2];
  const markedContent = addMarker(srcContent, agentName, version);
  if (!dryRun) {
    fs.writeFileSync(tgtPath, markedContent);
  }
  updated.push(`${agentName} (${existingVersion} → ${version})`);
}

// Report
const prefix = dryRun ? '[DRY RUN] ' : '';
if (installed.length)  console.log(`${prefix}Installed agents: ${installed.join(', ')}`);
if (updated.length)    console.log(`${prefix}Updated agents: ${updated.join(', ')}`);
if (skipped.length)    console.log(`Skipping (up to date): ${skipped.join(', ')}`);
if (userOwned.length)  console.log(`Skipping (user-owned, no marker): ${userOwned.join(', ')}`);

if (!installed.length && !updated.length) {
  console.log('Claude Code agents are fully up to date — no changes needed');
}
