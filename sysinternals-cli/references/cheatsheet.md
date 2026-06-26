# Sysinternals CLI Cheatsheet

Dense, copy-pasteable command reference for the command-line Sysinternals tools. Grouped by goal. For full flag tables see the per-category references; for the authoritative vendor page of any tool see `references/ms-docs/<tool>.md`.

> **Before you run anything, read the rules in `SKILL.md` (EULA, on-PATH naming, admin).** Almost every command below includes `-accepteula` because the first run otherwise blocks on a GUI dialog and hangs a non-interactive shell. Tools are called by their **plain name** (`procdump`, `handle`, `autorunsc`, `sigcheck`, `listdlls`…) — a winget/Store install puts them on `PATH` and that name already resolves to the 64-bit build; for a manual zip-extract, call them by full path or append `64` for the 64-bit file.

---

## Processes, modules & memory  → `references/process-and-memory.md`

| Goal | Command |
| ---- | ------- |
| Process tree (spot bad parent/child lineage) | `pslist -accepteula -t` |
| Memory/threads/handles for a name prefix | `pslist -accepteula -x svchost` |
| Exact-name match, memory detail | `pslist -accepteula -m -e lsass` |
| Processes on a remote host | `pslist -accepteula \\HOST -u DOMAIN\admin` |
| **List only unsigned DLLs across all processes** (injection sweep) | `listdlls -accepteula -u` |
| Which processes loaded a suspect DLL | `listdlls -accepteula -d evil.dll` |
| Full modules + version + signature for a process | `listdlls -accepteula -v malware.exe` |
| Flag relocated DLLs in a PID (injection hint) | `listdlls -accepteula -r 1234` |
| All handle types for a suspect PID (mutexes, sections) | `handle -accepteula -a -p 1234` |
| Which process holds a locked file | `handle -accepteula -u C:\path\report.docx` |
| Search handles by object/path fragment | `handle -accepteula \ProgramData\evil` |
| Export all handles to CSV | `handle -accepteula -a -v > handles.csv` |
| Force-close a handle in a PID (risky) | `handle -accepteula -c 0x1A4 -p 1234 -y` |
| **Full memory dump of a process** (offline malware analysis) | `procdump -accepteula -ma 1234 D:\evi\p1234.dmp` |
| Arm a dump *before* a sample launches | `procdump -accepteula -ma -w sample.exe D:\evi` |
| Dump at process termination (catch self-deleters) | `procdump -accepteula -ma -t malware.exe D:\evi` |
| Repeated dumps to catch unpack stages | `procdump -accepteula -ma -n 5 -s 3 1234 D:\evi` |
| Dump on CPU spike (suspected miner) | `procdump -accepteula -ma -n 3 -s 5 -c 80 susp.exe D:\evi` |
| Freeze a process for live analysis (don't kill) | `pssuspend -accepteula 1234` / resume `-r 1234` |
| Headless Procmon capture, preset filters, 60 s | `procmon /accepteula /Quiet /Minimized /LoadConfig t.pmc /BackingFile C:\ir\run.pml /Runtime 60` |
| Convert a Procmon `.pml` to CSV (headless; `.pml` is GUI-only otherwise) | `procmon /OpenLog C:\ir\run.pml /SaveAs C:\ir\run.csv /Quiet /Minimized` |

## Persistence / autostart  → `references/autoruns.md`

| Goal | Command |
| ---- | ------- |
| **Full ASEP sweep, all users, hashes + signatures, CSV** | `autorunsc -accepteula -a * -s -h -c -t * > autoruns.csv` |
| Hide signed Microsoft entries (zoom to third-party) | `autorunsc -accepteula -a * -m -s -c *` |
| VirusTotal triage, only unknown/flagged (`-v` queries) | `autorunsc -accepteula -a * -h -s -vt -v -u -c *` |
| Scheduled tasks only | `autorunsc -accepteula -a t -c -h -nobanner` |
| Services + drivers only (rootkit/driver hunt) | `autorunsc -accepteula -a s -s -h -c` |
| Scan an offline / mounted image | `autorunsc -accepteula -a * -s -h -c -z D:\Windows > off.csv` |

`-a` category codes: `b`oot `d`AppInitDLL `e`xplorer `g`adgets image`h`ijack `i`Eaddon `k`nownDLL `l`ogon w`m`i `n`etwork c`o`decs `p`rinter lsa`r` `s`ervices+drivers `t`asks `w`inlogon · `*`=all

## File signature, strings, ADS, ACLs, wipe  → `references/security-and-files.md`

| Goal | Command |
| ---- | ------- |
| **Unsigned executables in System32** (malware sweep) | `sigcheck -accepteula -u -e -s c:\windows\system32` |
| Unsigned in user dirs → CSV (high-yield) | `sigcheck -accepteula -u -e -s -h -c c:\users > unsigned.csv` |
| VirusTotal hash lookup of a suspect file (`-v` queries, `-vt` accepts ToS) | `sigcheck -accepteula -vt -v -h c:\temp\suspect.exe` |
| VT on whole tree, only unknown/detected | `sigcheck -accepteula -vt -v -u -e -s c:\users` |
| Entropy / packing check | `sigcheck -accepteula -a c:\temp\packed.exe` |
| Catalog-signed check (drivers) | `sigcheck -accepteula -i -h c:\temp\file.sys` |
| Air-gap VT: stage 1 hash to CSV on victim | `sigcheck -accepteula -e -s -h -c c:\windows\system32 > out.csv` |
| Air-gap VT: stage 2 lookup on online box | `sigcheck -accepteula -vt -o out.csv > vtout.csv` |
| **Extract strings** (ASCII+Unicode default) | `strings -accepteula -nobanner -n 8 suspect.exe` |
| Unicode-only strings with offsets | `strings -accepteula -nobanner -u -o -n 8 suspect.exe` |
| Pull URL/onion IOCs | `strings -accepteula -nobanner suspect.exe \| findstr /i "http:// https:// .onion"` |
| **List NTFS alternate data streams** | `streams -accepteula suspect.exe` |
| Recursively hunt ADS (hidden payloads/MOTW) | `streams -accepteula -s c:\users\public\downloads` |
| Read an ADS (NOTE: `type` won't work) | `more < "file.txt:hidden"` |
| Strip ADS (DESTRUCTIVE — capture first) | `streams -accepteula -s -d c:\path` |
| **Services a low-priv group can modify** (privesc) | `accesschk -accepteula -uwcqv "Users" *` |
| Files under System32 writable by Users | `accesschk -accepteula -uwqs "Users" c:\windows\system32` |
| Directories writable by Users (recurse) | `accesschk -accepteula -uwdqs "Users" c:\` |
| Writable service registry keys | `accesschk -accepteula -kvuqsw "Users" hklm\System\CurrentControlSet\services` |
| Full token (groups + privileges) of a process | `accesschk -accepteula -p -f cmd.exe` |
| Secure-delete a file (3 passes) | `sdelete -accepteula -nobanner -p 3 c:\temp\secret.docx` |
| Wipe free space on C: | `sdelete -accepteula -nobanner -c c:` |
| Logon sessions + their processes (IR) | `logonsessions -accepteula -p` |
| Who can decrypt an EFS file | `efsdump -accepteula secret.docx` |

## Accounts, sessions, event logs, services  → `references/pstools.md`

| Goal | Command |
| ---- | ------- |
| Who is logged on (local + via shares) | `psloggedon -accepteula \\HOST` |
| Find every host a suspect account is on | `psloggedon -accepteula DOMAIN\suspectuser` |
| Files opened remotely over SMB (staging) | `psfile -accepteula` |
| **Security log → CSV, one record/line** | `psloglist -accepteula -s -x security > sec.csv` |
| Service installs (7045) in last 3 days (PsExec/persist) | `psloglist -accepteula -s -d 3 -i 7045 system` |
| Process-creation (4688) last 2 days | `psloglist -accepteula -s -i 4688 -d 2 security` |
| Parse a saved offline `.evt` | `psloglist -accepteula -s -l C:\evi\Security.evt Security` |
| Query a service (remote) | `psservice \\HOST -u DOMAIN\admin query Spooler` |
| Service DACL (defensive ACL check) | `psservice \\HOST security <Svc>` |
| Find every host running a service | `psservice -accepteula find termservice` |
| Disable a service's start type (does **not** stop a running instance) | `psservice \\HOST setconfig RemoteRegistry disabled` |
| Stop a running service (pair with the disable above) | `psservice \\HOST stop RemoteRegistry` |
| SID of a user / reverse SID lookup | `psgetsid -accepteula DOMAIN\user` / `psgetsid -accepteula S-1-5-...` |
| Remote host inventory (hotfixes+apps+disks) | `psinfo \\HOST -u DOMAIN\admin -h -s -d` |
| Kill a process + child tree | `pskill -accepteula -t evil.exe` |
| Rotate local admin password across hosts | `pspasswd @hosts.txt -u DOMAIN\admin Administrator "N3wP@ss!"` |
| Reboot remote host in 60s with message | `psshutdown \\HOST -r -f -t 60 -m "Patching"` |

## Remote execution (PsExec)  → `references/pstools.md`

| Goal | Command |
| ---- | ------- |
| Interactive remote shell | `psexec -accepteula \\HOST -u DOMAIN\admin cmd` |
| Run a command on many hosts from a file | `psexec -accepteula @hosts.txt -s cmd /c "whoami"` |
| Copy a local tool to target and run it | `psexec -accepteula \\HOST -c -f mytool.exe` |
| Interactive SYSTEM shell on the **local** box | `psexec -accepteula -i -s cmd.exe` |
| Regedit as SYSTEM (view SAM/SECURITY) | `psexec -accepteula -i -d -s c:\windows\regedit.exe` |
| Software deploy as SYSTEM | `psexec -accepteula \\HOST -i -s msiexec /i "c:\inst\app.msi"` |

⚠️ `psexec -p PASSWORD` exposes the password to process listings/telemetry — omit `-p` to be prompted. Without `-u`, the remote process can't reach network resources (no second hop). PsExec leaves loud artifacts (PSEXESVC service, Event 7045, `C:\Windows\PSEXEC-<src>.key`) — see `dfir-workflows.md`.

## Networking, disk & system info  → `references/networking-and-system.md`

| Goal | Command |
| ---- | ------- |
| **All TCP/UDP endpoints + owning PID, CSV, no DNS** | `tcpvcon -accepteula -a -c -n` |
| Endpoints for a suspect process | `tcpvcon -accepteula -a -n powershell` |
| TCP port-connect test, summary only | `psping -accepteula -n 100 -i 0 -q host:443` |
| TCP latency histogram | `psping -accepteula -l 8k -n 10000 -h 100 host:5000` |
| WHOIS ownership of a suspicious IP | `whois -accepteula 66.193.254.46` |
| Enumerate named pipes (C2 / PsExec clones) | `pipelist -accepteula` |
| Virtualization / SLAT support | `coreinfo -accepteula -v` |
| CPU feature flags (AES/AVX/NX) | `coreinfo -accepteula -f` |
| Directory tree sizes, CSV | `du -accepteula -nobanner -c C:\Users\jdoe` |
| File fragmentation (analyze only) | `contig -accepteula -a C:\db\large.mdf` |
| Hunt junctions / reparse points | `junction -accepteula -s C:\` |
| Hard links to a file | `findlinks -accepteula C:\Windows\System32\notepad.exe` |
| NTFS volume internals (MFT/cluster) | `ntfsinfo -accepteula c` |
| Size a registry subtree / offline hive | `ru -accepteula -q -c HKLM\SOFTWARE` · `ru -accepteula -c -h C:\evi\NTUSER.DAT` |
| Schedule a locked file for deletion at boot | `movefile -accepteula C:\malware\locked.exe ""` |
| List moves/deletes queued for next boot | `pendmoves -accepteula` |
| Hex→dec (status codes) | `hex2dec 0xC0000022` |

## Sysmon (telemetry)  → `references/sysmon.md`

| Goal | Command |
| ---- | ------- |
| Install with a detection config | `sysmon -accepteula -i sysmonconfig.xml` |
| Hot-reload config (no reboot) | `sysmon -c sysmonconfig.xml` |
| Dump active config (audit drift) | `sysmon -c` |
| Uninstall (force past missing parts) | `sysmon -u force` |
| Query process-create events | `Get-WinEvent -FilterHashtable @{logname='Microsoft-Windows-Sysmon/Operational';id=1}` |
| Query LSASS-access events | `Get-WinEvent -FilterHashtable @{logname='Microsoft-Windows-Sysmon/Operational';id=10} \| ? {$_.Message -match 'lsass'}` |
