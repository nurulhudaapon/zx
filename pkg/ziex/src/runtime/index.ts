import { ZxWasiBridge } from "../wasm/wasi";
import { createFetchImports } from "./fetch";
import { createKVImports } from "./kv/extern";
import { createDbImports } from "./db/extern";
import { bindWasmAlloc, type WasmAllocRef } from "../wasm/core";
import { createWasiImports, ProcExit, mergeUint8Arrays } from "./wasi";
import type { WASI } from "./wasi";
import type { KVNamespace } from "./kv";
import { get, put, del, list } from "./kv/memory";
import type { Database } from "./db";

/** Minimal sticky long-lived fetch namespace shape (e.g. Cloudflare Durable Object binding). */
export type StickyNamespace = {
    idFromName(name: string): unknown;
    // Host stubs take a concrete id type; `any` keeps Env key inference workable.
    get(id: any): { fetch(request: Request): Promise<Response> };
};

export type WsState = {
    upgraded: boolean;
    server: WebSocket | null;
    pendingWrites: Uint8Array[];
    messageQueue: Uint8Array[];
    recvResolve: ((bytes: Uint8Array | null) => void) | null;
    /** Resolved when ws_recv is called for the first time (WASM has entered the message loop). */
    _resolveFirstSuspend?: () => void;
    // Optional pub/sub callbacks (used by sticky handlers)
    subscribe?: (topic: string) => void;
    unsubscribe?: (topic: string) => void;
    publish?: (topic: string, data: Uint8Array) => number;
    isSubscribed?: (topic: string) => boolean;
};

type HttpState = {
    committed: boolean;
    ended: boolean;
    status: number;
    streaming: boolean;
    headers: Headers;
    bodyChunks: Uint8Array[];
    streamWriter: WritableStreamDefaultWriter<Uint8Array> | null;
};

export function buildHttpImports(
    mem: () => WebAssembly.Memory,
    http: HttpState,
): WebAssembly.ModuleImports {
    const decoder = new TextDecoder();
    return {
        commit: (status: number, meta_ptr: number, meta_len: number): void => {
            http.status = status >>> 0;
            http.committed = true;
            http.headers = new Headers();
            http.streaming = false;
            if (meta_len > 0) {
                try {
                    const raw = decoder.decode(new Uint8Array(mem().buffer, meta_ptr >>> 0, meta_len >>> 0));
                    const parsed = JSON.parse(raw) as {
                        streaming?: boolean;
                        headers?: [string, string][];
                    };
                    if (parsed.streaming === true) http.streaming = true;
                    if (Array.isArray(parsed.headers)) {
                        for (const [name, value] of parsed.headers) {
                            http.headers.append(name, value);
                        }
                    }
                } catch {
                    // keep defaults
                }
            }
        },
        write: (ptr: number, len: number): void => {
            if (len <= 0) return;
            const chunk = new Uint8Array(mem().buffer, ptr >>> 0, len >>> 0).slice();
            if (http.streamWriter) void http.streamWriter.write(chunk);
            else http.bodyChunks.push(chunk);
        },
        end: (): void => {
            http.ended = true;
            if (http.streamWriter) {
                void http.streamWriter.close();
                http.streamWriter = null;
            }
        },
    };
}

