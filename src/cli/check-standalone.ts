#!/usr/bin/env node
import { Command } from 'commander';
import { registerCheckCommand } from '../commands/check.js';

const program = new Command()
  .name('saascode-check')
  .description('Endpoint parity checker — find mismatches between frontend API calls and backend routes')
  .version('2.0.0');

registerCheckCommand(program);

program.parse();
