# PsTools — Remote & Local Administration CLI

> The PsTools suite covers remote process execution, process/service/session enumeration, event logs, and host info. Most tools accept `\\computer[,computer,...]` (or `@file` for a list) plus `-u`/`-p` for remote credentials. The suite shares a one-time per-machine EULA: every tool accepts `-accepteula` to suppress the first-run license dialog (only PsExec documents it explicitly), which is mandatory for non-interactive/automation use or the tool will hang on the popup. Authoritative per-tool docs (full flag tables) live in `references/ms-docs/<tool>.md`.

## PsExec (`psexec`)
**Purpose:** Execute processes on remote (or local) systems, interactively or detached.
**Privilege / EULA:** Needs admin rights on the target (and the Admin$ share / File and Printer Sharing reachable). Pass `-accepteula` for non-interactive runs and `-nobanner` to suppress the startup banner. Omitting `-u` impersonates your token (no network access on the remote side); use `Domain\User` for network resource access.
**Synopsis:**
```text
psexec [\\computer[,computer2[,...] | @file]][-u user [-p psswd]][-n s][-r servicename][-h][-l][-s|-e][-x][-i [session]][-c [-f|-v]][-w directory][-d][-<priority>][-g n][-a n,n,...][-accepteula][-nobanner] cmd [arguments]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` / `@file` / `\\*` | Target host(s); file list; or all computers in the domain |
| `-u` / `-p` | Remote username / password (omit `-p` to be prompted) |
| `-s` | Run as the Local System account |
| `-h` | Run with the account's elevated token (Vista+) |
| `-l` | Run as limited user (strips Administrators group / Low Integrity) |
| `-e` | Do not load the account's profile |
| `-i [session]` | Interact with the desktop of the given session (required for interactive console I/O) |
| `-c` / `-f` / `-v` | Copy the exe to the target; `-f` overwrite, `-v` copy only if newer |
| `-d` | Don't wait for the process to terminate (detached) |
| `-w` | Set the remote working directory |
| `-n s` | Connection timeout (seconds) to remote computers |
| `-accepteula` | Suppress the EULA dialog (required for automation) |
| `-nobanner` | Suppress startup banner |
**Examples:**
```cmd
# Open an interactive remote command prompt
psexec \\marklap -accepteula -u DOMAIN\admin cmd

# Run ipconfig /all on a remote host and show output locally
psexec \\marklap -accepteula ipconfig /all

# Copy a tool to the target and run it interactively (-i is required for interactive/redirected IO)
psexec \\marklap -accepteula -i -c test.exe

# Dump SAM/SECURITY by running regedit as System, detached (DFIR/forensics)
psexec -i -d -s -accepteula c:\windows\regedit.exe

# Fan out a command to every machine listed in a file
psexec @hosts.txt -accepteula -u DOMAIN\admin -s cmd /c "net localgroup administrators"
```
**Output / parsing:** PsExec relays the remote process's stdout/stderr and returns the remote process's exit code (not its own), so it scripts cleanly. Use `-d` for fire-and-forget; avoid `-i` in batch contexts.
**Full reference:** `references/ms-docs/psexec.md`

## PsList (`pslist`)
**Purpose:** List processes (and threads/memory) with performance-counter detail, local or remote.
**Privilege / EULA:** Reads performance counters; remote use may need `-u`/`-p` if your credentials can't read remote counters. Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
pslist [-d][-m][-x][-t][-s [n]][-r n][\\computer [-u user [-p psswd]]][-e] [name | pid]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` | Query a remote system |
| `-u` / `-p` | Remote username / password |
| `name` | Show processes whose name begins with `name` |
| `-e` | Exact-match the process name |
| `pid` | Restrict to the process with this PID |
| `-d` | Show thread detail |
| `-m` | Show memory detail |
| `-x` | Show processes, memory, and threads |
| `-t` | Show process tree |
| `-s [n]` | Task-manager mode (optionally for `n` seconds) |
| `-r n` | Refresh rate (seconds) for `-s` mode |
**Examples:**
```cmd
# List all processes on a remote host
pslist \\server01 -u DOMAIN\admin

