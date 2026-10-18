
# Helix

## 1. Language & Grammar Setup

Add the following entries to your Helix `~/.config/helix/languages.toml`:

```toml
[[language]]
name = "ziex"
language-id = "zx"
scope = "source.zx"
roots = ["build.zig", ".git"]
file-types = ["zx"]
grammar = "zx"
language-servers = ["zxls"]

[language-server.zxls]
command = "zx"
args = ["lsp"]

[[grammar]]
name = "zx"
source = { git = "https://github.com/ziex-dev/ziex", rev = "main", subpath = "pkg/tree-sitter-zx" }
```

---

## 2. Build Grammar

Fetch and build the grammar:

```sh
hx --grammar fetch
hx --grammar build
```

---

## 3. Copy Queries

Clone this repo, then copy the queries for zx:

```sh
cp -r ide/helix/queries/ziex/ ~/.config/helix/runtime/queries/ziex/
```

---

## 4. Configure the Language Server

Set ZLS options in the server's `config` table and enable inlay hints:

```toml
# languages.toml
[language-server.zxls]
command = "zx"
args = ["lsp"]
config = { inlay_hints_show_builtin = true }
```

```toml
# config.toml
[editor.lsp]
display-inlay-hints = true
```

Without the `zx` CLI, build the server from the project. Helix starts it in
the workspace root, which must contain the project's `build.zig`:

```toml
[language-server.zxls]
command = "zig"
args = ["build", "zx", "-Dziex-lsp=true", "--release=fast", "--", "lsp"]
```

See the [editor guide](../README.md) for the ZX defaults.
