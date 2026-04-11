#!/usr/bin/env node
'use strict';

const { execSync, spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const HELP = `
claude-dev-suite — Spec-Driven Development installer

Usage:
  npx claude-dev-suite install [OPTIONS]
  npx claude-dev-suite --help

Commands:
  install     Install the SDD baseline into the current (or specified) directory

Options:
  --profile <name>     Apply a profile: frontend, backend-api, brownfield, high-risk
  --repo-type <type>   Auto-select profiles: frontend, backend, monorepo,
                        brownfield-frontend, brownfield-backend, coordination, standalone
  --target <dir>       Target directory (default: current directory)
  --dry-run            Preview changes without applying
  --no-agents          Skip agent suite installation
  --version <ver>      Agent suite version (default: 1.0.0)
  --help, -h           Show this help

Examples:
  npx claude-dev-suite install
  npx claude-dev-suite install --profile frontend
  npx claude-dev-suite install --repo-type monorepo --target ./my-project
  npx claude-dev-suite install --dry-run
`;

function main() {
  const args = process.argv.slice(2);

  if (args.length === 0 || args.includes('--help') || args.includes('-h')) {
    console.log(HELP);
    process.exit(0);
  }

  const command = args[0];

  if (command !== 'install') {
    console.error(`Unknown command: ${command}`);
    console.error('Run "npx claude-dev-suite --help" for usage.');
    process.exit(1);
  }

  // Find the install.sh relative to this script
  // When run via npx, this file is at <package>/bin/cli.js
  // install.sh is at <package>/install.sh
  const packageRoot = path.resolve(__dirname, '..');
  const installScript = path.join(packageRoot, 'install.sh');

  if (!fs.existsSync(installScript)) {
    console.error('Error: install.sh not found in package. This is a packaging bug.');
    console.error(`Expected at: ${installScript}`);
    process.exit(1);
  }

  // Forward remaining args to install.sh
  const installArgs = args.slice(1); // Remove 'install' command

  // Determine the shell to use
  const shell = process.platform === 'win32' ? 'bash' : '/bin/bash';

  try {
    const child = spawn(shell, [installScript, ...installArgs], {
      stdio: 'inherit',
      cwd: process.cwd(),
      env: { ...process.env }
    });

    child.on('error', (err) => {
      if (err.code === 'ENOENT') {
        console.error('Error: bash is required but not found.');
        console.error('On Windows, install Git Bash or WSL.');
        process.exit(1);
      }
      console.error(`Error: ${err.message}`);
      process.exit(1);
    });

    child.on('close', (code) => {
      process.exit(code || 0);
    });
  } catch (err) {
    console.error(`Failed to run installer: ${err.message}`);
    process.exit(1);
  }
}

main();
