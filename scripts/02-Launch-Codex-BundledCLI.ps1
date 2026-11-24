#requires -version 5.1
<#
.SYNOPSIS
  Launch Windows MSIX Codex Desktop with its own bundled CLI as a session-only override.
.NOTES
  Does not write persistent environment variables or delete any user data.
  Close all existing Codex Desktop windows/processes before running this script.
#>
[CmdletBinding()]
param()

$pkg = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1
if (-not $pkg) { throw '未找到 OpenAI.Codex：本脚本仅支持 Windows MSIX 版本。' }

$bundledCli = Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
$desktopExe = Join-Path $pkg.InstallLocation 'app\ChatGPT.exe'

if (-not (Test-Path -LiteralPath $bundledCli)) {
    throw "找不到安装包内置 CLI：$bundledCli"
}
if (-not (Test-Path -LiteralPath $desktopExe)) {
    throw "找不到桌面应用文件：$desktopExe"
}

# Do not terminate anything automatically; the user controls their running sessions.
$running = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -eq 'ChatGPT.exe' })
if ($running.Count -gt 0) {
    $running | Select-Object ProcessId,Name | Format-Table -AutoSize
    throw '检测到 ChatGPT.exe 仍在运行。请正常完全退出桌面应用后重新执行。'
}

Write-Host '===== Windows Codex Desktop =====' -ForegroundColor Cyan
Write-Host "MSIX Version: $($pkg.Version)"
Write-Host "Bundled CLI: $bundledCli"
& $bundledCli --version

Write-Host "`n===== 验证 CLI 认证状态 =====" -ForegroundColor Cyan
& $bundledCli login status
if ($LASTEXITCODE -ne 0) {
    throw '当前 CLI 还未登录。请先运行 03-Login-Codex-DeviceCode.ps1 完成授权。'
}

# Process-scope override; Start-Process inherits this environment.
$env:CODEX_CLI_PATH = $bundledCli
Write-Host "`n临时指定 CODEX_CLI_PATH（Process 作用域）。" -ForegroundColor Green
Write-Host '即将从同一 PowerShell 会话启动桌面程序。'
Start-Process -FilePath $desktopExe
Write-Host '启动命令已执行；请验证工作空间设置及新会话是否正常。'
Write-Host '这不是永久修复；下次从开始菜单启动不一定继承此设置。'
