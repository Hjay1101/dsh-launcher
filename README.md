# dsh-launcher

One-click launcher for [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web — boot the web UI in your workspace and open the browser automatically. Works on **macOS & Linux**.

一键启动 DeepSeek Harness Web：自动进入工作区、启动服务、等待就绪后打开浏览器。支持 macOS 和 Linux。

## Why / 为什么需要它

DeepSeek Harness's web UI must be started from the directory you want as the workspace root (that directory becomes the session root). Remembering the command, the right directory, and waiting for the port every time is tedious. `dsh-launcher` wraps all of it:

DSH 的 Web 界面必须在「你想作为工作区根目录的目录」下启动（该目录会成为会话根目录）。每次记住命令、切换目录、等待端口就绪很繁琐。`dsh-launcher` 把这些全包了：

- ✅ `cd` into your workspace automatically
- ✅ Detect the `dsh` binary (PATH → npx cache → fallback to `npx`)
- ✅ Skip startup if the server is already running — just open the browser
- ✅ Wait for the port, then auto-open the browser
- ✅ Custom port / workspace / binary via CLI args or env vars

## Quick start / 快速开始

### Option A — clone & run directly

```bash
git clone https://github.com/Hjay1101/dsh-launcher.git
cd dsh-launcher
./dsh-launcher.sh --workspace /path/to/your/workspace
```

### Option B — install to PATH

```bash
./install.sh                 # installs to ~/.local/bin/dsh-launcher
dsh-launcher -w /path/to/your/workspace
```

### Option C — macOS double-click

`dsh-launcher.command` is a double-clickable launcher (Terminal app required). Set your default workspace by editing `DEFAULT_WORKSPACE` inside the file, or export `DSH_WORKSPACE` in `~/.zshrc`:

```bash
export DSH_WORKSPACE="/path/to/your/workspace"
```

Then double-click `dsh-launcher.command`.

## Usage / 用法

```
Usage: dsh-launcher [options]

Options:
  -w, --workspace <dir>   Workspace root (default: $DSH_WORKSPACE or current dir)
  -p, --port <port>       Web port (default: $DSH_PORT or 3080)
  -b, --dsh-bin <path>    Explicit dsh binary path (default: auto-detect)
  -n, --no-browser        Do not auto-open the browser
  -h, --help              Show this help
```

### Environment variables / 环境变量

| Variable | Description |
|----------|-------------|
| `DSH_WORKSPACE` | Default workspace root (same as `-w`) |
| `DSH_PORT` | Default port (same as `-p`) |
| `DSH_BIN` | Explicit `dsh` binary path (same as `-b`) |
| `DSH_NO_BROWSER` | Set to `1` to disable auto-open (same as `-n`) |

### Examples / 示例

```bash
# Default port 3080, browser auto-opens
dsh-launcher -w ~/my-workspace

# Custom port
dsh-launcher -w ~/my-workspace -p 8080

# Headless (no browser)
dsh-launcher -w ~/my-workspace --no-browser

# The server is already running → just opens the browser
dsh-launcher -w ~/my-workspace
```

## How it works / 工作原理

1. `cd` into the workspace (⚠️ this is the session root — start from the directory you want)
2. Check if the port is already in use → if yes, open the browser and exit
3. Locate `dsh`:
   - `DSH_BIN` if provided
   - `dsh` on PATH
   - newest copy in `~/.npm/_npx/*/node_modules/.bin/dsh`
   - otherwise `npx --yes @deepseek-ai/dsh web`
4. Start `dsh web` in the background
5. Poll the port (up to 60s), then auto-open the browser
6. Press `Ctrl+C` to stop

## Stop / 停止

Press `Ctrl+C` in the terminal window that runs the launcher.

## License / 许可证

MIT © Hjay1101
