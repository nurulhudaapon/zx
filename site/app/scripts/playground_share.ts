export type PlaygroundFilesMap = Record<string, string>;

export type SnippetEntry = {
    code: string;
    filename: string;
};

const ZX_IMPORT_LINE = 'const zx = @import("zx");';
const STD_IMPORT_LINE = 'const std = @import("std");';

const MINIMAL_LAYOUT = `pub fn Layout(ctx: zx.LayoutContext, children: zx.Component) zx.Component {
    return (
        <html @allocator={ctx.arena} lang="en-US">
            <head>
                <meta charset="UTF-8" />
                <title>Playground</title>
            </head>
            <body>
                {children}
            </body>
        </html>
    );
}

const zx = @import("zx");
`;

const MINIMAL_PAGE = `pub fn Page(ctx: zx.PageContext) !zx.Component {
    return (
        <main @allocator={ctx.arena}>
            <h1>Playground</h1>
            <p>Open <a href="/api">/api</a> to try the route.</p>
        </main>
    );
}

const zx = @import("zx");
`;

function ensureTopLevelZxImport(code: string): string {
    const hasTopLevelImport = code
        .split(/\r?\n/)
        .some((line) => /^const\s+zx\s*=\s*@import\("zx"\);\s*$/.test(line));

    if (hasTopLevelImport) {
        return code;
    }

    const normalized = code.replace(/\s+$/, "");
    return `${normalized}\n\n${ZX_IMPORT_LINE}`;
}

function ensureTopLevelStdImport(code: string): string {
    const usesStd = /std\.\w+/m.test(code);

    if (!usesStd) {
        return code;
    }

    const hasTopLevelImport = code
        .split(/\r?\n/)
        .some((line) => /^const\s+std\s*=\s*@import\("std"\);\s*$/.test(line));

    if (hasTopLevelImport) {
        return code;
    }

    const normalized = code.replace(/\s+$/, "");
    return `${normalized}\n\n${STD_IMPORT_LINE}`;
}

function processSnippetCode(code: string): string {
    let processedCode = code;
    processedCode = ensureTopLevelStdImport(processedCode);
    processedCode = ensureTopLevelZxImport(processedCode);
    return processedCode;
}

function basename(filename: string): string {
    const parts = filename.replace(/\\/g, "/").split("/");
    return parts[parts.length - 1] || filename;
}

