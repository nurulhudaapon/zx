use zed_extension_api::{
    self as zed, serde_json, settings::LspSettings, LanguageServerId, Result,
};

struct ZiexExtension;

impl zed::Extension for ZiexExtension {
    fn new() -> Self {
        Self
    }

    fn language_server_command(
        &mut self,
        _language_server_id: &LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<zed::Command> {
        let (platform, _) = zed::current_platform();
        let env = match platform {
            zed::Os::Mac | zed::Os::Linux => worktree.shell_env(),
            zed::Os::Windows => vec![],
        };

        // Respect custom binary path from LSP settings
        if let Ok(lsp_settings) = LspSettings::for_worktree("zxls", worktree) {
            if let Some(binary) = lsp_settings.binary {
                if let Some(path) = binary.path {
                    return Ok(zed::Command {
                        command: path,
                        args: binary.arguments.unwrap_or_default(),
                        env,
                    });
                }
            }
        }

        // `zx lsp` resolves imports from each document's nearest `build.zig`,
        // so it also works when the worktree is a Zig monorepo.
        if let Some(zx) = worktree.which("zx") {
            return Ok(zed::Command {
                command: zx,
                args: vec!["lsp".into()],
                env,
            });
        }

        // Without the CLI, build the server from the worktree's Ziex project.
        // The extension does not run processes, so only the worktree root is
        // considered; a Ziex app nested in a monorepo needs the zx CLI.
        if !depends_on_ziex(worktree) {
            return Err(
                "zxls needs the zx CLI on PATH when the worktree root is not a Ziex project"
                    .into(),
            );
        }
        let zig = worktree
            .which("zig")
            .ok_or("zxls needs the zx CLI or zig on PATH")?;
        Ok(zed::Command {
            command: zig,
            args: vec![
                "build".into(),
                "--build-file".into(),
                format!("{}/build.zig", worktree.root_path()),
                "-Dziex-lsp=true".into(),
                "--release=fast".into(),
                "zx".into(),
                "--".into(),
                "lsp".into(),
            ],
            env,
        })
    }

    fn language_server_workspace_configuration(
        &mut self,
        _language_server_id: &zed::LanguageServerId,
        worktree: &zed::Worktree,
    ) -> Result<Option<serde_json::Value>> {
        // `import_extensions` / `modules` are owned by `zx lsp` (per-build.zig);
        // overriding them here would mask the build's module imports.
        let settings = LspSettings::for_worktree("zxls", worktree)
            .ok()
            .and_then(|lsp_settings| lsp_settings.settings.clone())
            .unwrap_or_else(|| serde_json::json!({}));

        if settings.as_object().map(|o| o.is_empty()).unwrap_or(true) {
            return Ok(None);
        }
        // ZLS pulls the `zls` section, so accept both `{ "zls": { ... } }` and
        // the flat form `{ "inlay_hints_show_builtin": true, ... }`.
        if settings.get("zls").is_some() {
            return Ok(Some(settings));
        }
        Ok(Some(serde_json::json!({ "zls": settings })))
    }
}

/// Whether the worktree root's `build.zig.zon` has a `ziex` dependency.
fn depends_on_ziex(worktree: &zed::Worktree) -> bool {
    worktree
        .read_text_file("build.zig.zon")
        .map(|zon| {
            let compact: String = zon.chars().filter(|c| !c.is_whitespace()).collect();
            compact.contains(".ziex=.{")
        })
        .unwrap_or(false)
}

zed::register_extension!(ZiexExtension);
