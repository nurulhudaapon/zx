import { test, expect, describe } from "bun:test";
import { formatZx } from "../src/fmt";
import { fmtCases } from "./data.test";
import Bun from "bun";

// Register virtual document providers
const virtualHtmlDocumentContents = new Map<string, string>();

describe("formatZx", () => {
    const cancellationTokenSource = new CancellationTokenSource();
    for (const fmtCase of fmtCases) {
        Object.keys(fmtCase).filter(key => key !== "ins").forEach(key => {
            test(`formatZx - ${key.slice('out'.length)} - ${fmtCase.ins.length} inputs`, async () => {
    
                for (const inputText of fmtCase.ins) {
                    const outputText = await formatZx(
                        inputText,
                        cancellationTokenSource.token,
                        "test.zig",
                        virtualHtmlDocumentContents,
                    );
    
                    await log(inputText, outputText);
                    expect(outputText).toEqual(fmtCase[key]);
                }
            });
        });

    }
});


async function log(input: string, output: string) {
    const inputFile = Bun.file("test/logs/input.zig");
    const outputFile = Bun.file("test/logs/output.zig");
    await inputFile.write(input);
    await outputFile.write(output);
    
    const logFile = Bun.file("test/logs/fmt.log");
    const existing = await logFile.exists() ? await logFile.text() : "";
    const newLog = `${existing}${input}
------------------------------>>
${output}
---------------------------------------------------------
`;
    await Bun.write("test/logs/fmt.log", newLog);
}

class CancellationTokenSource {
    token = {
        isCancellationRequested: false,
        onCancellationRequested: (_callback: () => void) => {
            // Mock implementation
        },
    };
    cancel() {
        this.token.isCancellationRequested = true;
    }
    dispose() { }
}
