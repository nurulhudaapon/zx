# Ziex App on Railway

> A starter template for building web applications with [Ziex](https://ziex.dev) deployed on [Railway](https://railway.com/).

**[Documentation →](https://ziex.dev)**

[![Deploy on Railway](https://railway.com/button.svg)](https://railway.com/new/template?template=https://github.com/ziex-dev/template-railway)

## Getting Started

### Prerequisites

**1. Install ZX CLI**

```bash
# Linux/macOS
curl -fsSL https://ziex.dev/install | bash

# Windows
powershell -c "irm ziex.dev/install.ps1 | iex"
```

**2. Install Zig**

```bash
brew install zig  # macOS
winget install -e --id zig.zig  # Windows
```

[_Other platforms →_](https://ziglang.org/learn/getting-started/)

## Project Structure

```
├── app/
│   ├── assets/         # Static assets (CSS, images, etc)
│   ├── main.zig        # Zig entrypoint
│   ├── pages/          # Pages (Zig/ZX)
│   │   ├── layout.zx   # Root layout
│   │   ├── page.zx     # Home page
│   │   ├── client.zx   # Client-side component
│   │   └── ...
│   └── public/         # Public static files (favicon, etc)
├── build.zig           # Zig build script
└── build.zig.zon       # Zig package manager config
```

## Development

```bash
zig build dev
```

App will be available at [`http://localhost:3000`](http://localhost:3000) with hot reload enabled.

## Deploy to Railway

### Via Railway Dashboard

1. Push this repo to GitHub
2. Go to [Railway](https://railway.com/) and create a new project
3. Select **Deploy from GitHub repo**
4. In your service settings, configure:
   - **Build Command**: `zig build -Doptimize=ReleaseSafe && zig build zx -- bundle`
   - **Start Command**: `./bundle/ziex_app --rootdir ./bundle/static`

### Configuration

The app listens on port **3000** by default. In your Railway service settings, set the **Internal Port** to `3000`.

To use a custom port, set the `PORT` environment variable (for example `PORT=8080`) and update the Internal Port to match.

## Contributing

Contributions are welcome! For feature requests, bug reports, or questions, see the [Ziex Repo](https://github.com/ziex-dev/ziex).

## Links

- [Documentation](https://ziex.dev)
- [Discord](https://ziex.dev/r/discord)
- [Railway Docs](https://docs.railway.com/)
- [Zig Language](https://ziglang.org/)
