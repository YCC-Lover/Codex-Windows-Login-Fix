#requires -version 5.1
<#
.SYNOPSIS
  Read-only diagnostic summary for Windows Codex Desktop and CLI.
.DESCRIPTION
  Does not print raw logs, credentials, full authentication URLs or proxy secrets.
  -TestNetwork sends one intentionally invalid OAuth grant and one GitHub GET.
.EXAMPLE
  .\01-Diagnose-Codex.ps1
.EXAMPLE
  .\01-Diagnose-Codex.ps1 -ProxyPort 44100 -TestNetwork
#>
[CmdletBinding()]
param(
    [ValidateRange(0,65535)]
    [int]$ProxyPort = 0,
    [switch]$TestNetwork
)

function Show-Section([string]$Title) {
    Write-Host "`n===== $Title =====" -ForegroundColor Cyan
}

Show-Section 'Codex MSIX 安装信息'
$pkg = Get-AppxPackage -Name 'OpenAI.Codex' -ErrorAction SilentlyContinue |
    Sort-Object Version -Descending | Select-Object -First 1
if ($null -eq $pkg) {
    Write-Warning '未找到 OpenAI.Codex 包；此脚本主要适用于 Microsoft Store/MSIX 版本。'
} else {
    [PSCustomObject]@{
        Name = $pkg.Name
        Version = $pkg.Version
        BundledCliExists = Test-Path (Join-Path $pkg.InstallLocation 'app\resources\codex.exe')
        DesktopExeExists = Test-Path (Join-Path $pkg.InstallLocation 'app\ChatGPT.exe')
    } | Format-List
}

Show-Section '正在运行的 Codex 进程'
$processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue |
    Where-Object { $_.Name -match '^(codex|chatgpt)\.exe$' })
$processes | ForEach-Object {
    [PSCustomObject]@{
        Name = $_.Name
        PID = $_.ProcessId
        Source = if ($_.ExecutablePath -match '\\WindowsApps\\') { 'MSIX' }
                 elseif ($_.ExecutablePath -match '\\OpenAI\\Codex\\bin\\') { 'Copied CLI' }
                 elseif ($_.ExecutablePath) { 'Other' } else { 'Unknown' }
    }
} | Format-Table -AutoSize

Show-Section '代理配置（只显示状态；不显示可能包含凭据的完整代理 URL）'
$internetSettings = Get-ItemProperty `
    'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' `
    -ErrorAction SilentlyContinue
$proxySummary = '未配置'
if ($internetSettings.ProxyServer) {
    if ($internetSettings.ProxyServer -match '127\.0\.0\.1:(\d+)') {
        $proxySummary = "本地端口 $($Matches[1])"
    } else {
        $proxySummary = '存在非本地/复杂系统代理配置（内容隐藏）'
    }
}
[PSCustomObject]@{
    SystemProxyEnabled = ($internetSettings.ProxyEnable -eq 1)
    SystemProxy = $proxySummary
    PACConfigured = [bool]$internetSettings.AutoConfigURL
} | Format-List

$names = @('HTTP_PROXY','HTTPS_PROXY','ALL_PROXY','NO_PROXY',
           'http_proxy','https_proxy','all_proxy','no_proxy',
           'CODEX_CLI_PATH')
$envRows = @(
    foreach ($name in $names) {
        foreach ($scope in @('Process','User','Machine')) {
            $value = [Environment]::GetEnvironmentVariable($name,$scope)
            if ($value) {
                [PSCustomObject]@{
                    Variable = $name
                    Scope = $scope
                    State = '已设置（值隐藏）'
                }
            }
        }
    }
)
$envRows | Format-Table -AutoSize