/** Build the __zx_ws import object for a given connection state. */
export function buildWsImports(
    Suspending: any,
    mem: () => WebAssembly.Memory,
    decoder: TextDecoder,
    ws: WsState,
): WebAssembly.ModuleImports {
    const readStr = (ptr: number, len: number) =>
        decoder.decode(new Uint8Array(mem().buffer, ptr, len));

    return {
        ws_upgrade: (): void => { ws.upgraded = true; },
        ws_write: (ptr: number, len: number): void => {
            const data = new Uint8Array(mem().buffer, ptr, len).slice();
            if (!ws.server) {
                ws.pendingWrites.push(data); // buffer until server is set
            } else {
                ws.server.send(data);
            }
        },
        ws_close: (code: number, reason_ptr: number, reason_len: number): void => {
            ws.server?.close(code, decoder.decode(new Uint8Array(mem().buffer, reason_ptr, reason_len)));
        },
        ws_recv: Suspending ? new Suspending(async (buf_ptr: number, buf_max: number): Promise<number> => {
            // Signal that WASM has reached the receive loop (upgrade has happened).
            if (ws._resolveFirstSuspend) {
                const fn = ws._resolveFirstSuspend;
                ws._resolveFirstSuspend = undefined;
                fn();
            }
            const deliver = (bytes: Uint8Array | null): number => {
                if (bytes === null) return -1;
                const n = Math.min(bytes.length, buf_max);
                new Uint8Array(mem().buffer, buf_ptr, n).set(bytes.subarray(0, n));
                return n;
            };
            if (ws.messageQueue.length > 0) return deliver(ws.messageQueue.shift()!);
            return new Promise<number>((resolve) => {
                ws.recvResolve = (bytes) => resolve(deliver(bytes));
            });
        }) : (_buf_ptr: number, _buf_max: number): number => -1,
        // Pub/sub - delegates to optional callbacks (real in DO, no-ops otherwise)
        ws_subscribe: (ptr: number, len: number): void => { ws.subscribe?.(readStr(ptr, len)); },
        ws_unsubscribe: (ptr: number, len: number): void => { ws.unsubscribe?.(readStr(ptr, len)); },
        ws_publish: (topic_ptr: number, topic_len: number, data_ptr: number, data_len: number): number => {
            const topic = readStr(topic_ptr, topic_len);
            const data = new Uint8Array(mem().buffer, data_ptr, data_len).slice();
            return ws.publish?.(topic, data) ?? 0;
        },
        ws_is_subscribed: (ptr: number, len: number): number =>
            ws.isSubscribed?.(readStr(ptr, len)) ? 1 : 0,
    };
}

/** Create WebSocketPair, wire message/close listeners, flush pending writes. */
export function attachWebSocket(ws: WsState): { client: WebSocket } {
    const WebSocketPairCtor = (globalThis as any).WebSocketPair as new () => { 0: WebSocket; 1: WebSocket };
    const pair = new WebSocketPairCtor();
    const client = pair[0];
    const server = pair[1] as WebSocket & { accept(): void };
    ws.server = server;
    server.accept();

    // Flush writes that happened during socket_open (before server was set)
    for (const data of ws.pendingWrites) server.send(data as BufferSource);
    ws.pendingWrites = [];

    server.addEventListener("message", (event: MessageEvent) => {
        const data = typeof event.data === "string"
            ? new TextEncoder().encode(event.data)
            : new Uint8Array(event.data as ArrayBuffer);
        if (ws.recvResolve) {
            const res = ws.recvResolve; ws.recvResolve = null; res(data);
        } else {
            ws.messageQueue.push(data);
        }
    });

    server.addEventListener("close", () => {
        if (ws.recvResolve) {
            const res = ws.recvResolve; ws.recvResolve = null; res(null);
        }
    });

    return { client };
}

/**
 * Build the `__zx_sys` import object.
 * `sleep_ms` pauses WASM under JSPI so body chunks reach the client
 * incrementally; falls back to a sync no-op when JSPI is unavailable.
 */
function buildSysImports(jspi: boolean, Suspending: any, onPark?: () => void): WebAssembly.ModuleImports {
    return {
        sleep_ms: jspi
            ? new Suspending(async (ms: number) => new Promise<void>(r => setTimeout(r, ms)))
            : (_ms: number) => {},
        // `park` never resolves: the instance stays initialized and serves via `__zx_serve`.
        park: jspi
            ? new Suspending(() => {
                onPark?.();
                return new Promise<void>(() => {});
            })
            : () => {
                throw new Error("park requires WebAssembly JSPI");
            },
    };
}

