export type OutputEvent =
    | { kind: "line"; text: string; className?: string }
    | { kind: "step"; id: string; label: string }
    | { kind: "step-done"; id: string; state: 'done' | 'error' | 'cached' | 'prefetched'; time: string };

const outputListeners = new Set<(ev: OutputEvent) => void>();

// Mirrors everything written to the Output panel (used by the shell while running zx build)
export function onOutput(listener: (ev: OutputEvent) => void): () => void {
    outputListeners.add(listener);
    return () => outputListeners.delete(listener);
}

function emitOutput(ev: OutputEvent) {
    for (const listener of outputListeners) listener(ev);
}

export type PanelTab = "output" | "terminal";

const PANEL_TAB_STORAGE_KEY = "playground_panel_tab_v1";
let activePanelTab: PanelTab = "output";
let shellHooks: { open(container: HTMLElement): void; clear(): void } | null = null;

try {
    if (localStorage.getItem(PANEL_TAB_STORAGE_KEY) === "terminal") activePanelTab = "terminal";
} catch { /* ignore */ }

export function setShellHooks(hooks: { open(container: HTMLElement): void; clear(): void }) {
    shellHooks = hooks;
}

function isTerminalCollapsed(): boolean {
    return document.getElementById("pg-terminal")?.classList.contains("collapsed") ?? true;
}

export function showPanelTab(tab: PanelTab) {
    activePanelTab = tab;
    try {
        localStorage.setItem(PANEL_TAB_STORAGE_KEY, tab);
    } catch { /* ignore */ }
    document.querySelectorAll<HTMLElement>(".pg-panel-tab").forEach((el) => {
        const active = el.dataset.panel === tab;
        el.classList.toggle("pg-panel-tab--active", active);
        el.setAttribute("aria-selected", String(active));
    });
    document.getElementById("pg-terminal-body")?.classList.toggle("is-hidden", tab !== "output");
    const shell = document.getElementById("pg-shell");
    shell?.classList.toggle("is-hidden", tab !== "terminal");
    if (tab === "terminal" && shell && !isTerminalCollapsed()) shellHooks?.open(shell);
}

export function setTerminalCollapsed(collapsed: boolean) {
    const terminal = document.getElementById("pg-terminal");
    const preview = document.getElementById("pg-preview");
    const toggleBtn = document.getElementById("pg-terminal-toggle");
    if (!terminal) return;
    if (collapsed) {
        terminal.classList.add("collapsed");
        if (preview) preview.classList.add("terminal-collapsed");
        if (toggleBtn) toggleBtn.innerHTML = "▲";
    } else {
        terminal.classList.remove("collapsed");
        if (preview) preview.classList.remove("terminal-collapsed");
        if (toggleBtn) toggleBtn.innerHTML = "▼";
        const shell = document.getElementById("pg-shell");
        if (activePanelTab === "terminal" && shell) shellHooks?.open(shell);
    }
}

export function revealOutputWindow() {
    const outputs = document.getElementById("pg-terminal-body");
    if (outputs) outputs.scrollTo(0, outputs.scrollHeight!);
}

export function appendTerminalLine(text: string, className?: string) {
    emitOutput({ kind: "line", text, className });
    const termBody = document.getElementById("pg-terminal-body");
    if (!termBody) return;

    // Hide the empty-state placeholder once we have output
    document.getElementById("pg-terminal-empty")?.classList.add("hidden");

    const line = document.createElement("span");
    line.className = "pg-terminal-line";

    const prompt = document.createElement("span");
    prompt.className = "pg-terminal-prompt";
    prompt.textContent = "";
    line.appendChild(prompt);

    const content = document.createElement("span");
    if (className) content.className = className;
    content.textContent = text;
    line.appendChild(content);
    termBody.appendChild(line);
}

export function clearTerminal() {
    const termBody = document.getElementById("pg-terminal-body");
    if (!termBody) return;
    // Remove all children except the empty-state element
    Array.from(termBody.children).forEach(child => {
        if (child.id !== "pg-terminal-empty") child.remove();
    });
    // Restore the empty-state placeholder
    document.getElementById("pg-terminal-empty")?.classList.remove("hidden");
}

/** Append a new animated pipeline step row to the terminal. */
export function appendStatusStep(stepId: string, label: string): void {
    emitOutput({ kind: "step", id: stepId, label });
    const termBody = document.getElementById("pg-terminal-body");
    if (!termBody) return;

    // Hide empty-state placeholder
    document.getElementById("pg-terminal-empty")?.classList.add("hidden");

    const line = document.createElement("div");
    line.className = "pg-status-step pg-status-step--running";
    line.id = `pg-status-step-${stepId}`;
    line.dataset.step = stepId;
    line.dataset.start = String(performance.now());

    const iconEl = document.createElement("span");
    iconEl.className = "pg-status-step-icon";

    const labelEl = document.createElement("span");
    labelEl.className = "pg-status-step-label";
    labelEl.textContent = label;

    const timeEl = document.createElement("span");
    timeEl.className = "pg-status-step-time";

    line.appendChild(iconEl);
    line.appendChild(labelEl);
    line.appendChild(timeEl);
    termBody.appendChild(line);
    revealOutputWindow();
}

/** Mark a pipeline step as done, errored, cached, or prefetched. */
export function completeStatusStep(stepId: string, state: 'done' | 'error' | 'cached' | 'prefetched', ms?: number): void {
    const line = document.getElementById(`pg-status-step-${stepId}`);
    if (!line) return;

    line.classList.remove("pg-status-step--running");
    line.classList.add(`pg-status-step--${state}`);

    const timeEl = line.querySelector(".pg-status-step-time") as HTMLElement | null;
    if (timeEl) {
        if (state === 'cached') {
            timeEl.textContent = "cached";
        } else if (ms !== undefined) {
            timeEl.textContent = `${(ms / 1000).toFixed(2)}s`;
        } else if (line.dataset.start) {
            const elapsed = performance.now() - parseFloat(line.dataset.start);
            timeEl.textContent = `${(elapsed / 1000).toFixed(2)}s`;
        }
        emitOutput({ kind: "step-done", id: stepId, state, time: timeEl.textContent ?? "" });
    }
}

window.addEventListener("DOMContentLoaded", () => {
    // Collapse terminal by default on load
    setTerminalCollapsed(true);
    showPanelTab(activePanelTab);

    document.querySelectorAll<HTMLElement>(".pg-panel-tab").forEach((el) => {
        el.addEventListener("click", (e) => {
            e.stopPropagation();
            setTerminalCollapsed(false);
            showPanelTab(el.dataset.panel as PanelTab);
        });
    });

    // Toggle button logic
    document.getElementById("pg-terminal-toggle")?.addEventListener("click", (e) => {
        const terminal = document.getElementById("pg-terminal");
        if (terminal) setTerminalCollapsed(!terminal.classList.contains("collapsed"));
        e.stopPropagation();
    });

    // Clear button logic
    document.getElementById("pg-terminal-clear")?.addEventListener("click", (e) => {
        if (activePanelTab === "terminal") shellHooks?.clear();
        else clearTerminal();
        e.stopPropagation();
    });

    // Also allow clicking the header to toggle
    document.getElementById("pg-terminal-header")?.addEventListener("click", (e) => {
        if ((e.target as any).id !== "pg-terminal-toggle" && (e.target as any).id !== "pg-terminal-clear") {
            const terminal = document.getElementById("pg-terminal");
            if (terminal) setTerminalCollapsed(!terminal.classList.contains("collapsed"));
        }
    });
});
