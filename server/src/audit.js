import { readFileSync } from 'node:fs';
import { config } from './config.js';

// Loaded once at start; restart the server after re-running the engine.
export const audit = JSON.parse(readFileSync(config.auditPath, 'utf8'));