# Show the process tree (spot suspicious parent/child chains)
pslist -t

# Exact-match a single process and show memory detail
pslist -m -e lsass

# Dump full stats (memory + threads) for one PID
pslist -x 4321
```
**Output / parsing:** Text-table output only (no CSV option). Memory values are in KB. Column legend: Pri, Thd, Hnd, VM, WS, Priv, Priv Pk, Faults, NonP, Page, Cswtch.
**Full reference:** `references/ms-docs/pslist.md`

## PsKill (`pskill`)
**Purpose:** Terminate processes by PID or name on the local or a remote system.
**Privilege / EULA:** Killing on a remote host requires admin rights there (use `-u`/`-p` if needed). Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
pskill [- ] [-t] [\\computer [-u username] [-p password]] <process name | process id>
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` | Target remote host (reachable via network neighborhood) |
| `-u` / `-p` | Remote admin username / password |
| `-t` | Kill the process and its descendant tree |
| `process id` | Numeric PID to kill |
| `process name` | Kill all processes with this name |
**Examples:**
```cmd
# Kill a process by PID locally
pskill -accepteula 4321

# Kill a malicious process and its whole child tree (containment)
pskill -accepteula -t evil.exe

# Kill a process by name on a remote host
pskill \\server01 -u DOMAIN\admin -accepteula badproc.exe
```
**Output / parsing:** Minimal text confirmation; no structured output. Drive it from PSList/tasklist output for scripted hunts.
**Full reference:** `references/ms-docs/pskill.md`

## PsService (`psservice`)
**Purpose:** View, configure, and control Windows services locally or remotely; search the network for a service.
**Privilege / EULA:** Service control needs appropriate rights on the target; use `-u`/`-p` for a different remote account. Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
psservice [\\computer [-u username] [-p password]] <command> <options>
```
**Key flags (commands):**
| Flag | Meaning |
|------|---------|
| `\\computer` | Target remote host |
| `-u` / `-p` | Remote username / password |
| `query` | Display the status of a service |
| `config` | Display a service's configuration |
| `setconfig` | Set start type: `disabled` / `auto` / `demand` |
| `start` / `stop` / `restart` | Start / stop / stop-then-start a service |
| `pause` / `cont` | Pause / resume a service |
| `depend` | List services dependent on the one specified |
| `security` | Dump the service's security descriptor |
| `find` | Search the network for the specified service |
**Examples:**
```cmd
# Query the status of a service on a remote host
psservice \\server01 -u DOMAIN\admin -accepteula query Spooler

# Stop and disable a service (lock down an attack surface)
psservice \\server01 -accepteula stop RemoteRegistry
psservice \\server01 -accepteula setconfig RemoteRegistry disabled

# Find every machine on the network running a given service
psservice -accepteula find termservice

