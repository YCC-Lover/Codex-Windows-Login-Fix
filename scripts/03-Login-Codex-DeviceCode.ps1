#requires -version 5.1
<#
.SYNOPSIS
  Find the current Codex native CLI and start interactive device-code login.
.NOTES
  User interaction is required. Login may write credentials to ~/.codex/auth.json
  or the configured OS credential store. Never share device codes or tokens.
#>
[CmdletBinding()]
param()

$cli = $null
$running = Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object {
        $_.Name -eq 'codex.exe' -and $_.ExecutablePath -and
        (Test-Path -LiteralPath $_.ExecutablePath)
    } | Select-Object -First 1
if ($running) { $cli = $running.ExecutablePath }

if (-not $cli) {
    $binRoot = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $binRoot) {
        $cli = Get-ChildItem -LiteralPath $binRoot -Filter 'codex.exe' `
            -Recurse -File -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
}

if (-not $cli) {
    $pkg = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue |
        Sort-Object Version -Descending | Select-Object -First 1
    if ($pkg) {
        $candidate = Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
        if (Test-Path -LiteralPath $candidate) { $cli = $candidate }
    }
}

if (-not $cli) { throw '未找到 Codex CLI；请先确认已安装 Codex 桌面版。' }

Write-Host '===== Codex CLI =====' -ForegroundColor Cyan
Write-Host $cli
& $cli --version
Write-Host "`n===== 当前登录状态 =====" -ForegroundColor Cyan
& $cli login status

Write-Host "`n即将启动交互式设备码登录。" -ForegroundColor Yellow
Write-Host '请仅在官方页面输入设备码；不要向他人发送设备码、Token 或 auth.json。'
& $cli login --device-auth
if ($LASTEXITCODE -ne 0) { throw '设备码登录未完成，请根据 CLI 错误检查账户权限/代理/TLS。' }

Write-Host "`n===== 授权后登录状态 =====" -ForegroundColor Cyan
& $cli login status
