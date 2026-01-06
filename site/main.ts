import React from "react";
import { createRoot } from "react-dom/client";
import { hydrateAll } from "../packages/ziex/src/react";
import { init, jsz, storeValueGetRef } from "../packages/ziex/src/wasm";
import { components } from "@ziex/components";

// Build registry from generated components
const registry = Object.fromEntries(components.map(c => [c.name, c.import]));

// Hydrate React islands
hydrateAll(registry, (el, C, props) => createRoot(el).render(React.createElement(C, props)));

let wasmSource: WebAssembly.WebAssemblyInstantiatedSource;
const importObject: WebAssembly.Imports = {
    env: {
        zxFetch: (urlPtr: number, urlLen: number) => {
            const exports = wasmSource.instance.exports;
            const memory = new Uint8Array(jsz.memory!.buffer);
            const url = new TextDecoder().decode(memory.slice(urlPtr, urlPtr + urlLen));

            fetch(url)
                .then(response => response.text())
                .then(text => {
                    // Store the response string in jsz and get its reference
                    const textRef = storeValueGetRef(text);

                    // Call Zig with the jsz reference - no manual memory allocation needed
                    const onFetchComplete = exports?.onFetchComplete as ((textRef: bigint) => void) | undefined;
                    if (onFetchComplete) {
                        onFetchComplete(textRef);
                    }
                })
                .catch(error => {
                    console.error('Fetch error:', error);
                });
        },
    }
};

// Initialize WASM
init({ importObject }).then(s => wasmSource = s);

