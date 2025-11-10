import { test, expect, describe } from "bun:test";
import { formatZx } from "../src/fmt";
import { fmtCases } from "./data.test";
import Bun from "bun";

const virtualHtmlDocumentContents = new Map<string, string>();

describe("fmt", () => {
    const cancellationTokenSource = new CancellationTokenSource();
    for (const fmtCase of fmtCases) {
        Object.keys(fmtCase).filter(key => key !== "ins").forEach(key => {

            for (let inputIndex = 0; inputIndex < fmtCase.ins.length; inputIndex++) {
                const inputText = fmtCase.ins[inputIndex];
                test(`ZX Expr - ${key.slice('out'.length)} #${inputIndex}`, async () => {
                    const outputText = await formatZx(
                        inputText,
                        cancellationTokenSource.token,
                        "test.zig",
                        virtualHtmlDocumentContents,
                    );

                    expect(outputText).toEqual(fmtCase[key]);
                    await log(inputText, outputText);
                });
            }
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
