import { test, expect } from '@playwright/test';
import { spawnSync } from 'node:child_process';
import { join } from 'node:path';
import { isEdgeRuntime } from '../../helpers/env';

/**
 * Edge runtime specifics for the site served by workerd (`E2E_RUNTIME=edge`).
 * The rest of the suite runs unchanged against the same server.
 *
 *   E2E_RUNTIME=edge npx playwright test specs/edge --workers=1 --retries=0
 *
 * Uses the wasm32-wasi build `wrangler dev` produced. Instance counts and per-request
 * cost are measured in Node (JSPI, like workerd) with the Cloudflare adapter.
 *
 * Env:
 *   EDGE_BENCH_ITERS        measured requests per path (default 200)
 *   EDGE_BENCH_WARMUP       discarded warmup requests (default 30)
 *   EDGE_BENCH_MAX_CPU_MS   optional per-request CPU budget for reused instances
 */
const ITERS = Math.max(1, Number(process.env.EDGE_BENCH_ITERS ?? 200));
const WARMUP = Math.max(0, Number(process.env.EDGE_BENCH_WARMUP ?? 30));
const MAX_CPU_MS = process.env.EDGE_BENCH_MAX_CPU_MS ? Number(process.env.EDGE_BENCH_MAX_CPU_MS) : undefined;
const MAX_INITIAL_MEMORY_BYTES = 4 * 1024 * 1024;

const siteOut = join(__dirname, '../../../../site/zig-out');
const runner = join(__dirname, '../../helpers/edge-runner.mjs');

const pages: Record<string, { status: number; marker: string }> = {
  '/': { status: 200, marker: 'hero-title-main' },
  '/learn': { status: 200, marker: '<h1>Quick Start' },
  '/reference': { status: 200, marker: '<h1>API Reference' },
  '/examples/counter': { status: 200, marker: '<h1>Counter' },
  '/examples/todo': { status: 200, marker: '<h1>Todo app' },
  '/does-not-exist': { status: 404, marker: '404 - Page Not Found' },
};
const BENCH_PATHS = ['/', '/examples/counter'];

type PathResult = { status: number; body: string; wallMs: number; cpuMs: number; instantiateMs: number; instantiations: number };
type RunnerOutput = { initialMemoryBytes: number; fresh: Record<string, PathResult>; reused: Record<string, PathResult> };

test.use({ video: 'off', screenshot: 'off', trace: 'off' });

test.describe('Edge runtime', () => {
  test.skip(!isEdgeRuntime, 'set E2E_RUNTIME=edge');

  test('interleaved requests each get their own response', async ({ request }) => {
    for (const path of [...Object.keys(pages), ...Object.keys(pages).reverse()]) {
      const res = await request.get(path);
      expect(res.status(), path).toBe(pages[path].status);
      expect(await res.text(), path).toContain(pages[path].marker);
    }
  });

  test('concurrent requests each get their own response', async ({ request }) => {
    const paths = Array.from({ length: 4 }, () => Object.keys(pages)).flat();
    const replies = await Promise.all(paths.map(async (path) => {
      const res = await request.get(path);
      return { path, status: res.status(), body: await res.text() };
    }));
    for (const { path, status, body } of replies) {
      expect(status, path).toBe(pages[path].status);
      expect(body, path).toContain(pages[path].marker);
    }
  });

  test.describe('instances (in-process)', () => {
    test.describe.configure({ mode: 'serial', retries: 0, timeout: 5 * 60_000 });
    let output: RunnerOutput;

    test.beforeAll(() => {
      const run = spawnSync(
        process.execPath,
        [
          '--experimental-wasm-jspi',
          '--no-warnings',
          runner,
          join(siteOut, 'bin/ziex_dev.wasm'),
          join(siteOut, 'pkg/ziex/platforms/cloudflare/index.js'),
          String(ITERS),
          String(WARMUP),
          ...BENCH_PATHS,
        ],
        { encoding: 'utf8', maxBuffer: 64 * 1024 * 1024 },
      );
      expect(run.status, run.stderr).toBe(0);
      output = JSON.parse(run.stdout);
    });

    test('initial linear memory stays small', () => {
      expect(output.initialMemoryBytes).toBeLessThanOrEqual(MAX_INITIAL_MEMORY_BYTES);
    });

    test('fresh and reused instances render the same pages', () => {
      for (const path of BENCH_PATHS) {
        for (const mode of ['fresh', 'reused'] as const) {
          expect(output[mode][path].status, `${mode} ${path}`).toBe(pages[path].status);
          expect(output[mode][path].body, `${mode} ${path}`).toContain(pages[path].marker);
        }
      }
    });

    test('fresh mode instantiates per request, reused mode does not', () => {
      for (const path of BENCH_PATHS) {
        expect(output.fresh[path].instantiations).toBe(ITERS);
        expect(output.reused[path].instantiations).toBe(0);
      }
    });

    test('per-request cost', () => {
      const rows = BENCH_PATHS.flatMap((path) =>
        (['fresh', 'reused'] as const).map((mode) => {
          const r = output[mode][path];
          return {
            path,
            mode,
            'wall ms': r.wallMs.toFixed(3),
            'cpu ms': r.cpuMs.toFixed(3),
            'instantiate ms': r.instantiateMs.toFixed(3),
            instantiations: r.instantiations,
          };
        }),
      );
      console.log(
        `\nEdge runtime @ site (${ITERS} requests, ${WARMUP} warmup, initial memory ${(output.initialMemoryBytes / 1048576).toFixed(2)} MiB)`,
      );
      console.table(rows);

      if (MAX_CPU_MS !== undefined) {
        for (const path of BENCH_PATHS) {
          expect(output.reused[path].cpuMs, `${path} CPU per request`).toBeLessThanOrEqual(MAX_CPU_MS);
        }
      }
    });
  });
});
