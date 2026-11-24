#requires -version 5.1
<#
.SYNOPSIS
  Periodically sample TCP connections owned by Codex.exe and descendants.
.DESCRIPTION
  Diagnostic only. Sampling can miss short-lived OAuth connections.
  A public :443 socket does not prove the eventual traffic bypassed VPN/TUN.
#>
[CmdletBinding()]
param(
    [ValidateRange(1,600)][int]$Seconds = 60,
    [ValidateRange(100,5000)][int]$IntervalMs = 300,
    [ValidateRange(1,65535)][int]$ProxyPort = 44100
)

Write-Host '正在采样 Codex 进程 TCP 连接；请切换到 Codex 重现问题。' -ForegroundColor Cyan
Write-Host '只输出进程名、PID、远端端口类别及连接状态。'
$seen = @{}
$iterations = [Math]::Ceiling(1000 * $Seconds / $IntervalMs)

for ($i=0; $i -lt $iterations; $i++) {
    $processes = @(Get-CimInstance Win32_Process -ErrorAction SilentlyContinue)
    $ids = @($processes | Where-Object {
        $_.Name -match '^(codex|chatgpt)\.exe$'
    } | ForEach-Object { [int]$_.ProcessId })

    for ($level=0; $level -lt 4; $level++) {
        $children = @($processes | Where-Object {
            $ids -contains [int]$_.ParentProcessId
        } | ForEach-Object { [int]$_.ProcessId })
        $ids = @($ids + $children | Sort-Object -Unique)
    }

    $connections = @(Get-NetTCPConnection -ErrorAction SilentlyContinue |
        Where-Object {
            ($ids -contains [int]$_.OwningProcess) -and
            ($_.RemotePort -eq 443 -or
             $_.RemoteAddress -match '^(127\.|::1$|::ffff:127\.)')
        })

    foreach ($c in $connections) {
        $key = "$($c.OwningProcess)|$($c.RemoteAddress)|$($c.RemotePort)|$($c.State)"
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true

        $local = $c.RemoteAddress -match '^(127\.|::1$|::ffff:127\.)'
        $kind = if ($local -and $c.RemotePort -eq $ProxyPort) {
            '本地代理端口'
        } elseif (-not $local -and $c.RemotePort -eq 443) {
            '公网 443 连接（不代表一定绕过 TUN/VPN）'
        } else {
            '其他本地连接'
        }
        $name = ($processes | Where-Object {
            $_.ProcessId -eq $c.OwningProcess
        } | Select-Object -First 1).Name

        [PSCustomObject]@{
            Time = Get-Date -Format 'HH:mm:ss'
            Process = $name
            PID = $c.OwningProcess
            Port = $c.RemotePort
            State = $c.State
            Type = $kind
        } | Format-Table -HideTableHeaders
    }
    Start-Sleep -Milliseconds $IntervalMs
}
Write-Host '采样结束。未捕获到连接，不等于没有连接。' -ForegroundColor Yellow
