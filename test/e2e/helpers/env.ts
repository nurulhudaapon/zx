export function isRemoteStaticDeploy(): boolean {
  return false;
  const base = process.env.BASE_URL;
  if (!base) return false;
  try {
    const { hostname } = new URL(base);
    return hostname !== 'localhost' && hostname !== '127.0.0.1' && hostname !== '[::1]';
  } catch {
    return false;
  }
}

export const skipOnRemoteStatic = isRemoteStaticDeploy();

/** Standalone `_base` server (`TEMPLATE_TESTS=1`) vs site embed under `/templates`. */
export const isTemplateServer = !!process.env.TEMPLATE_TESTS;

/** Root path for the `_base` template app in the current e2e mode. */
export const templateRoot = isTemplateServer ? '/' : '/templates';

/** Resolve a template-app path for the current e2e mode. */
export function templateUrl(path = '/'): string {
  if (!path || path === '/') return templateRoot;
  const normalized = path.startsWith('/') ? path : `/${path}`;
  return isTemplateServer ? normalized : `/templates${normalized}`;
}
