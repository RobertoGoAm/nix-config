#!/usr/bin/env node
/**
 * PostToolUse gate for code comments. Flags comments an Edit/Write ADDS to a code file that fall
 * outside the allowed set — JSDoc (`/** ... *\/`), eslint/ts directives, tooling markers, or a
 * genuinely-obscure-code explanation. Exit 2 feeds the list back so they get removed. Fail-open:
 * any error exits 0 so real work is never blocked.
 */
import process from 'node:process';

const CODE = /\.(?:ts|tsx|js|jsx|mjs|cjs)$/;
const ALLOWED = [
  /eslint-disable/,
  /eslint-enable/,
  /@ts-(?:expect-error|ignore|nocheck)/,
  /sourceMappingURL/,
  /\bcovers:/,
  /\bCoverage:/,
  /biome-ignore/,
  /prettier-ignore/,
  /@ts-check/,
];

function stripStrings(line) {
  return line
    .replace(/'(?:[^'\\]|\\.)*'/g, "''")
    .replace(/"(?:[^"\\]|\\.)*"/g, '""')
    .replace(/`(?:[^`\\]|\\.)*`/g, '``');
}

/** Comment lines (trimmed) in a blob, excluding JSDoc and allowed directives/markers. */
function offendingComments(blob) {
  const out = [];
  let inJsdoc = false;
  for (const rawLine of String(blob).split('\n')) {
    const line = rawLine.trim();
    if (inJsdoc) {
      if (line.includes('*/')) inJsdoc = false;
      continue;
    }
    if (line.startsWith('/**')) {
      if (!line.includes('*/')) inJsdoc = true;
      continue;
    }
    const code = stripStrings(rawLine);
    const lineIdx = code.indexOf('//');
    const blockIdx = code.indexOf('/*');
    let comment = '';
    if (lineIdx >= 0) comment = code.slice(lineIdx);
    else if (blockIdx >= 0) comment = code.slice(blockIdx);
    else continue;
    if (ALLOWED.some((re) => re.test(comment))) continue;
    out.push(line);
  }
  return out;
}

let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  try {
    const payload = JSON.parse(raw);
    const input = payload.tool_input ?? {};
    const file = input.file_path ?? '';
    if (!CODE.test(file)) process.exit(0);

    // Comments already present in what this call replaces are not "added" — ignore them.
    const priorRaw =
      typeof input.old_string === 'string'
        ? input.old_string
        : Array.isArray(input.edits)
          ? input.edits.map((e) => e?.old_string ?? '').join('\n')
          : '';
    const prior = new Set(offendingComments(priorRaw));

    let added = '';
    if (typeof input.new_string === 'string') added = input.new_string;
    else if (Array.isArray(input.edits)) added = input.edits.map((e) => e?.new_string ?? '').join('\n');
    else if (typeof input.content === 'string') added = input.content;

    const offenders = offendingComments(added).filter((c) => !prior.has(c));
    if (offenders.length === 0) process.exit(0);

    process.stderr.write(
      `[comment-policy] ${offenders.length} added comment(s) in ${file} are outside the allowed set ` +
        `(JSDoc, eslint/ts directives, tooling markers, or a genuinely-obscure-code explanation):\n` +
        offenders.map((c) => `  ${c}`).join('\n') +
        `\nRemove redundant, restating, or change-narrating comments — keep the code minimal. ` +
        `Explain a change in the gate or in chat, never in a code comment.\n`,
    );
    process.exit(2);
  } catch {
    process.exit(0);
  }
});
