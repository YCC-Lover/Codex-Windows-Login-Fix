---
name: Windows Codex 故障反馈
about: 报告教程在你环境中的验证结果
title: "[Windows Codex] <症状简述>"
labels: []
assignees: []
---

> 请勿附上 auth.json、API Key、完整 OAuth URL、设备码、邮箱、账号 ID 或完整未经脱敏的日志。

## 环境

- Windows 版本与 build：
- Codex MSIX 版本：
- Codex CLI 版本：
- 代理类型（可选；不要公开内网地址或凭据）：
- 是否使用额外的 CLI / `CODEX_CLI_PATH` 覆盖：

## 错误阶段

- [ ] `token_exchange_failed`
- [ ] CLI `Not logged in`
- [ ] CLI 已登录但桌面工作空间失败
- [ ] 日志有 `Workspace routing is unavailable` / `status=432`
- [ ] 其他

## 排查结果（只提供脱敏摘要）

- CLI `login status`：
- 显式代理 OAuth 测试 HTTP 状态：
- `respect_system_proxy` 状态：
- 使用本仓库脚本前能否发送新会话：
- 使用 `02-Launch-Codex-BundledCLI.ps1` 后能否发送新会话：

## 最小复现步骤

1. 
2. 
3. 

## 补充说明

不要直接上传原始 `.log`、`.sqlite` 或 `auth.json`。