/**
 * Start the WASM module and return a promise that resolves when it exits.
 * Under JSPI the module runs asynchronously with streaming body writes; without
 * JSPI it runs synchronously and buffers all output.
 */
function executeWasm(
    instance: WebAssembly.Instance,
    jspi: boolean,
    Suspending: any,
    wsState: WsState,
): Promise<void> {
    if (!jspi) {
        try {
            (instance.exports._start as Function)();
        } catch (e) {
            if (!(e instanceof ProcExit)) throw e;
        }
        return Promise.resolve();
    }

    // NOTE: no await - start() runs synchronously until the first Suspending
    // call (typically sleep_ms mid-stream or ws_recv). By then Zig has usually
    // called __zx_http.commit for streaming pages.
    const start = (WebAssembly as any).promising(instance.exports._start as Function);
    return (start() as Promise<void>)
        .catch((e: unknown) => {
            if (e instanceof Error && e.message.startsWith("proc_exit")) return;
            throw e;
        })
        .finally(() => {
            // Unblock any pending ws_recv on exit/error
            if (wsState.recvResolve) {
                const res = wsState.recvResolve;
                wsState.recvResolve = null;
                res(null);
            }
        });
}

/**
 * Run a WASM module for a single request using JSPI.
 *
 * Pass `kv` as a map of binding names → KV namespaces. The Zig side selects
 * a binding via `zx.kv.scoped("name")`; the top-level `zx.kv.*` functions use
 * `"default"`.
 *
 * @example
 * ```ts
 * return run({
 *   request, env, ctx, module,
 *   kv: { default: env.KV, users: env.USERS_KV },
 * });
 * ```
 */
export async function run({
    request,
    env,
    ctx,
    module,
    kv: kvBindings,
    db: dbBindings,
    imports,
    wasi,
    sticky,
    reuse = true,
}: {
    request: Request;
    env?: unknown;
    ctx?: { waitUntil(promise: Promise<unknown>): void };
    module: WebAssembly.Module;
    /** KV namespace bindings - `{ default: env.KV, otherName: env.OTHER_KV }` */
    kv?: Record<string, KVNamespace>;
    /** DB bindings - `{ default: env.DB, analytics: env.ANALYTICS_DB }` */
    db?: Record<string, Database>;
    imports?: (mem: () => WebAssembly.Memory) => WebAssembly.Imports;
    wasi?: WASI;
    /**
     * Sticky namespace for long-lived fetch (WebSocket upgrades).
     * When provided, upgrade requests are forwarded so pub/sub works across clients.
     */
    sticky?: StickyNamespace;
    /**
     * Reuse initialized instances across requests when the module supports it
     * (exports `__zx_serve`). Each instance serves one request at a time.
     */
    reuse?: boolean;
}): Promise<Response> {
    const isUpgrade = request.headers.get("upgrade")?.toLowerCase() === "websocket";

    // Route WebSocket upgrades to the sticky handler so pub/sub works
    // across all connected clients sharing the same instance.
    if (sticky && isUpgrade) {
        const id = sticky.idFromName(new URL(request.url).pathname);
        return sticky.get(id).fetch(request);
    }

    const stdinData = request.body
        ? new Uint8Array(await request.arrayBuffer())
        : undefined;

    const Suspending = (WebAssembly as any).Suspending;
    const jspi = typeof Suspending === 'function';
    const kv = kvBindings ?? { default: { get, put, del, list } };
    const db = dbBindings ?? {};

    if (reuse && jspi && !isUpgrade && supportsReuse(module)) {
        return serveReused({ module, request, stdinData, kv, db, imports, wasi, Suspending });
    }

    const http = newHttpState();
    const wsState = newWsState();
    const { instance } = instantiate({ module, request, stdinData, kv, db, imports, wasi, jspi, Suspending, http, wsState });
    const wasmPromise = executeWasm(instance, jspi, Suspending, wsState);

    // After start(), WASM has run synchronously until its first Suspending call.
    // For WebSocket routes, that first suspension is ws_recv (after the upgrade
    // call in the Route handler), so wsState.upgraded is already true here.
    if (wsState.upgraded) {
        const server = attachWebSocket(wsState);
        // Keep the Worker alive while WASM processes the WebSocket message loop.
        ctx?.waitUntil(wasmPromise);
        return new Response(null, { status: 101, webSocket: server.client } as ResponseInit);
    }

    return toResponse(http, wasmPromise);
}

