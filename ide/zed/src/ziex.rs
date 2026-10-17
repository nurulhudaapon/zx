use zed_extension_api::{
    self as zed, serde_json, settings::LspSettings, LanguageServerId, Result,
};

struct ZiexExtension {
    zx_module_path: Option<String>,
}

impl zed::Extension for ZiexExtension {
    fn new() -> Self {
        Self {
            zx_module_path: None,
        }
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

        let zig_path = worktree.which("zig");
        let build_file = format!("{}/build.zig", worktree.root_path());

        // Resolve project ZX_MODULE_PATH via `zig build zx -- env` when possible.
        self.zx_module_path = zig_path
            .as_ref()
            .and_then(|zig| read_zx_module_path(zig, &build_file, worktree).ok().flatten());

        // `zx lsp` resolves `@import("zx")` from each document's closest
        // `build.zig`, so it works even when the worktree root is not a ziex app.
        if let Some(zx_path) = worktree.which("zx") {
            let mut env = env;
            let mut args = vec!["lsp".to_string()];
            if let Some(module_path) = self.zx_module_path.clone() {
                env.push(("ZX_MODULE_PATH".into(), module_path.clone()));
                args.push("--zx-module".into());
                args.push(module_path);
            }
            return Ok(zed::Command {
                command: zx_path,
                args,
                env,
            });
        }

        // Fallback: `zig build zx -- lsp` — the zx run step injects ZX_MODULE_PATH.
        let zig_path = zig_path.ok_or("Neither zx nor zig found in PATH.")?;
        Ok(zed::Command {
            command: zig_path,
            args: vec![
                "build".into(),
                "--build-file".into(),
                build_file,
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
        Ok(Some(settings))
    }
}

fn read_zx_module_path(
    zig: &str,
    build_file: &str,
    worktree: &zed::Worktree,
) -> Result<Option<String>> {
    let output = zed::process::Command::new(zig)
        .arg("build")
        .arg("--build-file")
        .arg(build_file)
        .arg("zx")
        .arg("--")
        .arg("env")
        .arg("--fmt=json")
        .envs(worktree.shell_env())
        .output()
        .map_err(|e| format!("failed to run zig build zx -- env: {e}"))?;

    if output.status != Some(0) {
        return Ok(None);
    }

    let stdout = String::from_utf8_lossy(&output.stdout);
    parse_zx_module_path_json(&stdout)
}

fn parse_zx_module_path_json(stdout: &str) -> Result<Option<String>> {
    let Some(start) = stdout.find('{') else {
        return Ok(None);
    };
    let Some(end) = stdout.rfind('}') else {
        return Ok(None);
    };
    if end < start {
        return Ok(None);
    }

    let value: serde_json::Value = serde_json::from_str(&stdout[start..=end])
        .map_err(|e| format!("failed to parse zx env JSON: {e}"))?;
    Ok(value
        .get("zx_module_path")
        .and_then(|v| v.as_str())
        .filter(|s| !s.is_empty())
        .map(str::to_owned))
}

zed::register_extension!(ZiexExtension);
