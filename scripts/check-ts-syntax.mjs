import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..');
const req = createRequire(path.join(root, 'ui', 'package.json'));
let ts;
try { ts = req('typescript'); }
catch {
  // The release environment may not have frontend dependencies installed. The real CI job does.
  process.exit(0);
}

const units = [];
function walk(dir) {
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    if (['node_modules', '.svelte-kit', 'build'].includes(entry.name)) continue;
    const p = path.join(dir, entry.name);
    if (entry.isDirectory()) walk(p);
    else if (/\.(ts|mts|cts)$/.test(entry.name) && !entry.name.endsWith('.d.ts')) {
      units.push({ file: p, label: p, source: fs.readFileSync(p, 'utf8') });
    } else if (entry.name.endsWith('.svelte')) {
      const source = fs.readFileSync(p, 'utf8');
      const re = /<script\b([^>]*)>([\s\S]*?)<\/script>/gi;
      let m;
      let n = 0;
      while ((m = re.exec(source))) {
        // Only TypeScript scripts. (The current tree uses lang="ts" throughout its logic.)
        if (!/\blang\s*=\s*["']ts["']/i.test(m[1])) continue;
        n += 1;
        units.push({ file: p, label: `${p}#script${n}`, source: m[2] });
      }
    }
  }
}
walk(path.join(root, 'ui', 'src'));

let failed = false;
for (const unit of units) {
  const out = ts.transpileModule(unit.source, {
    fileName: unit.label,
    reportDiagnostics: true,
    compilerOptions: { target: ts.ScriptTarget.ES2022, module: ts.ModuleKind.ESNext }
  });
  for (const d of out.diagnostics ?? []) {
    if (d.category !== ts.DiagnosticCategory.Error) continue;
    failed = true;
    const text = ts.flattenDiagnosticMessageText(d.messageText, '\n');
    const pos = d.file && typeof d.start === 'number' ? d.file.getLineAndCharacterOfPosition(d.start) : null;
    console.error(`${path.relative(root, unit.file)}${pos ? `:${pos.line + 1}:${pos.character + 1}` : ''}: ${text}`);
  }
}
if (failed) process.exit(1);
console.log(`TypeScript syntax: ${units.length} units OK`);