# Dump a service's security descriptor (privilege review)
psservice -accepteula security Spooler
```
**Output / parsing:** Text output per command (status, config, dependencies, SDDL for `security`). No CSV mode; parse line-by-line.
**Full reference:** `references/ms-docs/psservice.md`

## PsLogList (`psloglist`)
**Purpose:** Dump and filter event log records from the local or remote systems; supports CSV-style output.
**Privilege / EULA:** Remote log access may need `-u`/`-p`. `-c` clears the log after display — destructive, use deliberately. Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
psloglist [- ] [\\computer[,computer[,...]] | @file [-u username [-p password]]] [-s [-t delimiter]] [-m #|-n #|-h #|-d #|-w][-c][-x][-r][-a mm/dd/yy][-b mm/dd/yy][-f filter] [-i ID[,ID[,...]] | -e ID[,ID[,...]]] [-o event source[,...]] [-q event source[,...]] [-l event log file] <eventlog>
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` / `@file` | Target host(s) / list of hosts |
| `-u` / `-p` | Remote username / password |
| `<eventlog>` | Log name (e.g. `System`, `Security`, `Application`) |
| `-s` | One record per line, comma-delimited (search/parse friendly) |
| `-t delimiter` | Override the `-s` delimiter character |
| `-n #` | Only the `#` most recent entries |
| `-m #` / `-h #` / `-d #` | Records from the last `#` minutes / hours / days |
| `-a` / `-b mm/dd/yy` | Records after / before a date |
| `-i ID,...` / `-e ID,...` | Include only / exclude these Event IDs (up to 10) |
| `-o src,...` / `-q src,...` | Only / omit records from these event sources |
| `-f filter` | Filter by event type (e.g. `-f w` for warnings) |
| `-x` | Dump extended data |
| `-r` | Order least-recent to most-recent |
| `-l file` | Read from a saved `.evt` event log file |
| `-c` | Clear the log after displaying (destructive) |
| `-w` | Wait and tail new events (local only) |
**Examples:**
```cmd
# Pull Security log failed-logon events (4625) in CSV form for triage
psloglist \\dc01 -u DOMAIN\admin -accepteula -s -i 4625 Security

# Last 24 hours of System errors only, parse-friendly
psloglist -accepteula -s -h 24 -f e System

# Dump the most recent 200 Security records to CSV with a custom delimiter
psloglist -accepteula -s -t "|" -n 200 Security

# Parse a saved offline event log file (DFIR on a collected .evt)
psloglist -accepteula -s -l C:\evidence\Security.evt Security
```
**Output / parsing:** `-s` produces one-record-per-line, comma-delimited output (override with `-t`) — the format to use for grep/CSV ingestion. Combine with `-i`/`-e`/time-window flags to keep output lean. Note PsLogList has **no `-nobanner`** flag, so even with `-s` it emits its version banner (a blank line, three copyright lines, a blank line) before the first record — skip those lines when importing as CSV (e.g. filter to rows matching a date, or `Select-Object -Skip 5`). The message field is double-quoted and can contain commas, so parse with a real CSV reader, not a plain comma split.
**Full reference:** `references/ms-docs/psloglist.md`

## PsLoggedOn (`psloggedon`)
**Purpose:** Show users logged on to a system (locally and via resource shares), or find where a named user is logged on.
**Privilege / EULA:** Querying a remote system loads its registry (your session shows as connected via share). Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
psloggedon [- ] [-l] [-x] [\\computername | username]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computername` | List logon info for this computer |
| `username` | Search the network for computers where this user is logged on |
| `-l` | Show only local logons (skip network resource logons) |
| `-x` | Don't show logon times |
**Examples:**
```cmd
# Who is logged on (local + share) to a host
psloggedon -accepteula \\workstation07

# Only local interactive logons on a host
psloggedon -accepteula -l \\workstation07

# Hunt: find every machine where a suspect account is logged on (lateral movement)
psloggedon -accepteula DOMAIN\suspectuser
```
**Output / parsing:** Plain text listing of usernames and logon times; no structured/CSV mode. Use `-x` to drop timestamps for cleaner diffs.
**Full reference:** `references/ms-docs/psloggedon.md`

## PsFile (`psfile`)
**Purpose:** List files opened remotely on a system (via SMB), and optionally close them by ID or path.
**Privilege / EULA:** Remote query/close may need `-u`/`-p`. Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
psfile [\\RemoteComputer [-u Username [-p Password]]] [[Id | path] [-c]]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\RemoteComputer` | Target host |
| `-u` / `-p` | Remote username / password |
| `Id` | File identifier (assigned by PsFile) to show or close |
| `path` | Full/partial path to match files to show or close |
| `-c` | Close the matched file(s) |
**Examples:**
```cmd
# List all files opened remotely on the local server
psfile

# List remotely-opened files on another server
psfile \\fileserver01 -u DOMAIN\admin -accepteula

# Force-close a locked file by path (release a stuck SMB handle)
psfile \\fileserver01 -accepteula "D:\share\report.xlsx" -c

# Close a specific open file by its PsFile ID
psfile -accepteula 1234 -c
```
**Output / parsing:** Text listing of file IDs, paths, accessing user, and lock count; no CSV mode. Use the printed ID with `-c` for precise closes.
**Full reference:** `references/ms-docs/psfile.md`

