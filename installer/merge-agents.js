#!/usr/bin/env node
/**
 * merge-agents.js — Non-destructive AGENTS.md merge engine.
 *
 * Merges sections from the Rojas SDD template into an existing AGENTS.md.
 * Uses HTML comment markers to track sections and versions:
 *   <!-- rojas:section:<name>:<version> -->
 *   ...content...
 *   <!-- /rojas:section:<name> -->
 *
 * Rules:
 *   - Section doesn't exist → append
 *   - Section exists with older version → update content between markers
 *   - Section exists with same/newer version → skip
 *   - Content without rojas markers → NEVER touched
 */

const fs = require('fs');
const path = require('path');

const args = process.argv.slice(2);
let templatePath = '';
let targetPath = '';
let dryRun = false;

for (let i = 0; i < args.length; i++) {
  switch (args[i]) {
    case '--template': templatePath = args[++i]; break;
    case '--target': targetPath = args[++i]; break;
    case '--dry-run': dryRun = args[++i] === 'true'; break;
  }
}

if (!templatePath || !targetPath) {
  console.error('Usage: merge-agents.js --template <path> --target <path> [--dry-run true]');
  process.exit(1);
}

const SECTION_START = /<!-- rojas:section:(\w[\w-]*):(\d+\.\d+\.\d+) -->/;
const SECTION_END = /<!-- \/rojas:section:(\w[\w-]*) -->/;

function parseSections(content) {
  const sections = new Map();
  const lines = content.split('\n');
  let currentSection = null;
  let currentVersion = null;
  let currentLines = [];
  let outsideLines = [];

  for (const line of lines) {
    const startMatch = line.match(SECTION_START);
    const endMatch = line.match(SECTION_END);

    if (startMatch) {
      currentSection = startMatch[1];
      currentVersion = startMatch[2];
      currentLines = [line];
    } else if (endMatch && currentSection === endMatch[1]) {
      currentLines.push(line);
      sections.set(currentSection, {
        version: currentVersion,
        content: currentLines.join('\n'),
      });
      currentSection = null;
      currentVersion = null;
      currentLines = [];
    } else if (currentSection) {
      currentLines.push(line);
    } else {
      outsideLines.push(line);
    }
  }

  return { sections, outsideContent: outsideLines.join('\n') };
}

function compareVersions(a, b) {
  const pa = a.split('.').map(Number);
  const pb = b.split('.').map(Number);
  for (let i = 0; i < 3; i++) {
    if (pa[i] > pb[i]) return 1;
    if (pa[i] < pb[i]) return -1;
  }
  return 0;
}

// --- Main ---

const templateContent = fs.readFileSync(templatePath, 'utf8');
const template = parseSections(templateContent);

let targetContent = '';
if (fs.existsSync(targetPath)) {
  targetContent = fs.readFileSync(targetPath, 'utf8');
} else {
  console.log(`${dryRun ? '[DRY RUN] ' : ''}Creating ${targetPath} from template`);
  if (!dryRun) {
    fs.mkdirSync(path.dirname(targetPath), { recursive: true });
    fs.writeFileSync(targetPath, templateContent);
  }
  process.exit(0);
}

const target = parseSections(targetContent);
let result = targetContent;
const appended = [];
const updated = [];
const skipped = [];

for (const [name, tmplSection] of template.sections) {
  if (target.sections.has(name)) {
    const existing = target.sections.get(name);
    if (compareVersions(tmplSection.version, existing.version) > 0) {
      // Update: replace old section content with new
      result = result.replace(existing.content, tmplSection.content);
      updated.push(`${name} (${existing.version} -> ${tmplSection.version})`);
    } else {
      skipped.push(`${name} (${existing.version} >= ${tmplSection.version})`);
    }
  } else {
    // Append new section
    result = result.trimEnd() + '\n\n' + tmplSection.content + '\n';
    appended.push(name);
  }
}

// Report
if (appended.length) console.log(`${dryRun ? '[DRY RUN] ' : ''}Appending sections: ${appended.join(', ')}`);
if (updated.length) console.log(`${dryRun ? '[DRY RUN] ' : ''}Updating sections: ${updated.join(', ')}`);
if (skipped.length) console.log(`Skipping (up to date): ${skipped.join(', ')}`);

if (!dryRun && (appended.length || updated.length)) {
  fs.writeFileSync(targetPath, result);
  console.log(`Wrote ${targetPath}`);
} else if (!appended.length && !updated.length) {
  console.log('AGENTS.md is fully up to date — no changes needed');
}