if ($ProxyPort -gt 0) {
    Show-Section "本地代理端口 $ProxyPort"
    $listener = Get-NetTCPConnection -LocalPort $ProxyPort -State Listen `
        -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($listener) {
        $p = Get-Process -Id $listener.OwningProcess -ErrorAction SilentlyContinue
        [PSCustomObject]@{
            Port = $ProxyPort
            Listening = $true
            Process = if ($p) { $p.ProcessName } else { '无法读取进程名' }
        } | Format-List
    } else {
        Write-Warning "未发现端口 $ProxyPort 的 TCP LISTEN 记录"
    }
}

Show-Section '已知 CLI 后端的登录状态与功能'
$cli = $null
$runningCli = $processes | Where-Object {
    $_.Name -eq 'codex.exe' -and $_.ExecutablePath -and
    (Test-Path -LiteralPath $_.ExecutablePath)
} | Select-Object -First 1
if ($runningCli) { $cli = $runningCli.ExecutablePath }
if (-not $cli) {
    $bin = Join-Path $env:LOCALAPPDATA 'OpenAI\Codex\bin'
    if (Test-Path -LiteralPath $bin) {
        $cli = Get-ChildItem -LiteralPath $bin -File -Filter 'codex.exe' `
            -Recurse -ErrorAction SilentlyContinue |
            Sort-Object LastWriteTime -Descending |
            Select-Object -First 1 -ExpandProperty FullName
    }
}
if (-not $cli -and $pkg) {
    $candidate = Join-Path $pkg.InstallLocation 'app\resources\codex.exe'
    if (Test-Path -LiteralPath $candidate) { $cli = $candidate }
}
if ($cli) {
    & $cli --version
    & $cli login status
    & $cli features list 2>$null |
        Select-String 'respect_system_proxy|system_proxy_fallback' |
        ForEach-Object { $_.Line }
} else {
    Write-Warning '找不到可执行的 Codex CLI。'
}

Show-Section '最近 Codex 桌面日志（只显示摘要）'
$roots = @((Join-Path $env:LOCALAPPDATA 'Codex\Logs'))
if ($pkg) {
    $roots += Join-Path $env:LOCALAPPDATA (
        'Packages\' + $pkg.PackageFamilyName + '\LocalCache\Local\Codex\Logs')
}
$files = @(
    foreach ($root in $roots) {
        if (Test-Path -LiteralPath $root) {
            Get-ChildItem -LiteralPath $root -Recurse -File -Filter '*.log' `
                -ErrorAction SilentlyContinue
        }
    }
) | Where-Object { $_.Length -gt 0 } |
    Sort-Object LastWriteTime -Descending |
    Select-Object -First 20

if ($files.Count -eq 0) {
    Write-Warning '未发现非空日志；检查桌面版是否已启动、LocalCache 路径是否正确。'
} else {
    $files | Select-Object -First 5 Name,LastWriteTime,Length |
        Format-Table -AutoSize
    $rules = [ordered]@{
        'Workspace routing' = 'Workspace routing|routing discovery'
        'Proxy failure' = 'ERR_PROXY_CONNECTION_FAILED'
        'Cloudflare challenge' = 'cloudflare_challenge'
        'EXDEV state failure' = 'EXDEV'
        'OAuth token failure' = 'token_exchange_failed'
        'HTTP 432 log records' = 'status[=:]"?432'
    }
    $summary = foreach ($label in $rules.Keys) {
        $matches = @(Select-String -Path $files.FullName -Pattern $rules[$label] `
            -ErrorAction SilentlyContinue)
        [PSCustomObject]@{ Pattern=$label; Matches=$matches.Count }
    }
    $summary | Format-Table -AutoSize
    Write-Host '注意：匹配次数 != 故障次数；432 为日志记录值，未必是远端原始 HTTP 状态。'
}

if ($TestNetwork) {
    Show-Section '通过显式代理进行网络测试（无真实授权凭据）'
    if ($ProxyPort -le 0) {
        Write-Warning '使用 -TestNetwork 时必须同时指定 -ProxyPort；跳过网络请求。'
    } else {
        $url = "http://127.0.0.1:$ProxyPort"
        & curl.exe --proxy $url -sS -o NUL `
            -w 'OAuth HTTP=%{http_code}\n' `
            --connect-timeout 8 --max-time 15 -X POST `
            'https://auth.openai.com/oauth/token' `
            -H 'Content-Type: application/x-www-form-urlencoded' `
            --data 'grant_type=invalid_test'
        & curl.exe --proxy $url -sS -o NUL `
            -w 'GitHub HTTP=%{http_code}\n' `
            --connect-timeout 8 --max-time 15 'https://github.com/'
    }
}

Write-Host "`n诊断结束。请勿提交 auth.json、完整原始日志或 Token。" -ForegroundColor Green
