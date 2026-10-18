// @ts-ignore
import * as childProcess from "child_process";
// @ts-ignore
import * as util from "util";
// @ts-ignore
import * as fs from "fs";
// @ts-ignore
import * as os from "os";
// @ts-ignore
import * as path from "path";
import { ExtensionContext, window, workspace } from "vscode";
import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions
} from "vscode-languageclient/node";

import { activateMultilineStringDecorator } from "./util/string";

let client: LanguageClient;
const execFile = util.promisify(childProcess.execFile);

export async function activate(context: ExtensionContext) {
  const lspCmd = await getLspCommand();
  const serverCommand = lspCmd.command;
  const serverArgs = lspCmd.args;
  const serverEnv = lspCmd.env;

  if (!serverCommand) {
    window.showErrorMessage(
      "Failed to start Ziex Language Server: zx executable or build step not found."
    );
    return;
  }

  const serverOptions: ServerOptions = {
    command: serverCommand,
    args: serverArgs,
    options: {
      cwd: lspCmd.cwd,
      env: serverEnv ? { ...process.env, ...serverEnv } : undefined,
    },
  };
  const outputChannel = window.createOutputChannel("Ziex Language Server", {
    log: true,
  });

  const clientOptions: LanguageClientOptions = {
    documentSelector: [
      { scheme: "file", language: "zx" },
    ],
    traceOutputChannel: outputChannel,
    outputChannel,
  };

  client = new LanguageClient(
    "zx-language-server",
    "Ziex Language Server",
    serverOptions,
    clientOptions,
  );
  client.start();
  activateMultilineStringDecorator(context);
}

type LspCommand = {
  command: string;
  args: string[];
  cwd?: string;
  env?: Record<string, string>;
};

const isWindows = process.platform === "win32";

async function getLspCommand(): Promise<LspCommand> {
  const projectDir = await findZxProjectDir();
  const cwd = projectDir ?? workspace.workspaceFolders?.[0]?.uri.fsPath;

  // Prefer installed `zx lsp`. Only then resolve ZX_MODULE_PATH via
  // `zig build zx -- env` so we can pass --zx-module.
  const zx = await findZxExecutable(cwd);
  if (zx) {
    const zxModulePath = projectDir
      ? (await readZxModulePath(projectDir)) ?? undefined
      : undefined;
    const args = ["lsp"];
    if (zxModulePath) {
      args.push("--zx-module", zxModulePath);
    }
    return {
      command: zx,
      args,
      cwd,
      env: zxModulePath ? { ZX_MODULE_PATH: zxModulePath } : undefined,
    };
  }

  if (projectDir) {
    return {
      command: "zig",
      args: ["build", "zx", "-Dziex-lsp=true", "--release=fast", "--", "lsp"],
      cwd: projectDir,
    };
  }
  return { command: "", args: [] };
}

/// Resolves `zx` from PATH, falling back to the default install location
/// (`$ZX_INSTALL/bin` or `~/.zx/bin`). VS Code doesn't always inherit the
/// shell PATH (e.g. WSL remote, or Windows before a restart after install).
async function findZxExecutable(cwd?: string): Promise<string | undefined> {
  const exe = isWindows ? "zx.exe" : "zx";
  const installRoot = process.env.ZX_INSTALL || path.join(os.homedir(), ".zx");
  const candidates = ["zx", path.join(installRoot, "bin", exe)];
  for (const candidate of candidates) {
    try {
      await execFile(candidate, ["version"], {
        cwd,
        maxBuffer: 1024 * 1024,
        timeout: 5000,
      });
      return candidate;
    } catch {
      // try next candidate
    }
  }
  return undefined;
}

/// Finds the directory of the nearest build.zig exposing a `zx` step,
/// starting from the active .zx document and walking up to its workspace
/// folder, then checking each workspace folder root. Needed for monorepos
/// where the Ziex project isn't at the workspace root.
async function findZxProjectDir(): Promise<string | undefined> {
  const folders = workspace.workspaceFolders?.map((f) => f.uri.fsPath) ?? [];
  const startPaths: string[] = [];

  const active = window.activeTextEditor?.document;
  if (active?.uri.scheme === "file") startPaths.push(active.uri.fsPath);
  for (const doc of workspace.textDocuments) {
    if (doc.uri.scheme === "file" && doc.languageId === "zx") {
      startPaths.push(doc.uri.fsPath);
    }
  }

  const checked = new Set<string>();
  for (const file of startPaths) {
    const root = folders.find((f) => isSubPath(f, file));
    let dir = path.dirname(file);
    while (true) {
      if (!checked.has(dir)) {
        checked.add(dir);
        if (fs.existsSync(path.join(dir, "build.zig")) && (await hasZxBuildStep(dir))) {
          return dir;
        }
      }
      const parent = path.dirname(dir);
      if (parent === dir || (root && !isSubPath(root, parent))) break;
      dir = parent;
    }
  }

  for (const folder of folders) {
    if (checked.has(folder)) continue;
    if (fs.existsSync(path.join(folder, "build.zig")) && (await hasZxBuildStep(folder))) {
      return folder;
    }
  }
  return undefined;
}

function isSubPath(parent: string, child: string): boolean {
  const rel = path.relative(parent, child);
  return rel === "" || (!rel.startsWith("..") && !path.isAbsolute(rel));
}

async function readZxModulePath(cwd: string): Promise<string | undefined> {
  try {
    const { stdout } = await execFile(
      "zig",
      ["build", "zx", "--", "env", "--fmt=json"],
      {
        cwd,
        maxBuffer: 1024 * 1024,
        timeout: 60_000,
      },
    );
    const jsonStart = stdout.indexOf("{");
    const jsonEnd = stdout.lastIndexOf("}");
    if (jsonStart < 0 || jsonEnd < jsonStart) return undefined;
    const parsed = JSON.parse(stdout.slice(jsonStart, jsonEnd + 1)) as {
      zx_module_path?: string | null;
    };
    return parsed.zx_module_path ?? undefined;
  } catch (error: any) {
    // @ts-ignore
    console.error("failed to read zx env", error);
    return undefined;
  }
}

interface BuildStep {
  name: string;
  description: string;
}

function parseBuildSteps(output: string): BuildStep[] {
  const steps: BuildStep[] = [];
  const lines = output.split(/\r?\n/);

  for (const line of lines) {
    if (!line.trim()) continue;
    const trimmed = line.trimStart();

    const parts = trimmed.split(/\s{2,}/);
    if (parts.length >= 2) {
      const namePart = parts[0].replace(/\s*\([^)]+\)\s*$/, "").trim();
      const description = parts.slice(1).join(" ").trim();
      if (namePart && description) {
        steps.push({ name: namePart, description });
      }
    }
  }

  return steps;
}

async function hasZxBuildStep(cwd: string): Promise<boolean> {
  try {
    // A cold `zig build -l` compiles the build runner and may fetch deps,
    // which can take well over 5s (especially on WSL / Windows).
    const { stdout } = await execFile("zig", ["build", "-l"], {
      cwd,
      maxBuffer: 1024 * 1024,
      timeout: 120_000,
    });
    const steps = parseBuildSteps(stdout);
    return steps.some((step) => step.name === "zx");
  } catch (error: any) {
    // @ts-ignore
    console.error(error);
    return false;
  }
}


export async function deactivate(): Promise<void> {
  if (client) await client.stop();
}
