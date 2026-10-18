// @ts-ignore
import * as childProcess from "child_process";
// @ts-ignore
import * as util from "util";
// @ts-ignore
import * as fs from "fs";
// @ts-ignore
import * as path from "path";
import { ExtensionContext, workspace } from "vscode";
import { resolvePath } from "./config";

const execFile = util.promisify(childProcess.execFile);
const isWindows = process.platform === "win32";
const zigExe = isWindows ? "zig.exe" : "zig";

/// Extension id of the official Zig extension, which downloads and manages
/// Zig toolchains under its global storage directory.
const ZIG_EXTENSION_ID = "ziglang.vscode-zig";

/**
 * Resolves the Zig executable to use for `zig build` and for the language
 * server (ZLS looks `zig` up in PATH).
 *
 * The official Zig extension only adds its managed toolchain to the integrated
 * terminal's PATH, not to other extensions' processes, so `zig` may work in the
 * terminal yet be missing here. Resolution order:
 *
 * 1. `zig.path` setting of the Zig extension, when it points at an executable
 * 2. Zig extension managed install matching the project's `minimum_zig_version`
 * 3. `zig` from PATH
 * 4. Newest Zig extension managed install
 */
export async function findZigExecutable(
  context: ExtensionContext,
  projectDir?: string,
): Promise<string | undefined> {
  const configured = configuredZigPath(projectDir);
  if (configured && (await isZig(configured))) return configured;

  const managed = managedZigInstalls(context);
  const wanted = projectDir ? readMinimumZigVersion(projectDir) : undefined;
  const exact = wanted ? managed.find((install) => install.version === wanted) : undefined;
  if (exact && (await isZig(exact.exe))) return exact.exe;

  if (await isZig("zig")) return "zig";

  for (const install of managed) {
    if (await isZig(install.exe)) return install.exe;
  }
  return undefined;
}

/// Prepends the directory of `zig` to PATH so child processes (`zx lsp`, ZLS,
/// `zig build`) resolve the same toolchain. Returns undefined when `zig` is
/// already a bare PATH lookup.
export function envWithZig(zig: string): Record<string, string> | undefined {
  if (!path.isAbsolute(zig)) return undefined;
  const key = Object.keys(process.env).find((k) => k.toUpperCase() === "PATH") ?? "PATH";
  const current = process.env[key];
  const dir = path.dirname(zig);
  return { [key]: current ? `${dir}${path.delimiter}${current}` : dir };
}

function configuredZigPath(projectDir?: string): string | undefined {
  const value = workspace.getConfiguration("zig").get<string>("path")?.trim();
  if (!value || value === "zig" || value === zigExe) return undefined;

  return resolvePath(value, workspace.workspaceFolders?.[0]?.uri.fsPath ?? projectDir);
}

type ManagedInstall = { version: string; exe: string };

/// Zig toolchains installed by the Zig extension, newest first. Layout:
/// `<globalStorage>/ziglang.vscode-zig/zig/<arch>-<os>-<version>/zig`.
function managedZigInstalls(context: ExtensionContext): ManagedInstall[] {
  const root = path.join(
    path.dirname(context.globalStorageUri.fsPath),
    ZIG_EXTENSION_ID,
    "zig",
  );
  let entries: string[];
  try {
    entries = fs.readdirSync(root);
  } catch {
    return [];
  }

  const installs: ManagedInstall[] = [];
  for (const entry of entries) {
    const parts = entry.split("-");
    if (parts.length < 3) continue;
    const exe = path.join(root, entry, zigExe);
    if (!fs.existsSync(exe)) continue;
    installs.push({ version: parts.slice(2).join("-"), exe });
  }
  return installs.sort((a, b) => compareZigVersions(b.version, a.version));
}

function readMinimumZigVersion(projectDir: string): string | undefined {
  try {
    const zon = fs.readFileSync(path.join(projectDir, "build.zig.zon"), "utf8");
    return /\.minimum_zig_version\s*=\s*"([^"]+)"/.exec(zon)?.[1];
  } catch {
    return undefined;
  }
}

/// Orders `0.16.0` < `0.17.0-dev.1456+hash` < `0.17.0-dev.2131+hash` < `0.17.0`.
function compareZigVersions(a: string, b: string): number {
  const parse = (v: string) => {
    const [core, pre] = v.split("+")[0].split(/-(.*)/);
    const nums = core.split(".").map((n) => parseInt(n, 10) || 0);
    const dev = pre ? parseInt(pre.replace(/^\D+/, ""), 10) || 0 : Infinity;
    return [...nums, dev];
  };
  const pa = parse(a);
  const pb = parse(b);
  for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
    const d = (pa[i] ?? 0) - (pb[i] ?? 0);
    if (d !== 0 && !Number.isNaN(d)) return d > 0 ? 1 : -1;
  }
  return 0;
}

async function isZig(exe: string): Promise<boolean> {
  try {
    await execFile(exe, ["version"], { maxBuffer: 1024 * 1024, timeout: 10_000 });
    return true;
  } catch {
    return false;
  }
}