## PsGetSid (`psgetsid`)
**Purpose:** Translate account names to SIDs and SIDs to account names; also report a computer's SID. Works for builtin, domain, and local accounts.
**Privilege / EULA:** Remote queries may need `-u`/`-p`. Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
psgetsid [\\computer[,computer[,...]] | @file] [-u username [-p password]]] [account|SID]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` / `@file` / `\\*` | Target host(s) / list / all domain computers |
| `-u` / `-p` | Remote username / password |
| `account` | Report the SID for this account |
| `SID` | Report the account name for this SID |
| (no account) | Report the target computer's machine SID |
**Examples:**
```cmd
# Get the SID of a user account
psgetsid -accepteula DOMAIN\administrator

# Reverse-lookup an account name from a SID (DFIR on log artifacts)
psgetsid -accepteula S-1-5-21-1234567890-1234567890-1234567890-500

# Get a remote computer's machine SID
psgetsid \\workstation07 -u DOMAIN\admin -accepteula

# Compare machine SIDs across hosts (detect cloned images)
psgetsid -accepteula @hosts.txt
```
**Output / parsing:** Prints the SID or account string directly — easy to capture in a variable or pipe. Use `@file` / `\\*` to batch across hosts.
**Full reference:** `references/ms-docs/psgetsid.md`

## PsInfo (`psinfo`)
**Purpose:** Gather key system info (OS build, uptime, CPUs, memory, install date) plus optional hotfixes, installed apps, and disk volumes; local or remote.
**Privilege / EULA:** Relies on remote registry access — the target must run the Remote Registry service and your account needs `HKLM\System` access (use `-u`/`-p`). Pass `-accepteula` on first non-interactive run. Returns the Service Pack number as its exit value for automation.
**Synopsis:**
```text
psinfo [[\\computer[,computer[,..] | @file [-u user [-p psswd]]] [-h] [-s] [-d] [-c [-t delimiter]] [filter]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` / `@file` / `\\*` | Target host(s) / list / all domain computers |
| `-u` / `-p` | Remote username / password |
| `-h` | List installed hotfixes |
| `-s` | List installed applications |
| `-d` | Show disk volume information |
| `-c` | Print in CSV format |
| `-t delimiter` | Override the `-c` delimiter (default comma) |
| `filter` | Show only the field(s) matching the filter |
**Examples:**
```cmd
# Full inventory of a remote host: hotfixes + apps + disks
psinfo \\server01 -u DOMAIN\admin -accepteula -h -s -d

# CSV inventory across all hosts in a file (asset reporting)
psinfo @hosts.txt -accepteula -c -h > inventory.csv

# Pull just the patch level / service pack field
psinfo -accepteula "service pack"

# CSV with a pipe delimiter for ingestion
psinfo -accepteula -c -t "|" -s
```
**Output / parsing:** `-c` emits CSV (override delimiter with `-t`) — the mode for scripting/inventory. Combine `-h`/`-s`/`-d` to add hotfix/app/disk sections; `filter` narrows to one field.
**Full reference:** `references/ms-docs/psinfo.md`

## PsPasswd (`pspasswd`)
**Purpose:** Change/reset a local or domain account password on local or remote systems; built for mass admin-password rotation via batch.
**Privilege / EULA:** Needs rights to reset the target account (use `-u`/`-p` for a remote admin). Uses Windows password-reset APIs (no cleartext over the wire). Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
pspasswd [[\\computer[,computer[,..] | @file [-u user [-p psswd]]] Username [NewPassword]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` / `@file` / `\\*` | Target host(s) / list / all domain computers |
| `-u` / `-p` | Remote admin username / password used to connect |
| `Username` | Account whose password to change |
| `NewPassword` | New password (omit to set a NULL password) |
**Examples:**
```cmd
# Rotate the local Administrator password on one host
pspasswd \\server01 -u DOMAIN\admin -accepteula Administrator "N3wP@ss!"

# Mass-rotate local admin password across all hosts in a file
pspasswd @hosts.txt -u DOMAIN\admin -accepteula Administrator "N3wP@ss!"

# Change a domain account password from the local machine
pspasswd -accepteula DOMAIN\serviceacct "Rotat3dP@ss"
```
**Output / parsing:** Per-host success/failure text — capture it when fanning out with `@file`/`\\*` to confirm every machine rotated. Avoid leaving the new password in shell history/logs.
**Full reference:** `references/ms-docs/pspasswd.md`

## PsShutdown (`psshutdown`)
**Purpose:** Shut down, reboot, hibernate, suspend, lock, log off, or abort shutdown on local or remote computers, with countdown and user messaging.
**Privilege / EULA:** Remote shutdown needs admin rights (use `-u`/`-p`). Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
psshutdown [[\\computer[,computer[,..] | @file [-u user [-p psswd]]] -s|-r|-h|-d|-k|-a|-l|-o|-x [-f] [-c] [-t nn|h:m] [-n s] [-v nn] [-e [u|p]:xx:yy] [-m "message"]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` / `@file` / `\\*` | Target host(s) / list / all domain computers |
| `-u` / `-p` | Remote admin username / password |
| `-s` | Shutdown (no power off) |
| `-r` | Reboot after shutdown |
| `-k` | Power off (reboot if power off unsupported) |
| `-h` | Hibernate |
| `-d` | Suspend |
| `-o` | Log off the console user |
| `-l` | Lock the computer |
| `-a` | Abort a countdown in progress |
| `-f` | Force apps to exit (no save prompt) |
| `-t nn\|h:m` | Countdown seconds, or absolute time (24h) |
| `-c` | Let the interactive user abort |
| `-m "message"` | Message shown to logged-on users |
| `-e [u\|p]:xx:yy` | Shutdown reason code (user/planned, major:minor) |
**Examples:**
```cmd
# Reboot a remote host in 60s, forcing apps closed, with a warning message
psshutdown \\server01 -u DOMAIN\admin -accepteula -r -f -t 60 -m "Patching reboot in 60s"

# Abort an in-progress shutdown countdown
psshutdown \\server01 -accepteula -a

# Lock the local console immediately
psshutdown -accepteula -l

# Power off all machines listed in a file at a set time, with reason code
psshutdown @hosts.txt -accepteula -k -t 22:00 -e p:0:0
```
**Output / parsing:** Status text per host; the countdown/abort model (`-t`/`-a`/`-c`) is the key automation lever. No structured output.
**Full reference:** `references/ms-docs/psshutdown.md`

## PsSuspend (`pssuspend`)
**Purpose:** Suspend (freeze) or resume processes by PID or name, locally or remotely — pause a resource hog instead of killing it.
**Privilege / EULA:** Remote use needs admin rights on the target (use `-u`/`-p`). Pass `-accepteula` on first non-interactive run.
**Synopsis:**
```text
pssuspend [- ] [-r] [\\computer [-u username] [-p password]] <process name | process id>
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `\\computer` | Target remote host |
| `-u` / `-p` | Remote admin username / password |
| `-r` | Resume the specified process(es) instead of suspending |
| `process id` | PID to suspend/resume |
| `process name` | Suspend/resume all processes with this name |
**Examples:**
```cmd
# Freeze a suspicious process for live analysis without killing it (DFIR)
pssuspend -accepteula 4321

# Suspend all instances of a runaway process by name
pssuspend -accepteula hog.exe

# Resume a previously suspended process
pssuspend -accepteula -r 4321

# Suspend a process on a remote host
pssuspend \\server01 -u DOMAIN\admin -accepteula badproc.exe
```
**Output / parsing:** Minimal text confirmation; no structured output. Pair with PsList to find the PID, then suspend before collecting memory artifacts.
**Full reference:** `references/ms-docs/pssuspend.md`
