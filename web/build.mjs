// Builds the static site into web/dist (upload that folder to Hostinger).
import { build } from 'esbuild';
import { cp, mkdir, rm } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const src = join(here, 'src');
const out = join(here, 'dist');

await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });
await build({
  entryPoints: { app: join(src, 'app.js'), admin: join(src, 'admin.js') },
  outdir: out,
  bundle: true,
  format: 'esm',
  splitting: true,
  chunkNames: 'chunks/[name]-[hash]',
  minify: true,
  sourcemap: false,
  target: ['es2022'],
  legalComments: 'none',
  logLevel: 'warning',
});
for (const f of ['index.html', 'admin.html', 'styles.css', 'privacy.html', 'delete-account.html', 'policy.css']) await cp(join(src, f), join(out, f));
await cp(join(here, '.htaccess'), join(out, '.htaccess'));
console.log('Built web/dist');
