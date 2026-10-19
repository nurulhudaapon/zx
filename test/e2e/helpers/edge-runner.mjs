// Serves a wasm32-wasi Ziex app through the Cloudflare adapter in-process, the way
// workerd does (JSPI enabled), in both instance modes: fresh per request and reused.
// Usage: node --experimental-wasm-jspi edge-runner.mjs <wasm> <cloudflareBindings> <iterations> <warmup> <path...>
import { readFileSync } from 'node:fs';
import { performance } from 'node:perf_hooks';
import { pathToFileURL } from 'node:url';
import { DatabaseSync } from 'node:sqlite';

const [wasmPath, bindingsPath, iterationsArg, warmupArg, ...paths] = process.argv.slice(2);
const iterations = Number(iterationsArg);
const warmup = Number(warmupArg);

if (typeof WebAssembly.Suspending !== 'function') throw new Error('JSPI unavailable: run with --experimental-wasm-jspi');

const bytes = readFileSync(wasmPath);
const module = new WebAssembly.Module(bytes);
const { Ziex } = await import(pathToFileURL(bindingsPath).href);

let instantiations = 0;
let instantiateMs = 0;
const RealInstance = WebAssembly.Instance;
WebAssembly.Instance = function (mod, imports) {
  const start = performance.now();
  const instance = new RealInstance(mod, imports);
  instantiateMs += performance.now() - start;
  instantiations++;
  return instance;
};

const env = { DB: d1(new DatabaseSync(':memory:')) };

async function bench(reuse) {
  const app = new Ziex({ module, db: 'DB', reuse });
  const call = async (path) => {
    const res = await app.fetch(new Request(`https://edge.test${path}`), env, { waitUntil() {} });
    return { status: res.status, body: await res.text() };
  };

  const results = {};
  for (const path of paths) {
    const first = await call(path);
    for (let i = 0; i < warmup; i++) await call(path);

    instantiations = 0;
    instantiateMs = 0;
    const cpuStart = process.cpuUsage();
    const wallStart = performance.now();
    for (let i = 0; i < iterations; i++) await call(path);
    const wallMs = performance.now() - wallStart;
    const cpu = process.cpuUsage(cpuStart);

    results[path] = {
      status: first.status,
      body: first.body,
      wallMs: wallMs / iterations,
      cpuMs: (cpu.user + cpu.system) / 1000 / iterations,
      instantiateMs: instantiateMs / iterations,
      instantiations,
    };
  }
  return results;
}

process.stdout.write(JSON.stringify({
  initialMemoryBytes: initialMemoryBytes(bytes),
  fresh: await bench(false),
  reused: await bench(true),
}));

// Just enough of the D1 binding surface the ziex runtime uses.
function d1(sqlite) {
  return {
    prepare(sql) {
      const stmt = sqlite.prepare(sql);
      let args = [];
      return {
        bind(...values) { args = values; return this; },
        async run() {
          const r = stmt.run(...args);
          return { meta: { last_row_id: Number(r.lastInsertRowid), changes: r.changes } };
        },
        async raw() { return stmt.all(...args).map((row) => Object.values(row)); },
        async all() { return { results: stmt.all(...args) }; },
        async first() { return stmt.get(...args) ?? null; },
      };
    },
  };
}

function initialMemoryBytes(wasm) {
  const leb = (i) => {
    let value = 0, shift = 0, b;
    do { b = wasm[i++]; value |= (b & 0x7f) << shift; shift += 7; } while (b & 0x80);
    return [value >>> 0, i];
  };
  for (let i = 8; i < wasm.length;) {
    const id = wasm[i];
    const [size, body] = leb(i + 1);
    if (id === 5) {
      const [, flagsAt] = leb(body);
      const [pages] = leb(flagsAt + 1);
      return pages * 65536;
    }
    i = body + size;
  }
  throw new Error('wasm module defines no memory');
}
