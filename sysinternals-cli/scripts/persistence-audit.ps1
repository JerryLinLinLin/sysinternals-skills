<#
.SYNOPSIS
    Persistence / autostart audit focused on the suspicious subset: non-Microsoft and unsigned ASEPs.

.DESCRIPTION
    Runs autorunsc across all autostart extensibility points (ASEPs) with signature verification and
    hashes, then derives a noise-reduced view that hides signed Microsoft entries so third-party and
    unsigned persistence stands out. Optionally folds in VirusTotal hash lookups (-VirusTotal). Also
    runs a sigcheck unsigned-executable sweep of common drop directories.

    Output is CSV for triage in a spreadsheet or for diffing against a known-good baseline (the fastest
    way to spot NEW persistence). Run elevated for full coverage. For dead-box forensics, point
    -OfflineWindows at a mounted image's Windows directory instead of scanning the live host.

.PARAMETER ToolsDir
    Folder containing autorunsc(64).exe and sigcheck(64).exe. Required.

.PARAMETER OutDir
    Output folder. Default: .\persistence-<HOSTNAME>-<yyyyMMdd-HHmmss>.

.PARAMETER VirusTotal
    Add VirusTotal hash lookups (-vt). Hash-only — never uploads files. Network + VT ToS acceptance.

.PARAMETER OfflineWindows
    Scan an offline/mounted Windows directory (e.g. E:\Windows) instead of the live system.

.EXAMPLE
    .\persistence-audit.ps1 -ToolsDir C:\tools\sysinternals -VirusTotal

.EXAMPLE
    .\persistence-audit.ps1 -ToolsDir C:\tools\sysinternals -OfflineWindows E:\Windows

.NOTES
    Reference: ../references/dfir-workflows.md (section 4) and ../references/autoruns.md.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)] [string] $ToolsDir,
    [string] $OutDir,
    [switch] $VirusTotal,
    [string] $OfflineWindows
)

$ErrorActionPreference = 'Continue'
if (-not (Test-Path -LiteralPath $ToolsDir)) { throw "ToolsDir not found: $ToolsDir" }
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
if (-not $OutDir) { $OutDir = Join-Path (Get-Location) ("persistence-{0}-{1}" -f $env:COMPUTERNAME, $stamp) }
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Resolve-Tool($base) {
    foreach ($name in @("$base`64.exe", "$base.exe")) {
        $p = Join-Path $ToolsDir $name
        if (Test-Path -LiteralPath $p) { return $p }
    }
    throw "Required tool '$base' not found in $ToolsDir"
}
function Run($exe, [string[]]$Args, $OutFile) {
    Write-Host ("RUN  {0} {1}" -f (Split-Path $exe -Leaf), ($Args -join ' '))
    & $exe @Args *> (Join-Path $OutDir $OutFile)
}

$autorunsc = Resolve-Tool 'autorunsc'
$sigcheck  = Resolve-Tool 'sigcheck'

# Common autorunsc args: all categories, verify sigs, hashes, UTC timestamps, CSV, no banner.
$arArgs = @('-accepteula','-a','*','-s','-h','-t','-c','-nobanner')
if ($VirusTotal) { $arArgs += @('-vt','-v') }     # -vt accepts VT ToS; -v = hash lookup (no upload)

# Full inventory.
if ($OfflineWindows) {
    if (-not (Test-Path -LiteralPath $OfflineWindows)) { throw "OfflineWindows path not found: $OfflineWindows" }
    Run $autorunsc ($arArgs + @('-z', $OfflineWindows)) 'autoruns_all.csv'
} else {
    Run $autorunsc ($arArgs + @('*')) 'autoruns_all.csv'   # trailing * = all user profiles
}

# Noise-reduced view: hide signed Microsoft entries (-m) so third-party/unsigned stands out.
$focusArgs = @('-accepteula','-a','*','-s','-h','-t','-m','-c','-nobanner')
if ($VirusTotal) { $focusArgs += @('-vt','-v','-u') }   # -u: with VT, only unknown/non-zero-detection
if ($OfflineWindows) { $focusArgs += @('-z', $OfflineWindows) } else { $focusArgs += @('*') }
Run $autorunsc $focusArgs 'autoruns_nonMicrosoft.csv'

# Unsigned executables in common drop directories (live host only).
if (-not $OfflineWindows) {
    $dropDirs = @("$env:ProgramData", "$env:SystemRoot\Temp", "$env:PUBLIC")
    foreach ($d in $dropDirs) {
        if (Test-Path -LiteralPath $d) {
            $safe = ($d -replace '[:\\ ]', '_')
            $scArgs = @('-accepteula','-u','-e','-s','-h','-c','-nobanner', $d)
            if ($VirusTotal) { $scArgs = @('-accepteula','-u','-e','-s','-h','-vt','-c','-nobanner', $d) }
            Run $sigcheck $scArgs ("unsigned_{0}.csv" -f $safe)
        }
    }
}

Write-Host ""
Write-Host "Done -> $OutDir"
Write-Host "Triage order: autoruns_nonMicrosoft.csv (third-party persistence) -> unsigned_*.csv -> autoruns_all.csv (baseline diff)."
Write-Host "Tip: diff autoruns_all.csv against a known-good baseline of the same image to surface NEW entries."
