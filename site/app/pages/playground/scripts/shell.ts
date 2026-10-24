import { init, Terminal, FitAddon } from "ghostty-web";
import { Bash, defineCommand, getCommandNames } from "just-bash";
import type { OutputEvent } from "./terminal.ts";
import type { PlaygroundBuildArtifacts } from "./csr.ts";

type Compiled = PlaygroundBuildArtifacts | Uint8Array;

export type ZxExecResult = {
    output: string;
    exitCode: number;
    files: Record<string, Uint8Array>;
};

export type ZigExecResult = ZxExecResult & { emitted: Uint8Array | null };

export type DevBuildResult =
    | { ok: true; compiled: Compiled }
    | { ok: false; stderr: string; files: Record<string, string> };

// Implemented by the editor; the shell is a separate bundle so it can't import editor state directly
export interface ShellHost {
    files(): Record<string, string>;
    writeFile(path: string, content: string): void;
    removeFile(path: string): boolean;
    build(): Promise<Compiled | null>;
    run(): Promise<void>;
    devBuild(): Promise<DevBuildResult>;
    preview(compiled: Compiled): Promise<void>;
    onFilesChanged(listener: () => void): () => void;
    zx(args: string[], files: Record<string, Uint8Array>, opts?: { env?: Record<string, string>; stdin?: string }): Promise<ZxExecResult>;
    zig(args: string[], files: Record<string, Uint8Array>, emit?: string): Promise<ZigExecResult>;
    runProgram(wasm: Uint8Array, args: string[], onOutput: (text: string) => void, signal?: AbortSignal): Promise<number>;
    onOutput(listener: (ev: OutputEvent) => void): () => void;
}

export interface Shell {
    focus(): void;
    clear(): void;
}

const HOME = "/home/user";
const PROJECT = `${HOME}/project`;
const PREVIEW_URL = "https://playground.local/";
// Debounce for editor keystrokes; natively zx dev rebuilds on save
const DEV_REBUILD_DELAY_MS = 400;
// Build outputs live only in the shell's filesystem
const IGNORED_DIRS = ["zig-out/", ".zig-cache/"];

const RESET = "\x1b[0m";
const DIM = "\x1b[2m";
const BOLD = "\x1b[1m";
const RED = "\x1b[31m";
const GREEN = "\x1b[32m";
const YELLOW = "\x1b[33m";
const BLUE = "\x1b[34m";
const CYAN = "\x1b[36m";

const utf8 = new TextDecoder("utf-8", { fatal: true });
const encoder = new TextEncoder();

function isIgnored(rel: string): boolean {
    return IGNORED_DIRS.some((d) => rel.startsWith(d));
}

