# 如何将本教程发布到 GitHub

这是发布操作说明，不属于故障本身的修复步骤。

## 建议的仓库信息

**仓库名：** `codex-windows-login-workspace-fix`

**Description：** `Windows Codex Desktop token_exchange_failed 与 Workspace routing 432 实测修复教程（设备码登录 + MSIX 内置 CLI 启动）`

**Topics：** `codex`、`openai-codex`、`windows`、`powershell`、`oauth`、`troubleshooting`、`workspace-routing`、`msix`

**README 首页：** 本仓库的 `README.md` 即为正文。截图保存在 `assets/`，脚本保存在 `scripts/`，支持 GitHub 相对路径渲染。

## 上传前安全检查

- 确认没有将 `auth.json`、`.codex`、`.env`、`.sqlite`、私人日志或包含 Token 的截图带进仓库。
- 确认 `README.md` 中的 `44100` 被解释为示例端口，不会被误认为默认值。
- 如果保留你的真实截图，请再次逐一检查是否包含邮箱、手机号、设备码、账号 ID、授权 URL 参数。
- 自行选择许可证。如果不添加 LICENSE，别人并不会自动获得任意转载和改编的授权。
- 不要对外分享完整未经脱敏的 `codex doctor --json` 或 `codex-login.log`。

## 使用网页发布（最省事）

1. 在 GitHub 新建公开或私有仓库。
2. 解压 `Codex-Windows-Login-Fix.zip`。
3. 上传 `README.md`、`.gitignore`、`PUBLISHING_GUIDE.md`、`scripts/`、`assets/` 及 `.github/`。
4. 预览 Markdown；检查截图、脚本链接、Mermaid 流程图能否正确显示。
5. 发布后在仓库 About 中填写 Description 与 Topics。

## 使用 Git 命令发布

在解压目录执行（下方 `<GitHub用户名>` 和仓库名需替换）：

```powershell
git init
git add README.md .gitignore PUBLISHING_GUIDE.md scripts assets .github
git status --short
git diff --cached --name-only
git commit -m "docs: add Windows Codex auth and workspace routing recovery guide"
git branch -M main
git remote add origin "https://github.com/<GitHub用户名>/codex-windows-login-workspace-fix.git"
git push -u origin main
```

如果 `git remote add origin` 提示已存在，请先查看 `git remote -v`，不要覆盖未知目标。

## GitHub Issue / Discussions 的建议说明

发布后可在 README 顶部持续记录经验证的版本、日期与修复效果。不要因为有人使用另一种版本失败，就删掉“本次实测成功”的事实；应该补充“适用范围与不适用案例”。

建议收集：Windows build、Codex MSIX 版本、CLI 版本、`CODEX_CLI_PATH` 是否设置、CLI 登录状态、是否看到 432、使用该脚本后能否新建会话。不收集 Token、完整账号信息或未经脱敏的日志。
