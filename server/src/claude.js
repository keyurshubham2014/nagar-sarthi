import { readFile } from 'node:fs/promises';
import path from 'node:path';
import Anthropic from '@anthropic-ai/sdk';
import { config, anthropicKey } from './config.js';
import { notFound, badRequest } from './errors.js';

/**
 * Claude feature registry. Later tasks add entries (notice, brief, intake, question):
 *   features.notice = {
 *     buildPrompt(body, audit) -> { system?, prompt, maxTokens? },
 *     fallbackKey(body) -> string   // key into server/fallbacks/notice.json
 *   }
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
};

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
    return table[key] ?? table.default ?? '';
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

  const c = getClient();
  if (c) {
    const started = Date.now();
    try {
      const { system, prompt, maxTokens = 1024 } = feature.buildPrompt(body, audit);
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
  return { text: await fallbackText(name, key), source: 'fallback' };
}
