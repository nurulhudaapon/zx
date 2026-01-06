import { ZigJS } from "../../../../vendor/jsz/js/src";

/**
 * ZX Client Bridge - Unified JS↔WASM communication layer
 * Handles events, fetch, timers, and other async callbacks using jsz
 */
export const CallbackType = {
    Event: 0,
    FetchSuccess: 1,
    FetchError: 2,
    Timeout: 3,
    Interval: 4,
} as const;

export type CallbackTypeValue = typeof CallbackType[keyof typeof CallbackType];
type CallbackHandler = (callbackType: number, id: bigint, dataRef: bigint) => void;

export const jsz = new ZigJS();

// Temporary buffer for reading back references from storeValue
const tempRefBuffer = new ArrayBuffer(8);
const tempRefView = new DataView(tempRefBuffer);

/** Store a value using jsz.storeValue and get the 64-bit reference. */
export function storeValueGetRef(val: any): bigint {
    const originalMemory = jsz.memory;
    jsz.memory = { buffer: tempRefBuffer } as WebAssembly.Memory;
    jsz.storeValue(0, val);
    jsz.memory = originalMemory;
    return tempRefView.getBigUint64(0, true);
}

/** Read a string from WASM memory */
function readString(ptr: number, len: number): string {
    const memory = new Uint8Array(jsz.memory!.buffer);
    return new TextDecoder().decode(memory.slice(ptr, ptr + len));
}


/** ZX Bridge - provides JS APIs that callback into WASM */
export class ZxBridge {
    #exports: WebAssembly.Exports;
    #nextCallbackId: bigint = BigInt(1);
    #intervals: Map<bigint, number> = new Map();

    constructor(exports: WebAssembly.Exports) {
        this.#exports = exports;
    }

    get #handler(): CallbackHandler | undefined {
        return this.#exports.__zx_cb as CallbackHandler | undefined;
    }

    #getNextId(): bigint {
        return this.#nextCallbackId++;
    }

    /** Invoke the unified callback handler */
    #invoke(type: CallbackTypeValue, id: bigint, data: any): void {
        const handler = this.#handler;
        if (!handler) {
            console.warn('__zx_cb not exported from WASM');
            return;
        }
        const dataRef = storeValueGetRef(data);
        handler(type, id, dataRef);
    }

    /** Fetch a URL and callback with the response */
    fetch(urlPtr: number, urlLen: number, callbackId: bigint): void {
        const url = readString(urlPtr, urlLen);
        
        fetch(url)
            .then(response => response.text())
            .then(text => {
                this.#invoke(CallbackType.FetchSuccess, callbackId, text);
            })
            .catch(error => {
                this.#invoke(CallbackType.FetchError, callbackId, error.message ?? 'Fetch failed');
            });
    }

    /** Set a timeout and callback when it fires */
    setTimeout(callbackId: bigint, delayMs: number): void {
        setTimeout(() => {
            this.#invoke(CallbackType.Timeout, callbackId, null);
        }, delayMs);
    }

    /** Set an interval and callback each time it fires */
    setInterval(callbackId: bigint, intervalMs: number): void {
        const handle = setInterval(() => {
            this.#invoke(CallbackType.Interval, callbackId, null);
        }, intervalMs) as unknown as number;
        
        this.#intervals.set(callbackId, handle);
    }

    /** Clear an interval */
    clearInterval(callbackId: bigint): void {
        const handle = this.#intervals.get(callbackId);
        if (handle !== undefined) {
            clearInterval(handle);
            this.#intervals.delete(callbackId);
        }
    }

    /** Handle a DOM event (called by event delegation) */
    eventbridge(velementId: bigint, eventTypeId: number, event: Event): void {
        const eventRef = storeValueGetRef(event);
        const eventbridge = this.#exports.__zx_eventbridge as ((velementId: bigint, eventTypeId: number, eventRef: bigint) => void) | undefined;
        if (eventbridge) eventbridge(velementId, eventTypeId, eventRef);
    }

    /** Create the import object for WASM instantiation */
    static createImportObject(bridgeRef: { current: ZxBridge | null }): WebAssembly.Imports {
        return {
            ...jsz.importObject(),
            __zx: {
                _fetch: (urlPtr: number, urlLen: number, callbackId: bigint) => {
                    bridgeRef.current?.fetch(urlPtr, urlLen, callbackId);
                },
                _setTimeout: (callbackId: bigint, delayMs: number) => {
                    bridgeRef.current?.setTimeout(callbackId, delayMs);
                },
                _setInterval: (callbackId: bigint, intervalMs: number) => {
                    bridgeRef.current?.setInterval(callbackId, intervalMs);
                },
                _clearInterval: (callbackId: bigint) => {
                    bridgeRef.current?.clearInterval(callbackId);
                },
            },
        };
    }
}