function formatSize(bytes: number): string {
    if (bytes < 1024) return `${bytes} B`;
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`;
    return `${(bytes / 1024 / 1024).toFixed(2)} MB`;
}

function bytesEqual(a: Uint8Array, b: Uint8Array): boolean {
    if (a.byteLength !== b.byteLength) return false;
    for (let i = 0; i < a.byteLength; i++) if (a[i] !== b[i]) return false;
    return true;
}

function commonPrefix(items: string[]): string {
    if (items.length === 0) return "";
    let prefix = items[0];
    for (const item of items) {
        while (!item.startsWith(prefix)) prefix = prefix.slice(0, -1);
    }
    return prefix;
}

export async function mountShell(container: HTMLElement, host: ShellHost): Promise<Shell> {
    await init();

    const term = new Terminal({
        fontSize: 12,
        fontFamily: "'Monaco', 'Menlo', 'Ubuntu Mono', 'Consolas', monospace",
        cursorBlink: true,
        convertEol: true,
        scrollback: 5000,
        theme: {
            background: "#0b0e13",
            foreground: "#d1d7dd",
            cursor: "#4ade80",
            selectionBackground: "#264f78",
            black: "#1b1f27",
            red: "#ff5f57",
            green: "#4ade80",
            yellow: "#febc2e",
            blue: "#6cb6ff",
            magenta: "#d2a8ff",
            cyan: "#56d4dd",
            white: "#d1d7dd",
            brightBlack: "#6e7681",
        },
    });
    // ghostty-web throws on empty writes
    const write = (text: string) => {
        if (text.length > 0) term.write(text);
    };
    const fit = new FitAddon();
    term.loadAddon(fit);
    term.open(container);
    fit.fit();
    fit.observeResize();

    // Last editor content mirrored into the shell fs, keyed by project-relative path
    const synced = new Map<string, string>();

    const bash = new Bash({
        cwd: PROJECT,
        env: { HOME, USER: "user", TERM: "xterm-256color" },
        files: { [`${PROJECT}/.keep`]: "" },
        customCommands: [
            defineCommand("zx", async (args, ctx) => {
                const sub = args.find((a) => !a.startsWith("-"));
                if (sub === "build") return zxBuild(args);
                if (sub === "dev") return zxDev(args, ctx.signal);
                if (sub === "run" || sub === "serve") return zxRun();
                return zxPassthrough(args, ctx.cwd);
            }),
            defineCommand("zig", async (args, ctx) => {
                if (args[0] === "build") {
                    return {
                        stdout: "",
                        stderr: "zig build runs build.zig as a separate process, which the browser can't spawn.\nUse `zx build`, or compile directly with `zig build-exe`.\n",
                        exitCode: 1,
                    };
                }
                if (args[0] === "run" || args[0] === "test") return zigRun(args, ctx.cwd, ctx.signal);
                return zigPassthrough(args, ctx.cwd);
            }),
        ],
    });
    await bash.fs.rm(`${PROJECT}/.keep`);

    async function syncIn() {
        const current = host.files();
        for (const [rel, content] of Object.entries(current)) {
            if (synced.get(rel) === content) continue;
            await bash.fs.writeFile(`${PROJECT}/${rel}`, content);
            synced.set(rel, content);
        }
        for (const rel of [...synced.keys()]) {
            if (rel in current) continue;
            await bash.fs.rm(`${PROJECT}/${rel}`, { force: true });
            synced.delete(rel);
        }
    }

    async function syncOut() {
        const seen = new Set<string>();
        for (const abs of bash.fs.getAllPaths()) {
            if (!abs.startsWith(PROJECT + "/")) continue;
            const rel = abs.slice(PROJECT.length + 1);
            if (isIgnored(rel)) continue;
            const stat = await bash.fs.stat(abs).catch(() => null);
            if (!stat?.isFile) continue;
            let content: string;
            try {
                content = utf8.decode(await bash.fs.readFileBuffer(abs));
            } catch {
                continue; // binary files stay in the shell
            }
            seen.add(rel);
            if (synced.get(rel) === content) continue;
            host.writeFile(rel, content);
            synced.set(rel, content);
        }
        for (const rel of [...synced.keys()]) {
            if (seen.has(rel)) continue;
            if (host.removeFile(rel)) synced.delete(rel);
        }
    }

    // Streams build/run progress from the Output panel while a zx command runs
    function mirrorOutput(): () => void {
        let lastStep: string | null = null;
        return host.onOutput((ev) => {
            if (ev.kind === "step") {
                write(`${CYAN}•${RESET} ${ev.label}\r\n`);
                lastStep = ev.id;
                return;
            }
            if (ev.kind === "step-done") {
                const color = ev.state === "error" ? RED : GREEN;
                const mark = ev.state === "error" ? "✗" : "✓";
                const replace = lastStep === ev.id ? "\x1b[1A\x1b[2K" : "";
                write(`${replace}${color}${mark}${RESET} ${stepLabel(ev.id)} ${DIM}${ev.time}${RESET}\r\n`);
            } else {
                const color = ev.className?.includes("error") ? RED
                    : ev.className?.includes("success") ? GREEN
                    : ev.className?.includes("muted") ? DIM : "";
                write(`${color}${ev.text}${RESET}\r\n`);
            }
            lastStep = null;
        });
    }

    function stepLabel(id: string): string {
        if (id === "transpile") return "Transpile";
        if (id === "build") return "Build";
        if (id === "run") return "Run";
        return id;
    }

    async function zxBuild(args: string[]) {
        if (args.includes("--help") || args.includes("-h")) {
            return zxPassthrough(args, PROJECT);
        }
        await syncOut();
        const stop = mirrorOutput();
        const start = performance.now();
        let compiled: Compiled | null;
        try {
            compiled = await host.build();
        } finally {
            stop();
        }
        if (!compiled) return { stdout: "", stderr: `${RED}error:${RESET} build failed\n`, exitCode: 1 };

        let stdout = "";
        for (const [rel, data] of await installArtifacts(compiled)) {
            stdout += `  ${rel} ${DIM}${formatSize(data.byteLength)}${RESET}\n`;
        }
        const secs = ((performance.now() - start) / 1000).toFixed(2);
        return { stdout: `${GREEN}${BOLD}Build succeeded${RESET} ${DIM}in ${secs}s${RESET}\n${stdout}`, stderr: "", exitCode: 0 };
    }

    async function installArtifacts(compiled: Compiled): Promise<[string, Uint8Array][]> {
        const artifacts: [string, Uint8Array][] = compiled instanceof Uint8Array
            ? [["zig-out/bin/playground.wasm", compiled]]
            : [
                ["zig-out/bin/app.wasm", compiled.ssrWasm],
                ["zig-out/static/assets/_/app.wasm", compiled.clientWasm],
            ];
        for (const [rel, data] of artifacts) {
            await bash.fs.mkdir(`${PROJECT}/${rel.slice(0, rel.lastIndexOf("/"))}`, { recursive: true });
            await bash.fs.writeFile(`${PROJECT}/${rel}`, data);
        }
        return artifacts;
    }

    // The dev loop's output (status, diagnostics, banners) is rendered by zx.wasm's `dev` command
    async function zxDev(args: string[], signal?: AbortSignal) {
        if (args.includes("--help") || args.includes("-h")) return zxPassthrough(args, PROJECT);
        await syncOut();

        const event = async (name: string, env: Record<string, string> = {}, stdin = "", files: Record<string, string> = {}) => {
            const tree: Record<string, Uint8Array> = {};
            for (const [rel, content] of Object.entries(files)) tree[rel] = encoder.encode(content);
            const res = await host.zx(args, tree, {
                env: { ZIEX_DEV_EVENT: name, ZIEX_DEV_URL: PREVIEW_URL, ...env },
                stdin,
            });
            write(res.output);
            return res.exitCode === 0;
        };
        if (!(await event("start"))) return { stdout: "", stderr: "", exitCode: 1 };

        let dirty = false;
        let wake: (() => void) | null = null;
        const stopWatching = host.onFilesChanged(() => {
            dirty = true;
            wake?.();
        });
        const waitForChange = () => new Promise<void>((resolve) => {
            let timer: ReturnType<typeof setTimeout> | undefined;
            const done = () => {
                clearTimeout(timer);
                wake = null;
                signal?.removeEventListener("abort", done);
                resolve();
            };
            wake = () => {
                clearTimeout(timer);
                timer = setTimeout(done, DEV_REBUILD_DELAY_MS);
            };
            signal?.addEventListener("abort", done);
            if (dirty) wake();
        });

        let first = true;
        let failing = false;
        let last: Compiled | null = null;
        try {
            while (!signal?.aborted) {
                dirty = false;
                const start = performance.now();
                const result = await host.devBuild();
                if (signal?.aborted) break;

                if (!result.ok) {
                    await event("errors", {}, result.stderr, result.files);
                    failing = true;
                } else if (result.compiled === last && !failing) {
                    await event("unchanged");
                } else {
                    last = result.compiled;
                    await installArtifacts(result.compiled);
                    await event("restart", {
                        ZIEX_DEV_BUILD_MS: String(Math.round(performance.now() - start)),
                        ZIEX_DEV_FIRST: first ? "1" : "0",
                        ZIEX_DEV_RESOLVED: failing ? "1" : "0",
                    });
                    first = false;
                    failing = false;
                    const stop = host.onOutput((ev) => {
                        if (ev.kind === "line") write(`${ev.text}\r\n`);
                    });
                    try {
                        await host.preview(result.compiled);
                    } finally {
                        stop();
                    }
                }

                await waitForChange();
                if (signal?.aborted) break;
                await event("rebuilding");
            }
        } finally {
            stopWatching();
        }
        await event("stop");
        return { stdout: "", stderr: "", exitCode: 0 };
    }

    async function zigRun(args: string[], cwd: string, signal?: AbortSignal) {
        const sep = args.indexOf("--");
        const compileArgs = sep === -1 ? args.slice(1) : args.slice(1, sep);
        const programArgs = sep === -1 ? [] : args.slice(sep + 1);
        const isTest = args[0] === "test";
        const emit = isTest ? "test.wasm" : "run.wasm";
        // zig.wasm can't spawn the result, so build it here and run it in a worker
        const res = await zigExec(
            [isTest ? "test" : "build-exe", ...compileArgs, ...(isTest ? ["--test-no-exec"] : []), `-femit-bin=.zig-cache/playground/${emit}`],
            cwd,
            emit,
        );
        write(res.output);
        if (res.exitCode !== 0 || !res.emitted) return { stdout: "", stderr: "", exitCode: res.exitCode || 1 };

        const source = compileArgs.find((a) => a.endsWith(".zig")) ?? emit;
        const name = source.slice(source.lastIndexOf("/") + 1).replace(/\.zig$/, "");
        const exitCode = await host.runProgram(res.emitted, [name, ...programArgs], (text) => write(text), signal);
        return { stdout: "", stderr: "", exitCode };
    }

    async function zigPassthrough(args: string[], cwd: string) {
        const res = await zigExec(args, cwd);
        return { stdout: res.output, stderr: "", exitCode: res.exitCode };
    }

    async function zigExec(args: string[], cwd: string, emit?: string) {
        const prefix = cwd === "/" ? "/" : `${cwd}/`;
        const before = await readTree(prefix);
        const res = await host.zig(args, before, emit);
        await writeTree(prefix, before, res.files);
        return res;
    }

    async function readTree(prefix: string): Promise<Record<string, Uint8Array>> {
        const tree: Record<string, Uint8Array> = {};
        for (const abs of bash.fs.getAllPaths()) {
            if (!abs.startsWith(prefix)) continue;
            const stat = await bash.fs.stat(abs).catch(() => null);
            if (stat?.isFile) tree[abs.slice(prefix.length)] = await bash.fs.readFileBuffer(abs);
        }
        return tree;
    }

    async function writeTree(prefix: string, before: Record<string, Uint8Array>, after: Record<string, Uint8Array>) {
        for (const [rel, data] of Object.entries(after)) {
            const prev = before[rel];
            if (prev && bytesEqual(prev, data)) continue;
            const abs = `${prefix}${rel}`;
            await bash.fs.mkdir(abs.slice(0, abs.lastIndexOf("/")) || "/", { recursive: true });
            await bash.fs.writeFile(abs, data);
        }
    }

    async function zxRun() {
        await syncOut();
        const stop = mirrorOutput();
        try {
            await host.run();
        } finally {
            stop();
        }
        return { stdout: `${DIM}Preview updated${RESET}\n`, stderr: "", exitCode: 0 };
    }

    async function zxPassthrough(args: string[], cwd: string) {
        const prefix = cwd === "/" ? "/" : `${cwd}/`;
        const before = await readTree(prefix);
        const res = await host.zx(args, before);
        await writeTree(prefix, before, res.files);
        return { stdout: res.output, stderr: "", exitCode: res.exitCode };
    }

    // Line editor
    let line = "";
    let cursor = 0;
    // Row of the cursor relative to the prompt's first row, for redrawing wrapped input
    let cursorRow = 0;
    const history: string[] = [];
    let historyIndex = 0;
    let busy = false;
    let abort: AbortController | null = null;
    let cwd = PROJECT;
    let env: Record<string, string> | undefined;

    function promptText(): string {
        const dir = cwd === HOME ? "~" : cwd.startsWith(HOME + "/") ? `~${cwd.slice(HOME.length)}` : cwd;
        return `${GREEN}${BOLD}user@ziex${RESET}:${BLUE}${BOLD}${dir}${RESET}$ `;
    }

    function redraw(): boolean {
        const prompt = promptText();
        const promptLen = prompt.replace(/\x1b\[[0-9;]*m/g, "").length;
        const cols = Math.max(term.cols, 1);
        const total = promptLen + line.length;
        let out = (cursorRow > 0 ? `\x1b[${cursorRow}A` : "") + `\r\x1b[J${prompt}${line}`;
        // Leave the pending-wrap state so the cursor math below holds
        if (total > 0 && total % cols === 0) out += "\r\n";
        const endRow = Math.floor(total / cols);
        const pos = promptLen + cursor;
        const row = Math.floor(pos / cols);
        if (endRow > row) out += `\x1b[${endRow - row}A`;
        out += "\r";
        if (pos % cols > 0) out += `\x1b[${pos % cols}C`;
        write(out);
        cursorRow = row;
        return total > 0 && total % cols === 0;
    }

    // Starts a fresh prompt on the current (empty) row
    function newPrompt() {
        cursorRow = 0;
        redraw();
    }

    function setLine(next: string) {
        line = next;
        cursor = next.length;
        redraw();
    }

    async function execute(command: string) {
        busy = true;
        abort = new AbortController();
        try {
            await syncIn();
            const res = await bash.exec(command, {
                cwd,
                env,
                replaceEnv: env !== undefined,
                signal: abort.signal,
            });
            // A Ctrl+C'd command already reported its own shutdown
            const stderr = abort.signal.aborted ? res.stderr.replace(/^bash: execution aborted\n?$/m, "") : res.stderr;
            if (res.stdout) write(res.stdout);
            if (stderr) write(`${RED}${stderr}${RESET}`);
            if ((res.stdout || stderr) && !(res.stdout + stderr).endsWith("\n")) {
                write(`${DIM}%${RESET}\r\n`);
            }
            env = res.env;
            if (res.env.PWD) cwd = res.env.PWD;
            await syncOut();
        } catch (err) {
            write(`${RED}${err instanceof Error ? err.message : String(err)}${RESET}\r\n`);
        } finally {
            busy = false;
            abort = null;
        }
    }

    async function complete() {
        const head = line.slice(0, cursor);
        const start = head.search(/\S*$/);
        const word = head.slice(start);
        const isCommand = head.slice(0, start).trim() === "" || /[|;&]\s*$/.test(head.slice(0, start));

        let candidates: string[];
        if (isCommand && !word.includes("/")) {
            candidates = [...new Set([...getCommandNames(), "zx", "zig"])].filter((c) => c.startsWith(word)).map((c) => c + " ");
        } else {
            const slash = word.lastIndexOf("/");
            const dirPart = slash >= 0 ? word.slice(0, slash + 1) : "";
            const base = word.slice(slash + 1);
            await syncIn();
            const dir = bash.fs.resolvePath(cwd, dirPart || ".");
            const entries = await bash.fs.readdir(dir).catch(() => [] as string[]);
            candidates = [];
            for (const entry of entries) {
                if (!entry.startsWith(base) || (entry.startsWith(".") && !base.startsWith("."))) continue;
                const stat = await bash.fs.stat(bash.fs.resolvePath(dir, entry)).catch(() => null);
                candidates.push(dirPart + entry + (stat?.isDirectory ? "/" : " "));
            }
        }
        if (candidates.length === 0) return;

        const prefix = candidates.length === 1 ? candidates[0] : commonPrefix(candidates);
        if (prefix.length > word.length) {
            line = line.slice(0, start) + prefix + line.slice(cursor);
            cursor = start + prefix.length;
            redraw();
        } else if (candidates.length > 1) {
            const end = cursor;
            cursor = line.length;
            redraw();
            cursor = end;
            write(`\r\n${candidates.map((c) => c.trimEnd()).join("  ")}\r\n`);
            newPrompt();
        }
    }

    async function submit() {
        const command = line;
        cursor = line.length;
        if (!redraw()) write("\r\n");
        line = "";
        cursor = 0;
        if (command.trim()) {
            if (history[history.length - 1] !== command) history.push(command);
            historyIndex = history.length;
            await execute(command);
        }
        historyIndex = history.length;
        newPrompt();
    }

    const queue: string[] = [];
    let draining = false;

    async function handleInput(data: string) {
        switch (data) {
            case "\r": return submit();
            case "\x7f":
            case "\b":
                if (cursor > 0) {
                    line = line.slice(0, cursor - 1) + line.slice(cursor);
                    cursor--;
                    redraw();
                }
                return;
            case "\x1b[3~":
                if (cursor < line.length) {
                    line = line.slice(0, cursor) + line.slice(cursor + 1);
                    redraw();
                }
                return;
            case "\x03":
                cursor = line.length;
                redraw();
                write("^C\r\n");
                line = "";
                cursor = 0;
                newPrompt();
                return;
            case "\x0c":
                write("\x1b[2J\x1b[3J\x1b[H");
                newPrompt();
                return;
            case "\x15":
                line = line.slice(cursor);
                cursor = 0;
                redraw();
                return;
            case "\x0b":
                line = line.slice(0, cursor);
                redraw();
                return;
            case "\x17": {
                const start = line.slice(0, cursor).replace(/\S+\s*$/, "").length;
                line = line.slice(0, start) + line.slice(cursor);
                cursor = start;
                redraw();
                return;
            }
            case "\t": return complete();
            case "\x1b[A":
                if (historyIndex > 0) setLine(history[--historyIndex]);
                return;
            case "\x1b[B":
                if (historyIndex < history.length - 1) setLine(history[++historyIndex]);
                else if (historyIndex < history.length) {
                    historyIndex = history.length;
                    setLine("");
                }
                return;
            case "\x1b[C":
                if (cursor < line.length) {
                    cursor++;
                    redraw();
                }
                return;
            case "\x1b[D":
                if (cursor > 0) {
                    cursor--;
                    redraw();
                }
                return;
            case "\x1b[H":
            case "\x1bOH":
            case "\x01":
                cursor = 0;
                redraw();
                return;
            case "\x1b[F":
            case "\x1bOF":
            case "\x05":
                cursor = line.length;
                redraw();
                return;
        }
        if (data.startsWith("\x1b")) return;

        // Typed or pasted text; pasted newlines submit each line in turn
        const parts = data.replace(/\r\n?/g, "\n").split("\n");
        for (let i = 0; i < parts.length; i++) {
            const text = parts[i].replace(/[\x00-\x1f]/g, "");
            line = line.slice(0, cursor) + text + line.slice(cursor);
            cursor += text.length;
            if (i < parts.length - 1) {
                redraw();
                await submit();
            }
        }
        redraw();
    }

    async function drain() {
        if (draining) return;
        draining = true;
        while (queue.length > 0) await handleInput(queue.shift()!);
        draining = false;
    }

    term.onData((data) => {
        if (busy && data === "\x03") {
            abort?.abort();
            write("^C\r\n");
            return;
        }
        queue.push(data);
        void drain();
    });

    write(`${BOLD}Ziex playground shell${RESET} ${DIM}(in-browser, files sync with the editor)${RESET}\r\n`);
    const hint = ["ls", "zx dev", "zx build", "zig run hello.zig", "zx --help"].map((c) => `${YELLOW}${c}${RESET}`).join(`${DIM},${RESET} `);
    write(`${DIM}Try${RESET} ${hint}\r\n\r\n`);
    await syncIn();
    newPrompt();

    return {
        focus() {
            fit.fit();
            term.focus();
        },
        clear() {
            write("\x1b[2J\x1b[3J\x1b[H");
            if (!busy) newPrompt();
        },
    };
}
