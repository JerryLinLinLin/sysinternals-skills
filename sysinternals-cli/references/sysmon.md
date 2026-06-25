# Sysmon — System Monitor (Detection Engineering)

> Sysmon is a driver + service that logs rich process, network, registry, file, and DNS telemetry to the Windows Event Log (`Applications and Services Logs/Microsoft/Windows/Sysmon/Operational`). It is driven entirely from the CLI for install, configuration, and uninstall, and is configured via an XML rules file. Authoritative per-tool docs (full flag tables) live in `references/ms-docs/sysmon.md`.

## Sysmon (`sysmon`)
**Purpose:** Install/configure a resident service + boot-start driver that records process/network/registry/file/DNS events to the Windows Event Log for detection and DFIR.
**Privilege / EULA:** Requires an elevated (Administrator) command prompt for install, config update, and uninstall. Pass `-accepteula` to auto-accept the EULA on install for non-interactive/automation use; otherwise the first run blocks on an interactive EULA prompt. (No `-nobanner` flag exists for Sysmon.) Note: the 64-bit binary is `sysmon64.exe`; `sysmon.exe` is the cross-bitness wrapper used in examples.

**Synopsis:**
```text
Install:                 sysmon64 -i [<configfile>]
Update configuration:    sysmon64 -c [<configfile>]
Install event manifest:  sysmon64 -m
Print schema:            sysmon64 -s
Uninstall:               sysmon64 -u [force]
```

**Key flags:**

| Flag | Meaning |
| ---- | ------- |
| `-i [<configfile>]` | Install service and driver; optionally apply a configuration file. |
| `-c [<configfile>]` | Update the configuration of an installed driver. With no arg, dumps the current configuration. Use `-c --` to reset to default settings. |
| `-m` | Install the event manifest (also done implicitly on service install). |
| `-s` | Print the full configuration schema (event tags, field names and types). |
| `-u` | Uninstall service and driver. `-u force` proceeds even when some components are missing. |
| `-accepteula` | Auto-accept the EULA on install (required for non-interactive use). |
| `-? config` | Print configuration-file help and the current schema version. |

**Examples:**
```cmd
# Install with default settings (SHA1 image hashing, no network monitoring), auto-accept EULA
sysmon -accepteula -i
```
```cmd
# Install with a hardened detection config (e.g. SwiftOnSecurity / Olaf Hartong baseline)
sysmon -accepteula -i c:\windows\config.xml
```
```cmd
# Hot-reload an active Sysmon with an updated rules file (no reboot, no reinstall)
sysmon -c c:\windows\config.xml
```
```cmd
# Dump the currently active configuration for audit / drift detection
sysmon -c
```
```cmd
# Reset configuration back to built-in defaults
sysmon -c --
```
```cmd
# Print the event schema (field names/types) to author or validate a config
sysmon -s
```
```cmd
# Uninstall the service and driver during IR cleanup, forcing past missing components
sysmon -u force
```

**Output / parsing:** Sysmon has no CSV switch — its real output is structured Windows Event Log records under `Microsoft-Windows-Sysmon/Operational` (timestamps in UTC). Query/export from the CLI with `wevtutil qe Microsoft-Windows-Sysmon/Operational /f:text` (or `/f:xml`) or PowerShell `Get-WinEvent -LogName Microsoft-Windows-Sysmon/Operational`. `sysmon -c` (config dump) and `sysmon -s` (schema) print to stdout for scripting/diffing; events filter via the XML config's `<EventFiltering>` rules (`onmatch="include"|"exclude"`, conditions like `is`, `contains`, `image`, `begin with`, `end with`). The service auto-reloads config when the registry changes.

## Sysmon Event ID reference

