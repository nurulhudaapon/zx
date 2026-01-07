import React from "react";
import { createRoot } from "react-dom/client";
import { hydrateAll } from "../packages/ziex/src/react";
import { registry } from "@ziex/components";

// Hydrate React islands
hydrateAll(registry, (el, C, props) => createRoot(el).render(React.createElement(C, props)));

// Client Side Rendering
import { init } from "../packages/ziex/src/wasm";
init();