function newHttpState(): HttpState {
    return {
        committed: false,
        ended: false,
        status: 200,
        streaming: false,
        headers: new Headers(),
        bodyChunks: [],
        streamWriter: null,
    };
}

function newWsState(): WsState {
    return {
        upgraded: false,
        server: null,
        pendingWrites: [],
        messageQueue: [],
        recvResolve: null,
    };
}

function instantiate({
    module, request, stdinData, kv, db, imports, wasi, jspi, Suspending, http, wsState, extraArgs, onPark,
}: {
    module: WebAssembly.Module;
    request: Request;
    stdinData?: Uint8Array;
    kv: Record<string, KVNamespace>;
    db: Record<string, Database>;
    imports?: (mem: () => WebAssembly.Memory) => WebAssembly.Imports;
    wasi?: WASI;
    jspi: boolean;
    Suspending: any;
    http: HttpState;
    wsState: WsState;
    extraArgs?: string[];
    onPark?: () => void;
}) {
    const { wasiImport, setMemory, setRequest } = createWasiImports({ request, stdinData, extraArgs });

    let wasmMemory: WebAssembly.Memory = null!;
    const mem = () => wasmMemory;
    const bridgeRef: [ZxWasiBridge | null] = [null];
    const allocRef: WasmAllocRef = [null];

    const importObject: WebAssembly.Imports = {
        wasi_snapshot_preview1: { ...wasi?.wasiImport, ...wasiImport },
        __zx_sys: buildSysImports(jspi, Suspending, onPark),
        __zx_ws: buildWsImports(jspi ? Suspending : null, mem, new TextDecoder(), wsState),
        __zx_http: buildHttpImports(mem, http),
        __zx_net: createFetchImports(mem),
        ...(imports ? imports(mem) : {}),
        ...ZxWasiBridge.createImportObject(bridgeRef),
    };
    if (typeof __FEAT_KV_SERVER__ === "undefined" || __FEAT_KV_SERVER__) {
        importObject.__zx_kv = createKVImports(kv, mem, allocRef);
    }
    if (typeof __FEAT_DB__ === "undefined" || __FEAT_DB__) {
        importObject.__zx_db = createDbImports(db, mem, allocRef);
    }

    const instance = new WebAssembly.Instance(module, importObject);
    wasmMemory = instance.exports.memory as WebAssembly.Memory;
    setMemory(wasmMemory);
    bridgeRef[0] = new ZxWasiBridge(instance.exports);
    bindWasmAlloc(allocRef, instance.exports);
    return { instance, setRequest, memory: mem };
}

async function toResponse(http: HttpState, done: Promise<void>): Promise<Response> {
    if (http.committed && http.streaming) {
        const { readable, writable } = new TransformStream<Uint8Array, Uint8Array>();
        http.streamWriter = writable.getWriter();
        for (const chunk of http.bodyChunks) void http.streamWriter.write(chunk);
        http.bodyChunks.length = 0;
        void done.finally(() => {
            if (http.streamWriter) {
                void http.streamWriter.close();
                http.streamWriter = null;
            }
        });
        return new Response(readable, { status: http.status, headers: http.headers });
    }

    await done;

    const status = http.status;
    const headers = http.headers;
    headers.delete('transfer-encoding');

    // 101/204/205/304 must use a null body (Workers warns on empty ArrayBuffer).
    const nullBody = status === 101 || status === 204 || status === 205 || status === 304;
    if (nullBody) {
        headers.delete('content-length');
        return new Response(null, { status, headers });
    }

    const body = mergeUint8Arrays(http.bodyChunks);
    if (!headers.has('content-length')) headers.set('content-length', String(body.byteLength));
    return new Response(body.buffer as ArrayBuffer, { status, headers });
}

