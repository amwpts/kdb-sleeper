# Windows PowerShell 5.1 launcher, shared by start.bat and stop.bat.
param([ValidateSet('start', 'stop')][string]$Action = 'start')
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root
$stateFile = Join-Path $root 'data/server.windows.json'
$logFile = Join-Path $root 'data/server.log'
$errorFile = Join-Path $root 'data/server.error.log'

function Get-Server {
    if (!(Test-Path -LiteralPath $stateFile)) { return $null }
    $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
    $process = Get-Process -Id $state.processId -ErrorAction SilentlyContinue
    # A reused PID must never cause an unrelated process to be stopped.
    if ($process -and $process.ProcessName -eq 'q' -and
        $process.StartTime.ToUniversalTime().Ticks.ToString() -eq $state.startTicks -and
        $process.Path -eq $state.executable) { return $process }
    Remove-Item -LiteralPath $stateFile
    return $null
}
function Stop-Server($process) {
    Stop-Process -InputObject $process
    if (!$process.WaitForExit(10000)) { throw 'The server did not stop within 10 seconds.' }
    Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
}
function Open-Dashboard($url) {
    Write-Host "Open: $url"
    try { Start-Process $url } catch { Write-Host 'Open the address above in your browser.' }
}
try {
    $server = Get-Server
    if ($Action -eq 'stop') {
        if ($server) { Stop-Server $server; Write-Host 'Stopped sleeper-kdb.' }
        else { Write-Host 'sleeper-kdb does not appear to be running.' }
        exit 0
    }
    $port = 8080
    if (Test-Path -LiteralPath 'config/config.json') {
        $config = Get-Content -LiteralPath 'config/config.json' -Raw | ConvertFrom-Json
        if ($null -ne $config.port) {
            if ("$($config.port)" -notmatch '^\d+$' -or [long]$config.port -lt 1 -or [long]$config.port -gt 65535) {
                throw 'The port in config/config.json must be an integer from 1 to 65535.'
            }
            $port = [int]$config.port
        }
    }
    $url = "http://localhost:$port"
    if ($server) {
        $state = Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json
        $changed = Get-ChildItem -LiteralPath 'q' -Filter '*.q' -Recurse |
            Where-Object { $_.LastWriteTimeUtc -gt $server.StartTime.ToUniversalTime() }
        if (!$changed -and $state.port -eq $port) {
            Write-Host 'sleeper-kdb is already running.'
            Open-Dashboard $url
            exit 0
        }
        Write-Host 'Restarting sleeper-kdb after source or port changes.'
        Stop-Server $server
    }
    $qCommand = Get-Command q.exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    $qExe = if ($qCommand) { $qCommand.Source } else { $null }
    $candidates = @()
    if ($env:QHOME) { $candidates += (Join-Path $env:QHOME 'w64/q.exe') }
    $candidates += @("$env:USERPROFILE\q\w64\q.exe", 'C:\q\w64\q.exe')
    if (!$qExe) {
        $qExe = $candidates | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    }
    if (!$qExe) { throw 'Could not find q.exe. Install Windows kdb+/q, then set QHOME or add its w64 folder to PATH. See README.md.' }
    if (!$env:QHOME) { $env:QHOME = Split-Path -Parent (Split-Path -Parent $qExe) }
    if (!(Get-Command curl.exe -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'Could not find curl.exe. Install curl and add it to PATH, then try again.'
    }
    $listeners = [System.Net.NetworkInformation.IPGlobalProperties]::GetIPGlobalProperties().GetActiveTcpListeners()
    if ($listeners | Where-Object { $_.Port -eq $port }) {
        throw "Port $port is already in use. Stop its server or change port in config/config.json."
    }
    New-Item -ItemType Directory -Path (Join-Path $root 'data') -Force | Out-Null
    Write-Host "Starting sleeper-kdb on $url ..."
    $server = Start-Process -FilePath $qExe -ArgumentList 'q/main.q', '-q' -WorkingDirectory $root -WindowStyle Hidden -RedirectStandardOutput $logFile -RedirectStandardError $errorFile -PassThru
    @{ processId = $server.Id; startTicks = $server.StartTime.ToUniversalTime().Ticks.ToString(); executable = $qExe; port = $port } |
        ConvertTo-Json | Set-Content -LiteralPath $stateFile -Encoding UTF8
    $deadline = (Get-Date).AddSeconds(120)
    while ((Get-Date) -lt $deadline) {
        $server.Refresh()
        if ($server.HasExited) {
            Remove-Item -LiteralPath $stateFile -ErrorAction SilentlyContinue
            throw "q stopped during startup. See $logFile and $errorFile."
        }
        try {
            $response = Invoke-WebRequest -Uri "$url/api/league" -UseBasicParsing -TimeoutSec 2
            if ($response.StatusCode -eq 200) {
                Write-Host 'Ready. Use stop.bat to stop the server.'
                Open-Dashboard $url
                exit 0
            }
        } catch { }
        Start-Sleep -Milliseconds 500
    }
    throw "Startup is taking longer than two minutes. See $logFile and $errorFile. The process is still running; use stop.bat to stop it."
} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}
