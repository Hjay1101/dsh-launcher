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
- ✅ macOS: build a native **DeepSeek Harness.app** with the official whale icon (Dock-ready)

## macOS app & icon / macOS 应用与图标

Want a real app on your Desktop / Dock with the DeepSeek whale icon? We build one:

想要桌面/程序坞上带鲸鱼图标的原生应用？仓库自带构建脚本：

```bash
./build-app.sh                    # → ~/Desktop/DeepSeek Harness.app
./build-app.sh ~/Documents        # → custom output dir
```

Double-click the app → it silently boots `dsh web` in the background (no Terminal window), then opens the browser when ready. **Close the app = stop the service**: right-click the Dock icon → Quit (or Cmd+Q) — the launcher kills `dsh` before exiting. Logs go to `$WORKSPACE/.dsh/dsh.log` (falls back to `~/.dsh/dsh.log`). Drag the app to the Dock for one-click access.

双击 .app → **完全静默**后台启动 `dsh web`（无终端窗口），就绪后自动打开浏览器。**关闭 app 即关闭服务**：Dock 图标右键 → 退出（或 Cmd+Q），launcher 会先停掉 dsh 再退出。日志在 `$WORKSPACE/.dsh/dsh.log`（工作区不可写时回退 `~/.dsh/dsh.log`）。可拖到程序坞。

**How it works:** the launcher stays alive as the parent of `dsh` — Dock icon lit = service running. On Quit, macOS sends SIGTERM and the launcher kills its `dsh` child first, so the service stops with the app. It also patches common `node`/`dsh` PATH locations (GUI-launched processes have a minimal PATH; nvm's default Node wins over `/usr/local`).

**工作原理**：launcher 作为 dsh 的父进程保持存活——Dock 图标亮着 = 服务在跑；退出时 macOS 发 SIGTERM，launcher 先杀掉 dsh 子进程再退出，服务随之停止。同时自动补全常见 node/dsh 路径（GUI 启动的进程 PATH 精简，且 nvm 默认 Node 优先于 /usr/local 的旧版本）。

The build script automatically ad-hoc **signs** the bundle (`codesign`), which macOS requires — without a signature the app silently refuses to open on double-click.

构建脚本会自动对应用做 **ad-hoc 签名**（macOS 强制要求，未签名的 .app 双击会毫无反应打不开）。

Need a custom icon on any file/folder? Use `set-icon.sh` (no extra tools, uses system AppKit):

想给任意文件/文件夹设置自定义图标？用 `set-icon.sh`（零依赖，走系统 AppKit）：

```bash
./set-icon.sh assets/favicon.svg ~/Desktop/MyFolder
./set-icon.sh assets/AppIcon.icns ~/Desktop/launcher.command
```

Icons live in `assets/` — `AppIcon.icns` (multi-size), the 1024px sources, and the original `favicon.svg` (official DSH whale, from the DeepSeek Harness web frontend).

图标资源在 `assets/`：`AppIcon.icns`（多尺寸）、1024px 源图和原始 `favicon.svg`（DSH 官方鲸鱼，取自 DeepSeek Harness Web 前端）。

**Icon design (macOS HIG):** white rounded-square background — 1024×1024 canvas, 824×824 content area centered with **185.4px corner radius** (Big Sur icon grid), whale at 75% of content width. Two variants:

**图标设计（macOS 规范）**：白底圆角方形——1024 画布、居中 824×824 内容区、**圆角 185.4px**（Big Sur 图标网格）、鲸鱼占内容区宽度 75%。两个版本：

- `AppIcon-1024.png` / `AppIcon.icns` — square white bg; macOS applies the rounded mask itself (for `.app`)
- `AppIcon-rounded-1024.png` — rounded white bg baked in (for file icons via `set-icon.sh`, which get no system mask)

- `AppIcon-1024.png` / `AppIcon.icns` — 方形白底，圆角由 macOS 系统遮罩自动切（.app 用）
- `AppIcon-rounded-1024.png` — 圆角直接做进图里（.command 等文件图标用，系统不给文件图标加遮罩）

Regenerate / tweak anytime (e.g. change `WHALE_PCT`):

随时可重新生成/调整参数（如改 `WHALE_PCT`）：

```bash
python3 generate-icon.py assets/favicon.svg   # requires svglib+reportlab
```

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
