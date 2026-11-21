import { readFile } from 'node:fs/promises';
import path from 'node:path';
import Anthropic from '@anthropic-ai/sdk';
import { config, anthropicKey } from './config.js';
import { notFound, badRequest } from './errors.js';
import { notice } from './notice.js';
import { brief } from './brief.js';

/**
 * Claude feature registry. Later tasks add entries (notice, brief, intake, question):
 *   features.notice = {
 *     prepare?(body, audit) -> ctx  // optional: validate (throw ApiError for 4xx), select rows
 *     buildPrompt(body, audit, ctx) -> { system?, prompt, maxTokens? },
 *     fallbackKey(body) -> string   // key into server/fallbacks/notice.json
 *   }
 * Fallback text may use {{name}} tokens, filled from ctx.vars (see notice.js).
 * and create server/fallbacks/<name>.json with a "default" entry.
 * body is the parsed request JSON (always an object); validate what you read from it.
 */
export const features = {
  ping: {
    buildPrompt: (body) => ({
      prompt: `Reply with one short friendly sentence confirming you are reachable. ${
        typeof body.message === 'string' ? `The caller says: ${body.message.slice(0, 200)}` : ''
      }`,
      maxTokens: 60,
    }),
    fallbackKey: (body) => (typeof body.key === 'string' ? body.key : 'default'),
  },
  notice,
  brief,
};

// Fallback text may hold {{name}} tokens, filled from prepare()'s `vars`.
const fill = (text, vars = {}) => text.replace(/\{\{(\w+)\}\}/g, (m, k) => (Object.hasOwn(vars, k) ? vars[k] : m));

let client;
function getClient() {
  const key = anthropicKey();
  if (!key) return null;
  client ??= new Anthropic({ apiKey: key, maxRetries: 0 });
  return client;
}

async function fallbackText(name, key) {
  try {
    const table = JSON.parse(await readFile(path.join(config.fallbacksDir, `${name}.json`), 'utf8'));
    // key comes from the client: own string entries only (no '__proto__' and the like).
    const text = Object.hasOwn(table, key) ? table[key] : table.default;
    return typeof text === 'string' ? text : typeof table.default === 'string' ? table.default : '';
  } catch (e) {
    console.warn(`[claude] fallback file for ${name} unreadable: ${e.message}`);
    return '';
  }
}

/** Returns {text, source: 'live'|'fallback'}. Never throws for Claude failures. */
export async function relay(name, body, audit) {
  const feature = Object.hasOwn(features, name) ? features[name] : null;
  if (!feature) throw notFound(`Claude feature '${name}'`);
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw badRequest('Body must be a JSON object');
  }
  // Optional prepare(body, audit): validates input (throws 4xx) and selects data for prompt and fallback.
  const ctx = feature.prepare ? feature.prepare(body, audit) : {};

  const c = getClient();
  if (c) {
    const started = Date.now();
    try {
      const { system, prompt, maxTokens = 1024 } = feature.buildPrompt(body, audit, ctx);
      const msg = await c.messages.create(
        {
          model: config.claudeModel,
          max_tokens: maxTokens,
          ...(system ? { system } : {}),
          messages: [{ role: 'user', content: prompt }],
        },
        { timeout: config.claudeTimeoutMs },
      );
      const text = msg.content.filter((b) => b.type === 'text').map((b) => b.text).join('');
      if (text) {
        console.log(`[claude] ${name} live in ${Date.now() - started} ms`);
        return { text, source: 'live' };
      }
      console.warn(`[claude] ${name} returned no text, using fallback`);
    } catch (e) {
      // Log status/name only: SDK error messages can echo request details.
      console.warn(`[claude] ${name} failed after ${Date.now() - started} ms (${e.status ?? e.name}), using fallback`);
    }
  } else {
    console.warn(`[claude] ${name}: ANTHROPIC_API_KEY not set, using fallback`);
  }

  let key = 'default';
  try {
    key = String(feature.fallbackKey(body) ?? 'default');
  } catch {
    /* bad body shape: default entry */
  }
  return { text: fill(await fallbackText(name, key), ctx.vars), source: 'fallback' };
}