function hasPageExport(code: string): boolean {
    return /\bpub\s+fn\s+Page\s*\(/.test(code);
}

function hasLayoutExport(code: string): boolean {
    return /\bpub\s+fn\s+Layout\s*\(/.test(code);
}

function looksLikeRoute(code: string, filename: string): boolean {
    const name = basename(filename).toLowerCase();
    if (name === "route.zig" || name.endsWith("route.zig")) return true;
    if (/\bzx\.RouteContext\b/.test(code)) return true;
    if (/\bzx\.SocketContext\b/.test(code)) return true;
    if (/\bpub\s+fn\s+(GET|POST|PUT|DELETE|PATCH|Socket|SocketOpen)\s*\(/.test(code) && /RouteContext|SocketContext/.test(code)) {
        return true;
    }
    return false;
}

export function needsAppMode(code: string, filename = "Playground.zx"): boolean {
    const name = basename(filename).toLowerCase();
    if (looksLikeRoute(code, filename)) return true;
    if (name === "layout.zx" || name === "page.zx") return true;
    if (hasPageExport(code) || hasLayoutExport(code)) return true;
    if (/@rendering\s*=\s*\{\s*\.client\s*\}/.test(code)) return true;
    if (/\bzx\.client\./.test(code)) return true;
    if (/\bzx\.server\.Action\b/.test(code)) return true;
    if (/\bzx\.PageContext\b/.test(code)) return true;
    if (/\bzx\.LayoutContext\b/.test(code)) return true;
    return false;
}

export function isPlaygroundOpenable(filename: string, code: string): boolean {
    const trimmed = code.trim();
    if (!trimmed) return false;

    const name = basename(filename).toLowerCase();
    if (
        name === "build.zig" ||
        name.endsWith(".json") ||
        name.endsWith(".sh") ||
        name.endsWith(".md") ||
        name.endsWith(".css") ||
        name.endsWith(".html")
    ) {
        return false;
    }

    if (name.endsWith(".zx") || name.endsWith(".zig")) return true;
    return needsAppMode(trimmed, filename) || /<[A-Za-z/!]/.test(trimmed);
}

function findPrimaryComponentName(code: string): string | null {
    const matches = code.matchAll(/\bpub\s+fn\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/g);
    for (const match of matches) {
        const name = match[1];
        if (!name || name === "Page" || name === "Layout") continue;
        if (/^(GET|POST|PUT|DELETE|PATCH|Socket|SocketOpen|main)$/.test(name)) continue;
        return name;
    }
    return null;
}

function componentTakesAllocator(code: string, name: string): boolean {
    const re = new RegExp(`\\bpub\\s+fn\\s+${name}\\s*\\(\\s*allocator\\s*:`);
    return re.test(code);
}

function wrapComponentAsPage(code: string): string {
    if (hasPageExport(code)) return code;

    const name = findPrimaryComponentName(code);
    if (!name) return code;

    const wantsClient =
        /@rendering\s*=\s*\{\s*\.client\s*\}/.test(code) ||
        /\bzx\.client\./.test(code) ||
        /\bzx\.client\.Action\b/.test(code);

    const allocatorAttr = componentTakesAllocator(code, name) ? " @allocator={ctx.arena}" : "";
    const renderingAttr = wantsClient ? " @rendering={.client}" : "";

    return `pub fn Page(ctx: zx.PageContext) !zx.Component {
    return (
        <main @allocator={ctx.arena}>
            <${name}${allocatorAttr}${renderingAttr} />
        </main>
    );
}

${code}`;
}

function ensureMinimalAppShell(files: PlaygroundFilesMap): PlaygroundFilesMap {
    const out: PlaygroundFilesMap = { ...files };

    if (!out["app/pages/layout.zx"]) {
        out["app/pages/layout.zx"] = MINIMAL_LAYOUT;
    }

    if (!out["app/pages/page.zx"]) {
        if (out["app/routes/api/route.zig"]) {
            out["app/pages/page.zx"] = MINIMAL_PAGE;
        } else {
            // Should not happen for page-bound snippets, but keep shell valid.
            out["app/pages/page.zx"] = MINIMAL_PAGE;
        }
    }

    return out;
}

function mapEntryToAppPath(filename: string, code: string): string {
    const name = basename(filename).toLowerCase();

    if (looksLikeRoute(code, filename)) {
        return "app/routes/api/route.zig";
    }
    if (name === "layout.zx" || hasLayoutExport(code)) {
        return "app/pages/layout.zx";
    }
    if (name === "page.zx" || hasPageExport(code) || needsAppMode(code, filename)) {
        return "app/pages/page.zx";
    }
    return "app/pages/page.zx";
}

/**
 * Pack one or more docs/home snippets into a playground file map.
 * Route handlers and client/page/layout snippets open in app mode with a minimal shell.
 */
export function createDocsSnippetFiles(code: string, filename = "Playground.zx"): PlaygroundFilesMap {
    return createDocsSnippetFilesFromEntries([{ code, filename }]);
}

export function createDocsSnippetFilesFromEntries(entries: SnippetEntry[]): PlaygroundFilesMap {
    const cleaned = entries
        .map((entry) => ({
            code: entry.code.trim(),
            filename: entry.filename.trim() || "Playground.zx",
        }))
        .filter((entry) => entry.code.length > 0);

    if (cleaned.length === 0) {
        return { "Playground.zx": "" };
    }

    const useApp = cleaned.some((entry) => needsAppMode(entry.code, entry.filename));

    if (!useApp) {
        const primary = cleaned[0];
        return {
            "Playground.zx": processSnippetCode(primary.code),
        };
    }

    const files: PlaygroundFilesMap = {};

    for (const entry of cleaned) {
        let code = processSnippetCode(entry.code);
        const path = mapEntryToAppPath(entry.filename, code);

        if (path === "app/pages/page.zx" && !hasPageExport(code) && !looksLikeRoute(code, entry.filename)) {
            code = processSnippetCode(wrapComponentAsPage(code));
        }

        // Prefer keeping an existing page/layout if multiple entries map to the same path.
        if (!files[path]) {
            files[path] = code;
        }
    }

    return ensureMinimalAppShell(files);
}

export async function encodeFilesToQuery(filesMap: PlaygroundFilesMap): Promise<string> {
    const json = JSON.stringify(filesMap);
    const stream = new Blob([json]).stream().pipeThrough(new CompressionStream("deflate"));
    const buffer = await new Response(stream).arrayBuffer();

    let binString = "";
    const bytes = new Uint8Array(buffer);
    const CHUNK_SIZE = 0x8000;
    for (let i = 0; i < bytes.length; i += CHUNK_SIZE) {
        binString += String.fromCharCode.apply(null, Array.from(bytes.subarray(i, i + CHUNK_SIZE)));
    }

    const b64 = btoa(binString);
    return b64.replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

export async function decodeFilesFromQuery(query: string): Promise<PlaygroundFilesMap | null> {
    try {
        let b64 = query.replace(/-/g, "+").replace(/_/g, "/");
        while (b64.length % 4) {
            b64 += "=";
        }

        const binString = atob(b64);
        const bytes = Uint8Array.from(binString, (m) => m.codePointAt(0) ?? 0);
        const stream = new Blob([bytes]).stream().pipeThrough(new DecompressionStream("deflate"));
        const text = await new Response(stream).text();

        return JSON.parse(text) as PlaygroundFilesMap;
    } catch {
        return null;
    }
}

export async function createPlaygroundShareUrl(filesMap: PlaygroundFilesMap, baseUrl: string): Promise<string> {
    const encoded = await encodeFilesToQuery(filesMap);
    return `${baseUrl}#data=${encoded}`;
}