// Event delegation constants
const DELEGATED_EVENTS = [
    'click', 'dblclick',
    'input', 'change', 'submit',
    'focus', 'blur',
    'keydown', 'keyup', 'keypress',
    'mouseenter', 'mouseleave',
    'mousedown', 'mouseup', 'mousemove',
    'touchstart', 'touchend', 'touchmove',
    'scroll',
] as const;

type DelegatedEvent = typeof DELEGATED_EVENTS[number];

const EVENT_TYPE_MAP: Record<DelegatedEvent, number> = {
    'click': 0, 'dblclick': 1, 'input': 2, 'change': 3, 'submit': 4,
    'focus': 5, 'blur': 6, 'keydown': 7, 'keyup': 8, 'keypress': 9,
    'mouseenter': 10, 'mouseleave': 11, 'mousedown': 12, 'mouseup': 13,
    'mousemove': 14, 'touchstart': 15, 'touchend': 16, 'touchmove': 17,
    'scroll': 18,
};

/** Initialize event delegation */
export function initEventDelegation(bridge: ZxBridge, rootSelector: string = 'body'): void {
    const root = document.querySelector(rootSelector);
    if (!root) return;

    for (const eventType of DELEGATED_EVENTS) {
        root.addEventListener(eventType, (event: Event) => {
            let target = event.target as HTMLElement | null;

            while (target && target !== document.body) {
                const zxRef = (target as any).__zx_ref;
                if (zxRef !== undefined) {
                    bridge.eventbridge(BigInt(zxRef), EVENT_TYPE_MAP[eventType] ?? 0, event);
                    break;
                }
                target = target.parentElement;
            }
        }, { passive: eventType.startsWith('touch') || eventType === 'scroll' });
    }
}



export type InitOptions = {
    url?: string;
    eventDelegationRoot?: string;
    importObject?: WebAssembly.Imports;
};

const DEFAULT_URL = "/assets/main.wasm";
/** Initialize WASM with the ZX Bridge */
export async function init(options: InitOptions = {}): Promise<{ source: WebAssembly.WebAssemblyInstantiatedSource; bridge: ZxBridge }> {
    const url = options.url ?? DEFAULT_URL;
    
    // Bridge reference for import object (will be set after instantiation)
    const bridgeRef: { current: ZxBridge | null } = { current: null };
    
    const importObject = Object.assign(
        {},
        ZxBridge.createImportObject(bridgeRef),
        options.importObject
    );
    
    const source = await WebAssembly.instantiateStreaming(fetch(url), importObject);
    const { instance } = source;

    jsz.memory = instance.exports.memory as WebAssembly.Memory;
    
    const bridge = new ZxBridge(instance.exports);
    bridgeRef.current = bridge;

    initEventDelegation(bridge, options.eventDelegationRoot ?? 'body');

    // Call main to initiate the client side rendering
    const main = instance.exports.mainClient;
    if (typeof main === 'function') main();

    return { source, bridge };
}

// Global type declarations
declare global {
    interface HTMLElement {
        __zx_ref?: number;
    }
}