These are the events Sysmon writes; tight config filtering decides which actually fire. The high-value detection events are flagged. Events 3 (network) and 7 (image load) are **disabled by default** — they only fire if enabled in the XML config (Event 7 / image load also has the legacy install switch `-l`; network logging is configured in current versions via the config's `<NetworkConnect>` rules).

| ID | Event | Detection value |
| -- | ----- | --------------- |
| 1 | ProcessCreate | ★ Full command line, parent image, hashes, user — backbone of most detections (LOLBins, attacker commands). |
| 2 | FileCreateTime changed | Timestomping / anti-forensics (T1070.006). |
| 3 | NetworkConnect | ★ Source process → dest IP/port/host. C2/beacon hunting. *Disabled by default.* |
| 4 | Sysmon service state changed | Sysmon start/stop — tampering signal outside deploy windows. |
| 5 | ProcessTerminate | Process lifetime / correlation. |
| 6 | DriverLoad | Malicious / unsigned kernel drivers (BYOVD). |
| 7 | ImageLoad (module load) | ★ Unsigned/sideloaded DLLs, signature + path. *Disabled by default; high volume.* |
| 8 | CreateRemoteThread | ★ Classic code-injection indicator (Source→Target image, StartFunction). |
| 9 | RawAccessRead | `\\.\` raw disk reads — SAM/NTDS theft, lock bypass. |
| 10 | ProcessAccess | ★ OpenProcess to **lsass.exe** = credential dumping; alert on GrantedAccess masks (0x1010, 0x1410, 0x1438, 0x1F1FFF). |
| 11 | FileCreate | ★ Dropped payloads, `.dmp` files, Startup-folder persistence. |
| 12/13/14 | RegistryEvent (key create-delete / value set / rename) | ★ Run-key & autostart persistence, config tampering. |
| 15 | FileCreateStreamHash | ★ NTFS Alternate Data Stream creation (incl. Zone.Identifier / mark-of-the-web). |
| 16 | Sysmon config changed | Config tampering / drift audit. |
| 17/18 | PipeEvent (created / connected) | ★ Named-pipe C2 and PsExec (`\PSEXESVC`), Cobalt Strike pipes. |
| 19/20/21 | WmiEvent (filter / consumer / binding) | ★ WMI-based persistence (T1546.003). |
| 22 | DnsQuery | ★ Beaconing domains / DNS tunneling. Only sees `dnsapi.dll DnsQuery_*` (Win8.1+) — blind to raw-socket/DoH. |
| 23 | FileDelete (archived) | Anti-forensic wiping; **copies deleted files to ArchiveDirectory — can fill the disk**. |
| 24 | ClipboardChange | Clipboard capture / data theft. |
| 25 | ProcessTampering | Process hollowing / herpaderping / image replacement. |
| 26 | FileDeleteDetected | Delete logging **without** archiving (lighter than 23). |
| 27 | FileBlockExecutable | Blocked executable write (prevention). |
| 28 | FileBlockShredding | Blocks SDelete-style secure-wipe / shredding. |
| 29 | FileExecutableDetected | New executable written to disk. |
| 255 | Error | Sysmon internal error. |

## Community configs, deployment & querying

**Configs** — almost nobody hand-writes Sysmon rules; deploy a community baseline and tune:
- **SwiftOnSecurity/sysmon-config** (`sysmonconfig-export.xml`) — well-commented, opinionated starter baseline.
- **olafhartong/sysmon-modular** — per-technique XML modules tagged to MITRE ATT&CK; merge into one config:
  ```powershell
  # clone github.com/olafhartong/sysmon-modular first, then:
  Import-Module .\Merge-SysmonXml.ps1
  Merge-AllSysmonXml -Path (Get-ChildItem '[0-9]*\*.xml') -AsString | Out-File sysmonconfig.xml
  sysmon64 -accepteula -i sysmonconfig.xml          # fresh install
  sysmon64 -c sysmonconfig.xml                       # update an existing install in place
  ```

**Gotchas that bite automation:**
- Config `schemaversion` is bound to the binary version — a newer-schema config is rejected by an older Sysmon. Upgrade the binary before pushing a newer config.
- Windows 11 ships an optional **built-in Sysmon** (`Enable-WindowsOptionalFeature -Online -FeatureName Sysmon`) that **cannot coexist** with the standalone download. Always check `Get-Service sysmon*` first.
- Events 7 (ImageLoad) and 10 (ProcessAccess) are extremely high-volume — never enable unfiltered.
- The service is named `Sysmon` or `Sysmon64` to match the binary you installed; scripts that hardcode the wrong name mis-detect install state.

**Query the telemetry from the CLI:**
```powershell
# Process-creation events (FilterHashtable is far faster than Where-Object)
Get-WinEvent -FilterHashtable @{logname='Microsoft-Windows-Sysmon/Operational'; id=1} -MaxEvents 50
# LSASS access attempts (credential theft)
Get-WinEvent -FilterHashtable @{logname='Microsoft-Windows-Sysmon/Operational'; id=10} | Where-Object { $_.Message -match 'lsass' }
```
```cmd
:: No-PowerShell alternative — 20 newest events, newest first, as text
wevtutil qe Microsoft-Windows-Sysmon/Operational /c:20 /rd:true /f:text
```

**Full reference:** `references/ms-docs/sysmon.md`
