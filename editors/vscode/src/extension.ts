import * as childProcess from "child_process";
import * as util from "util";
import * as vscode from "vscode";
import { ExtensionContext, window, workspace } from "vscode";

import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
} from "vscode-languageclient/node";

import { getZLSPath } from "./util/util";

import { registerHtmlAutoCompletion } from "./util/html";

let client: LanguageClient;

const execFile = util.promisify(childProcess.execFile);

export function activate(context: ExtensionContext) {
  const serverCommand = getZLSPath(context);

  if (!serverCommand) {
    window.showErrorMessage(
      "Failed to start ZX Language Server: ZLS not found",
    );
    return;
  }

  const serverOptions: ServerOptions = {
    command: serverCommand,
  };

  const outputChannel = window.createOutputChannel("ZX Language Server", {
    log: true,
  });

  // Options to control the language client
  const clientOptions: LanguageClientOptions = {
    documentSelector: [{ scheme: "file", language: "zx" }],
    traceOutputChannel: outputChannel,
    outputChannel,
    middleware: {
      async provideDocumentFormattingEdits(document, _options, token, _next) {
        return formatWithZxCli(document, token);
      },
      async provideHover(uri, position, token, next) {
        const hover = await next(uri, position, token);
        console.log(hover);

        return hover;
      },
      handleDiagnostics(uri, diagnostics, next) {
        const filteredDiagnostics = diagnostics.map((diag) => {
          // Filter out diagnostics with code "ZigE0424" (unused variable)
          if (
            diag.severity === vscode.DiagnosticSeverity.Error &&
            diag.message === "expected expression, found '<'"
          ) {
            return null;
            diag.severity = vscode.DiagnosticSeverity.Hint;
            diag.message =
              "ZX syntax: minimal LSP support will be available for now";
          }
          return diag;
        }).filter(Boolean);
        next(uri, filteredDiagnostics);
      },
    },
  };

  client = new LanguageClient(
    "zx-language-server",
    "ZX Language Server",
    serverOptions,
    clientOptions,
  );

  // Start the client. This will also launch the server
  client.start();

  // Register command to toggle embedded Zig expression formatting
  context.subscriptions.push(
    vscode.commands.registerCommand(
      "zx.toggleZigExpressionFormatting",
      async () => {
        const config = workspace.getConfiguration("zx");
        const current = config.get<boolean>("format.enableZigExpression", true);
        const newValue = !current;
        await config.update(
          "format.enableZigExpression",
          newValue,
          vscode.ConfigurationTarget.Global,
        );
        vscode.window.showInformationMessage(
          `ZX: embedded Zig expression formatting is now ${newValue ? "enabled" : "disabled"
          }`,
        );
      },
    ),
  );
  // Register HTML autocomplete + tag-complete for `.zx` files
  registerHtmlAutoCompletion(context, "zx");
}

async function formatWithZxCli(
  document: vscode.TextDocument,
  token: vscode.CancellationToken,
): Promise<vscode.TextEdit[] | null> {
  const abortController = new AbortController();
  token.onCancellationRequested(() => abortController.abort());

  try {
    const cwd = workspace.workspaceFolders?.[0]?.uri.fsPath;
    const originalText = document.getText();
    const promise = execFile("zx", ["fmt", "--stdio"], {
      cwd,
      maxBuffer: 10 * 1024 * 1024,
      signal: abortController.signal,
      timeout: 60000,
    });
    promise.child.stdin?.end(originalText);

    const { stdout } = await promise;
    const lastLineId = document.lineCount - 1;
    const wholeDocument = new vscode.Range(
      0,
      0,
      lastLineId,
      document.lineAt(lastLineId).text.length,
    );

    if (!stdout || stdout === originalText) {
      return null;
    }

    return [new vscode.TextEdit(wholeDocument, stdout)];
  } catch (error: any) {
    if (token.isCancellationRequested) {
      return null;
    }

    const message =
      error?.stderr?.toString()?.trim() || error?.message || String(error);
    const isNotFound =
      message.includes("not found") ||
      message.includes("ENOENT") ||
      error.code === "ENOENT";

    if (isNotFound) {
      const os = process.platform;
      const installCommand =
        os === "win32"
          ? 'powershell -c "irm ziex.dev/install.ps1 | iex"'
          : "curl -fsSL https://ziex.dev/install | bash";

      const selection = await window.showErrorMessage(
        "ZX CLI not found. Please install it to use code formatting.",
        "Install Now",
        "Copy Installation Script",
      );

      if (selection === "Copy Installation Script") {
        await vscode.env.clipboard.writeText(installCommand);
        window.showInformationMessage("Installation command copied to clipboard!");
      } else if (selection === "Install Now") {
        const terminal = window.createTerminal("ZX CLI Installation");
        terminal.sendText(installCommand);
        terminal.show();
      }
    } else {
      window.showErrorMessage(`ZX: failed to format using 'zx fmt': ${message}`);
    }

    return null;
  }
}

export function deactivate(): Thenable<void> | undefined {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
