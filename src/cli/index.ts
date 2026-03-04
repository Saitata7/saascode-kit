#!/usr/bin/env node
import { Command } from 'commander';
import { registerInitCommand } from '../commands/init.js';
import { registerCheckCommand } from '../commands/check.js';
import { registerReviewCommand } from '../commands/review.js';
import { registerAddCommand } from '../commands/add.js';
import { registerRecommendCommand } from '../commands/recommend.js';

const program = new Command()
  .name('saascode')
  .description('SaaS development guardrails. Free. Offline. Deterministic.')
  .version('2.0.0');

registerInitCommand(program);
registerCheckCommand(program);
registerReviewCommand(program);
registerAddCommand(program);
registerRecommendCommand(program);

program.parse();
