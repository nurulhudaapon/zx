// Browser stand-in for node:zlib; gzip/gunzip/zcat report as unsupported
function unsupported(): never {
    throw new Error("gzip is not supported in the playground");
}

export const constants = { Z_BEST_COMPRESSION: 9, Z_BEST_SPEED: 1, Z_DEFAULT_COMPRESSION: -1 };
export const gzipSync = unsupported;
export const gunzipSync = unsupported;
