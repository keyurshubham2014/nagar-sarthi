import { fileURLToPath } from 'node:url';
import path from 'node:path';

const here = path.dirname(fileURLToPath(import.meta.url));
export const serverRoot = path.resolve(here, '..');
const repoRoot = path.resolve(serverRoot, '..');

// server/.env is optional; real env vars win because loadEnvFile never overrides them.
try {
  process.loadEnvFile(path.join(serverRoot, '.env'));
} catch (e) {
  if (e.code !== 'ENOENT') throw e;
}

export const config = {
  port: Number(process.env.PORT ?? 8787),
  auditPath: process.env.AUDIT_PATH ?? path.join(repoRoot, 'engine', 'out', 'audit.json'),
  databaseUrl:
    process.env.DATABASE_URL ?? 'postgres://nagar:nagar@localhost:5435/nagar_sarthi',
  claudeModel: process.env.CLAUDE_MODEL ?? 'claude-sonnet-5-5',
  claudeTimeoutMs: Number(process.env.CLAUDE_TIMEOUT_MS ?? 20000),
  fallbacksDir: path.join(serverRoot, 'fallbacks'),
  demoLoginCode: process.env.DEMO_LOGIN_CODE || '246810',
  // On for the stage demo: the app's "Demo:" shortcuts read the code from GET /api/auth/demo.
  demoShortcuts: (process.env.DEMO_SHORTCUTS ?? 'on') !== 'off',
};

// Read lazily so the key never sits in the exported config object.
export const anthropicKey = () => process.env.ANTHROPIC_API_KEY || null;
// shortcut: dev default secret, set AUTH_SECRET anywhere beyond a laptop demo.
export const authSecret = () => process.env.AUTH_SECRET || 'nagar-sarthi-dev-only-secret';
