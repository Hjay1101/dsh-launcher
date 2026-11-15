// dsh-launcher — Client half.
// 在 Settings 侧栏注册「Launcher」分区：安装命令（一键复制）、三种启动
// 形态说明与下载链接。纯展示 UI，无 host 调用、无网络请求；
// 配色全部走 --dsw-alias-* 主题变量，深浅色自适应。
window.__ModuleLoader__.load({
	id: "dsh-launcher",
	factory: (require) => {
		var module = { exports: {} };
		var exports = module.exports;
		Object.defineProperty(exports, Symbol.toStringTag, { value: "Module" });
		const React = require("react");
		const { useState } = React;

		const NS = "settings.launcher";
		const inject = ["slots", "locale"];

		const REPO = "https://github.com/Hjay1101/dsh-launcher";
		const CMD_INSTALL =
			"git clone https://github.com/Hjay1101/dsh-launcher.git && cd dsh-launcher && ./install.sh";
		const CMD_APP = "cd dsh-launcher && ./build-app.sh";

		// ---------- 文案（中 / 英） ----------
		const zh = {
			nav: "Launcher",
			title: "Launcher",
			desc: "DeepSeek Harness Web 的原生启动器：在指定工作区启动 Web UI，HTTP 就绪后自动打开浏览器。",
			formCli: "CLI 命令行",
			formCliNote: "安装到 ~/.local/bin，任意目录直接 dsh-launcher",
			formCommand: "双击 .command",
			formCommandNote: "dsh-launcher.command，双击即启（需终端 App）",
			formApp: "原生 .app",
			formAppNote: "约 200KB Cocoa 应用，稳定 Dock 图标，关闭即停服务",
			installTitle: "安装（CLI）",
			appTitle: "构建原生应用",
			copy: "复制",
			copied: "已复制 ✓",
			releases: "前往 Releases 下载",
			repo: "项目主页",
			noteMac: "原生 .app 仅限 macOS；CLI 与 .command 在 macOS / Linux 均可用。",
		};
		const en = {
			nav: "Launcher",
			title: "Launcher",
			desc: "Native launcher for DeepSeek Harness Web: boots the UI in your workspace and opens the browser once the server responds.",
			formCli: "CLI",
			formCliNote: "Installs to ~/.local/bin, run dsh-launcher from anywhere",
			formCommand: "Double-click .command",
			formCommandNote: "dsh-launcher.command, one double-click to start (Terminal app required)",
			formApp: "Native .app",
			formAppNote: "~200 KB Cocoa app, stable Dock icon, closing the app stops the service",
			installTitle: "Install (CLI)",
			appTitle: "Build the native app",
			copy: "Copy",
			copied: "Copied ✓",
			releases: "Download from Releases",
			repo: "Project home",
			noteMac: "The native .app is macOS only; the CLI and .command also work on Linux.",
		};

		// ---------- 样式（幂等注入，全部走主题变量） ----------
		function ensureCss() {
			if (typeof document === "undefined") return;
			if (document.getElementById("dsh-launcher-css")) return;
			const style = document.createElement("style");
			style.id = "dsh-launcher-css";
			style.textContent = `
.dsh-launcher-body { max-width: 640px; font-size: 13px; line-height: 1.55;
	color: var(--dsw-alias-label-primary); }
.dsh-launcher-desc { margin: 0 0 12px; color: var(--dsw-alias-label-secondary); }
.dsh-launcher-forms { display: flex; flex-direction: column; gap: 8px; margin: 0 0 16px; }
.dsh-launcher-form { display: flex; gap: 10px; align-items: baseline;
	padding: 8px 10px; border: 1px solid var(--dsw-alias-border-l1); border-radius: 8px; }
.dsh-launcher-form b { min-width: 128px; flex: none; }
.dsh-launcher-form span { color: var(--dsw-alias-label-secondary); }
.dsh-launcher-block { margin: 0 0 14px; }
.dsh-launcher-block h4 { margin: 0 0 6px; font-size: 12px;
	color: var(--dsw-alias-label-secondary); font-weight: 600; }
.dsh-launcher-cmdrow { display: flex; gap: 8px; align-items: stretch; }
.dsh-launcher-cmd { flex: 1; margin: 0; padding: 8px 10px; overflow-x: auto;
	background: var(--dsw-alias-interactive-bg-hover); border-radius: 8px;
	font-family: ui-monospace, SFMono-Regular, Menlo, monospace; font-size: 12px;
	color: var(--dsw-alias-label-primary); white-space: pre; }
.dsh-launcher-copy { flex: none; padding: 0 12px; border-radius: 8px; cursor: pointer;
	border: 1px solid var(--dsw-alias-border-l2); background: transparent;
	color: var(--dsw-alias-label-primary); font-size: 12px; }
.dsh-launcher-copy:hover { background: var(--dsw-alias-interactive-bg-hover); }
.dsh-launcher-links { display: flex; gap: 16px; margin: 2px 0 10px; }
.dsh-launcher-links a { color: var(--dsw-alias-state-business-primary);
	text-decoration: none; }
.dsh-launcher-links a:hover { text-decoration: underline; }
.dsh-launcher-note { margin: 0; font-size: 12px;
	color: var(--dsw-alias-label-caption); }
`;
			document.head.appendChild(style);
		}

		async function copyText(text) {
			try {
				await navigator.clipboard.writeText(text);
				return true;
			} catch {
				try {
					const ta = document.createElement("textarea");
					ta.value = text;
					ta.style.position = "fixed";
					ta.style.opacity = "0";
					document.body.appendChild(ta);
					ta.select();
					const ok = document.execCommand("copy");
					ta.remove();
					return ok;
				} catch {
					return false;
				}
			}
		}

		function CommandBlock({ t, title, cmd, tag }) {
			const [copied, setCopied] = useState(false);
			const onCopy = async () => {
				if (await copyText(cmd)) {
					setCopied(true);
					setTimeout(() => setCopied(false), 1500);
				}
			};
			return React.createElement(
				"div",
				{ className: "dsh-launcher-block" },
				React.createElement("h4", null, title),
				React.createElement(
					"div",
					{ className: "dsh-launcher-cmdrow" },
					React.createElement("pre", { className: "dsh-launcher-cmd" }, cmd),
					React.createElement(
						"button",
						{ className: "dsh-launcher-copy", onClick: onCopy, "data-testid": tag },
						copied ? t("copied") : t("copy")
					)
				)
			);
		}

		function LauncherBody({ t }) {
			const forms = [
				{ name: t("formCli"), note: t("formCliNote") },
				{ name: t("formCommand"), note: t("formCommandNote") },
				{ name: t("formApp"), note: t("formAppNote") },
			];
			return React.createElement(
				"div",
				{ className: "dsh-launcher-body" },
				React.createElement("p", { className: "dsh-launcher-desc" }, t("desc")),
				React.createElement(
					"div",
					{ className: "dsh-launcher-forms" },
					forms.map((f) =>
						React.createElement(
							"div",
							{ className: "dsh-launcher-form", key: f.name },
							React.createElement("b", null, f.name),
							React.createElement("span", null, f.note)
						)
					)
				),
				React.createElement(CommandBlock, { t, title: t("installTitle"), cmd: CMD_INSTALL, tag: "install" }),
				React.createElement(CommandBlock, { t, title: t("appTitle"), cmd: CMD_APP, tag: "app" }),
				React.createElement(
					"div",
					{ className: "dsh-launcher-links" },
					React.createElement("a", { href: REPO + "/releases", target: "_blank", rel: "noreferrer" }, t("releases")),
					React.createElement("a", { href: REPO, target: "_blank", rel: "noreferrer" }, t("repo"))
				),
				React.createElement("p", { className: "dsh-launcher-note" }, t("noteMac"))
			);
		}

		function apply(ctx) {
			ensureCss();
			ctx.effect(() => ctx.locale.register(NS, { zh, en }), "dsh-launcher: dictionaries");
			const t = ctx.locale.bind(NS);
			ctx.slots.inject("settings.section", () =>
				ctx.slots.register(
					{
						name: "settings.section",
						id: "launcher",
						order: 55,
						label: () => t("nav"),
						locale: NS,
						inject: () => ({ t }),
					},
					(props) => React.createElement(LauncherBody, { t: props.t })
				)
			);
		}

		exports.NS = NS;
		exports.apply = apply;
		exports.inject = inject;
		return module.exports;
	},
});
