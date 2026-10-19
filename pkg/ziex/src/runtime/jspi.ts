type SuspendingCtor = new <T extends (...args: any[]) => any>(fn: T) => T;
type Promising = <T extends (...args: any[]) => any>(fn: T) => (...args: Parameters<T>) => Promise<unknown>;

export const Suspending = (WebAssembly as any).Suspending as SuspendingCtor | undefined;
export const promising = (WebAssembly as any).promising as Promising | undefined;

export const hasJspi: boolean = typeof Suspending === "function" && typeof promising === "function";
