<#
.SYNOPSIS
    Live-IR host triage: chain Sysinternals CLI tools to snapshot volatile state into one evidence folder.

.DESCRIPTION
    Collects, in order of volatility, a fast picture of a possibly-compromised Windows host:
      process tree, unsigned loaded DLLs, open handles, network endpoints (with owning PID),
      logon sessions + processes, who-is-logged-on, autostart persistence (ASEPs), and recent
      Security/System events. Every tool is invoked with -accepteula so it never blocks on the
      first-run EULA dialog, and the 64-bit binary is preferred automatically.

    Writes each artifact to a timestamped evidence folder and produces a SHA256 manifest of all
    outputs. Intended for AUTHORIZED incident response / DFIR on hosts you administer.

    Run from an ELEVATED PowerShell prompt. Point -OutDir at an EXTERNAL drive/share so you do not
    overwrite slack space on the suspect disk. Running these tools is itself forensically visible
    (EULA registry key, Prefetch) — note your run in the case log.

.PARAMETER ToolsDir
    Optional. Folder containing the Sysinternals executables (e.g. a manual zip-extract). If omitted,
    tools are called by their plain name from PATH — which is where a winget (Microsoft.Sysinternals.Suite)
    or Microsoft Store install puts them (already the 64-bit build). Only set this for a manual extract.

.PARAMETER OutDir
    Evidence output folder. Default: .\triage-<HOSTNAME>-<yyyyMMdd-HHmmss> in the current directory.

.PARAMETER Sigcheck
    Also run a (slower) recursive unsigned-executable sweep of System32 with sigcheck.

.EXAMPLE
    .\host-triage.ps1 -OutDir D:\evidence\PC07                          # tools resolved from PATH

.EXAMPLE
    .\host-triage.ps1 -ToolsDir C:\tools\sysinternals -OutDir D:\evidence\PC07   # manual extract

.NOTES
    Reference: ../references/dfir-workflows.md (sections 1-5). Built-in Get-WinEvent is used for the
    event-log pull because it is more reliable and dependency-free than psloglist for local logs.
#>
[CmdletBinding()]
param(
    [string] $ToolsDir,
    [string] $OutDir,
    [switch] $Sigcheck
)

$ErrorActionPreference = 'Continue'

# --- setup --------------------------------------------------------------------
if ($ToolsDir -and -not (Test-Path -LiteralPath $ToolsDir)) { throw "ToolsDir not found: $ToolsDir" }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $OutDir) { $OutDir = Join-Path (Get-Location) ("triage-{0}-{1}" -f $env:COMPUTERNAME, $stamp) }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$log = Join-Path $OutDir '_run.log'
function Write-Log($msg) {
    $line = "[{0}] {1}" -f (Get-Date -Format 'HH:mm:ss'), $msg
    $line | Tee-Object -FilePath $log -Append | Write-Host
}

# Resolve a tool: prefer an explicit ToolsDir (plain name, then 64-suffixed), else call it from PATH
# by its plain name (winget/Store expose the un-suffixed name, already the 64-bit build).
function Resolve-Tool($base) {
    if ($ToolsDir) {
        foreach ($name in @("$base.exe", "$base`64.exe")) {
            $p = Join-Path $ToolsDir $name
            if (Test-Path -LiteralPath $p) { return $p }
        }
    }
    if (Get-Command $base -ErrorAction SilentlyContinue) { return $base }
    return $null
}

# Run a tool with -accepteula, capturing stdout+stderr to a file.
function Invoke-Tool($base, [string[]]$Args, $OutFile) {
    $exe = Resolve-Tool $base
    if (-not $exe) { Write-Log "SKIP  $base (not found in ToolsDir)"; return }
    $full = @('-accepteula') + $Args
    Write-Log ("RUN   {0} {1}" -f (Split-Path $exe -Leaf), ($full -join ' '))
    try {
        & $exe @full *> (Join-Path $OutDir $OutFile)
    } catch {
        Write-Log ("ERROR {0}: {1}" -f $base, $_.Exception.Message)
    }
}

Write-Log "Host triage on $env:COMPUTERNAME — output: $OutDir"
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Log "WARNING: not elevated — handle/listdlls/pslist will return partial results."
}

# --- collection (order of volatility: network/process first) ------------------
Invoke-Tool 'tcpvcon'       @('-a','-c','-n')              'network_endpoints.csv'
Invoke-Tool 'pslist'        @('-t')                        'process_tree.txt'
Invoke-Tool 'pslist'        @('-x')                        'process_detail.txt'
Invoke-Tool 'listdlls'      @('-u')                        'unsigned_dlls.txt'
Invoke-Tool 'handle'        @('-a','-u')                   'handles.txt'
Invoke-Tool 'logonsessions' @('-p')                        'logon_sessions.txt'
Invoke-Tool 'psloggedon'    @()                            'logged_on.txt'
Invoke-Tool 'psfile'        @()                            'remote_open_files.txt'
Invoke-Tool 'autorunsc'     @('-a','*','-s','-h','-c','-t','-nobanner') 'autoruns.csv'

if ($Sigcheck) {
    Invoke-Tool 'sigcheck'  @('-u','-e','-s','-h','-c','-nobanner','C:\Windows\System32') 'unsigned_system32.csv'
}

# --- recent events (built-in, dependency-free) --------------------------------
Write-Log "RUN   Get-WinEvent (Security 4624/4625/4672/4688, System 7045)"
$evtOut = Join-Path $OutDir 'recent_events.csv'
$events = @()
$secIds = 4624, 4625, 4672, 4688          # logon, failed logon, special-priv logon, process create
$sysIds = 7045, 7036                        # service installed, service state change
try { $events += Get-WinEvent -FilterHashtable @{LogName='Security'; Id=$secIds; StartTime=(Get-Date).AddDays(-3)} -ErrorAction SilentlyContinue } catch {}
try { $events += Get-WinEvent -FilterHashtable @{LogName='System';   Id=$sysIds; StartTime=(Get-Date).AddDays(-3)} -ErrorAction SilentlyContinue } catch {}
$events |
    Sort-Object TimeCreated |
    Select-Object TimeCreated, Id, LogName, ProviderName,
        @{N='Message';E={ ($_.Message -split "`r?`n")[0] }} |
    Export-Csv -NoTypeInformation -Path $evtOut

# --- integrity manifest -------------------------------------------------------
Write-Log "Hashing outputs -> _manifest.sha256.csv"
Get-ChildItem -LiteralPath $OutDir -File |
    Where-Object { $_.Name -ne '_manifest.sha256.csv' } |
    Get-FileHash -Algorithm SHA256 |
    Select-Object Hash, @{N='File';E={ Split-Path $_.Path -Leaf }} |
    Export-Csv -NoTypeInformation -Path (Join-Path $OutDir '_manifest.sha256.csv')

Write-Log "Done. Review $OutDir (start with network_endpoints.csv, unsigned_dlls.txt, autoruns.csv)."