// --- Instance reuse --- //

const MAX_IDLE_INSTANCES = 4;
const MAX_REQUESTS_PER_INSTANCE = 1000;
const MAX_INSTANCE_MEMORY = 64 * 1024 * 1024;

type ReusableInstance = {
    serve: () => Promise<void>;
    setRequest: (request: Request, stdin?: Uint8Array) => void;
    memory: () => WebAssembly.Memory;
    http: HttpState;
    kv: Record<string, KVNamespace>;
    db: Record<string, Database>;
    served: number;
};

const reuseSupport = new WeakMap<WebAssembly.Module, boolean>();
const idleInstances = new WeakMap<WebAssembly.Module, ReusableInstance[]>();

function supportsReuse(module: WebAssembly.Module): boolean {
    let supported = reuseSupport.get(module);
    if (supported === undefined) {
        supported = WebAssembly.Module.exports(module).some((e) => e.name === "__zx_serve");
        reuseSupport.set(module, supported);
    }
    return supported;
}

async function createReusable(opts: {
    module: WebAssembly.Module;
    request: Request;
    stdinData?: Uint8Array;
    kv: Record<string, KVNamespace>;
    db: Record<string, Database>;
    imports?: (mem: () => WebAssembly.Memory) => WebAssembly.Imports;
    wasi?: WASI;
    Suspending: any;
}): Promise<ReusableInstance> {
    const http = newHttpState();
    // Live binding maps: refreshed per request so each request uses its own env.
    const kv = { ...opts.kv };
    const db = { ...opts.db };

    let onPark!: () => void;
    const parked = new Promise<void>((resolve) => { onPark = resolve; });
    const { instance, setRequest, memory } = instantiate({
        ...opts, kv, db, http, wsState: newWsState(), jspi: true, extraArgs: ["--zx-reuse"], onPark,
    });

    const promising = (WebAssembly as any).promising;
    const exited = (promising(instance.exports._start as Function)() as Promise<void>).then(
        () => { throw new Error("ziex: wasm exited before parking for reuse"); },
        (e: unknown) => { throw e; },
    );
    await Promise.race([parked, exited]);

    return { serve: promising(instance.exports.__zx_serve as Function), setRequest, memory, http, kv, db, served: 0 };
}

async function serveReused(opts: {
    module: WebAssembly.Module;
    request: Request;
    stdinData?: Uint8Array;
    kv: Record<string, KVNamespace>;
    db: Record<string, Database>;
    imports?: (mem: () => WebAssembly.Memory) => WebAssembly.Imports;
    wasi?: WASI;
    Suspending: any;
}): Promise<Response> {
    let idle = idleInstances.get(opts.module);
    if (!idle) idleInstances.set(opts.module, (idle = []));

    const reused = idle.pop();
    const inst = reused ?? await createReusable(opts);
    if (reused) inst.setRequest(opts.request, opts.stdinData);
    Object.assign(inst.http, newHttpState());
    replaceEntries(inst.kv, opts.kv);
    replaceEntries(inst.db, opts.db);

    const done = inst.serve().then(
        () => {
            inst.served++;
            const healthy = inst.served < MAX_REQUESTS_PER_INSTANCE &&
                inst.memory().buffer.byteLength <= MAX_INSTANCE_MEMORY;
            if (healthy && idle.length < MAX_IDLE_INSTANCES) idle.push(inst);
        },
        (e: unknown) => {
            // A trapped instance may hold corrupt state: never return it to the pool.
            if (e instanceof Error && e.message.startsWith("proc_exit")) return;
            throw e;
        },
    );
    return toResponse(inst.http, done);
}

function replaceEntries<T>(target: Record<string, T>, source: Record<string, T>): void {
    for (const key of Object.keys(target)) delete target[key];
    Object.assign(target, source);
}
