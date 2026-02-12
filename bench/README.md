# Benchmarks

## SSR Throughput

Prerequisites:
- [oha](https://github.com/hatoo/oha) for benchmarking
- [Node.js](https://nodejs.org/) for Next.js
- [Zig](https://ziglang.org/) for Ziex
- [Rust](https://www.rust-lang.org/) for Leptos

### Next.js
From the `bench/nextjs` directory, run:

```sh
npm install
npm run build
npm run start
```

Then run the benchmark:

```sh
oha -n 10000 -c 100 http://localhost:3000/ssr
```

### Ziex

From the `bench/ziex` directory, run:

```sh
zig build serve -Doptimize=ReleaseFast
```

Then run the benchmark:

```sh
oha -n 10000 -c 100 http://localhost:3000/ssr
```

### Leptos

From the `bench/leptos` directory, run:

```sh
cargo install --locked cargo-leptos
rustup target add wasm32-unknown-unknown
cargo leptos serve --release
```

Then run the benchmark:

```sh
oha -n 10000 -c 100 http://localhost:3000/ssr
```