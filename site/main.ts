import React from "react";
import { createRoot } from "react-dom/client";
import { hydrateAll } from "../packages/ziex/src/react";
import { init } from "../packages/ziex/src/wasm";
import { components } from "@ziex/components";

// Client Side Rendering
init();


// Build registry from generated components, TODO: move to @ziex/components in the future
const registry = Object.fromEntries(components.map(c => [c.name, c.import]));

// Hydrate React islands
hydrateAll(registry, (el, C, props) => createRoot(el).render(React.createElement(C, props)));