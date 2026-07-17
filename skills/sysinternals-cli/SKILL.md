---
name: sysinternals-cli
description: >-
  Cheatsheet for using the Microsoft Sysinternals command-line tools on Windows from a shell. Use it
  whenever a task involves a Sysinternals/PsTools utility — PsExec, PsList, PsService, PsLogList,
  ProcDump, Handle, ListDLLs, Autoruns/autorunsc, Sigcheck, Strings, Streams, AccessChk, SDelete,
  TCPView/tcpvcon, PsPing, Sysmon, Coreinfo, Junction, du — or when the goal is Windows live forensics
  / incident response / DFIR, malware triage, threat hunting, persistence enumeration, unsigned-binary
  or signature checking, VirusTotal-by-hash, process/handle/DLL inspection, memory/crash dumps, NTFS
  alternate-data-stream hunting, privilege-escalation auditing of service/file/registry ACLs, remote
  command execution, or event-log collection.
---

# Sysinternals CLI

The Sysinternals suite is ~70 small, single-purpose Windows utilities by Mark Russinovich et al. Many are command-line driven and are the standard toolkit for Windows troubleshooting, system administration, and — heavily — digital forensics, incident response, and threat hunting. This skill is the entry point for using them **from a shell, non-interactively**.

This file routes you to the right tool and reference. **Read the three operating rules first — they are what make these tools work in an automated shell.** Then jump to the relevant reference or playbook; don't load everything.

## ⚠️ Three rules that make this work (read before running anything)

1. **Pass `-accepteula` or the run hangs.** Every Sysinternals tool shows a one-time GUI license dialog on first run *per user*. In a non-interactive shell that dialog blocks forever. Always include `-accepteula`. To pre-seed it for all tools instead: `reg add HKCU\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f` (it's per-user/HKCU, so running as SYSTEM or another account re-prompts). Many tools also accept `-nobanner` to keep the copyright banner out of parsed output.
2. **Call tools by their plain name — assume they're on PATH, and don't add the `64` suffix.** A winget (`Microsoft.Sysinternals.Suite`) or Microsoft Store install puts the suite on `PATH` under each tool's **un-suffixed** name, and that name already resolves to the **64-bit** build — so just run `procdump`, `sigcheck`, `accesschk`, `autorunsc`, `handle`, `listdlls`, `pslist`, `tcpvcon`. If a command comes back "not recognized", the host has a manual zip-extract instead: call the tool by full path (`C:\tools\sysinternals\procdump.exe`) or add that folder to `PATH`. (Only edge case: in a manual extract the plain name is the *32-bit* build and the `64`-suffixed file is the 64-bit one — append `64` **only** there; on winget/Store the plain name is already 64-bit.) Need the tools installed? `winget install --id Microsoft.Sysinternals.Suite`, or grab one on demand from `https://live.sysinternals.com/<tool>.exe`.
3. **Most need Administrator**, and fail *quietly* without it (partial/empty output or access-denied, not a clear error). `handle`, `listdlls`, `procdump -ma`, `pslist`, `sysmon`, `ntfsinfo`, `autorunsc -a *` all want an elevated shell.

One more for security work: **AV/EDR flags the tools themselves** (`procdump.exe`, `psexec.exe`, `handle.exe`, `accesschk.exe` are common dual-use/LOLBin detections) and may quarantine them mid-task. Stage from a known-good copy and verify a tool runs before relying on it.

## Route by goal

| If the goal is… | Reach for | Reference |
| --------------- | --------- | --------- |
| Inspect running processes / process tree; per-process CPU/memory/handle/thread snapshot | `pslist` | [pstools.md](references/pstools.md) |
| Find what DLLs/modules a process loaded; hunt unsigned/injected DLLs | `listdlls` | [process-and-memory.md](references/process-and-memory.md) |
| See open handles; which process locks a file; find malware mutexes | `handle` | [process-and-memory.md](references/process-and-memory.md) |
| Dump a process's memory (crash/hang/CPU spike, or malware analysis) | `procdump` | [process-and-memory.md](references/process-and-memory.md) |
| Freeze/resume a process without killing it | `pssuspend` | [pstools.md](references/pstools.md) |
| Headless capture of file/registry/process activity | `procmon` (CLI flags) | [process-and-memory.md](references/process-and-memory.md) |
| Enumerate autostart / persistence locations (ASEPs) | `autorunsc` | [autoruns.md](references/autoruns.md) |
| Verify code signatures; find unsigned binaries; VirusTotal-by-hash; entropy | `sigcheck` | [security-and-files.md](references/security-and-files.md) |
| Extract ASCII/Unicode strings (IOCs) from a binary or dump | `strings` | [security-and-files.md](references/security-and-files.md) |
| Find/read NTFS Alternate Data Streams (hidden payloads, mark-of-the-web) | `streams` | [security-and-files.md](references/security-and-files.md) |
| Audit effective permissions on services/files/registry/processes; privesc review | `accesschk` | [security-and-files.md](references/security-and-files.md) |
| Securely wipe a file or free space | `sdelete` | [security-and-files.md](references/security-and-files.md) |
| List logon sessions and their processes | `logonsessions` | [security-and-files.md](references/security-and-files.md) |
| Run a command on one/many remote hosts; get a SYSTEM shell | `psexec` | [pstools.md](references/pstools.md) |
| Query/control services (local or remote) | `psservice` | [pstools.md](references/pstools.md) |
| Collect / filter / export Windows event logs | `psloglist` | [pstools.md](references/pstools.md) |
| See who is logged on (local + over shares), local or remote | `psloggedon` | [pstools.md](references/pstools.md) |
| Files opened remotely over SMB | `psfile` | [pstools.md](references/pstools.md) |
| Kill / SID-lookup / inventory / password-reset / reboot, remotely | `pskill` `psgetsid` `psinfo` `pspasswd` `psshutdown` | [pstools.md](references/pstools.md) |
| Map network connections to owning processes (C2/beacon hunt) | `tcpvcon` | [networking-and-system.md](references/networking-and-system.md) |
| Latency / bandwidth / TCP-port reachability testing | `psping` | [networking-and-system.md](references/networking-and-system.md) |
| WHOIS, named pipes, CPU topology, disk/NTFS/links, registry size, conversions | `whois` `pipelist` `coreinfo` `du` `contig` `junction` `findlinks` `ntfsinfo` `ru` `hex2dec` | [networking-and-system.md](references/networking-and-system.md) |
| Delete/move a locked file at next boot | `movefile` / `pendmoves` | [networking-and-system.md](references/networking-and-system.md) |
| Deploy/configure endpoint telemetry; query Sysmon events | `sysmon` | [sysmon.md](references/sysmon.md) |
| **A multi-step IR / malware-triage / hunting / privesc task** | a chain of the above | [dfir-workflows.md](references/dfir-workflows.md) ← start here |
| **I just need the one-liner** | — | [cheatsheet.md](references/cheatsheet.md) |

## How the references are organized

- **[cheatsheet.md](references/cheatsheet.md)** — the fastest path. A dense, goal-indexed table of copy-paste commands for every CLI tool. Start here when you already know what you want.
- **[dfir-workflows.md](references/dfir-workflows.md)** — chained, real-world playbooks (live triage, memory capture, C2 mapping, persistence sweep, malware file triage, unsigned-DLL hunt, PsExec abuse forensics, accesschk privesc, Sysmon detections) with evidence-handling rules and the forensic artifacts/Event IDs defenders watch for. Start here for anything investigative or multi-step.
- **Per-category tool references** — synopsis, the CLI/security-relevant flags, and worked examples for each tool:
  - [pstools.md](references/pstools.md) — remote exec & admin (PsExec, PsList, PsService, PsLogList, PsLoggedOn, PsFile, PsGetSid, PsInfo, PsPasswd, PsShutdown, PsSuspend, PsKill).
  - [process-and-memory.md](references/process-and-memory.md) — ProcDump, Handle, ListDLLs, VMMap, RAMMap, Procmon/Procexp CLI, LiveKd.
  - [security-and-files.md](references/security-and-files.md) — Sigcheck, Strings, Streams, AccessChk, SDelete, LogonSessions, EfsDump.
  - [autoruns.md](references/autoruns.md) — Autorunsc persistence enumeration + the `-a` category codes.
  - [sysmon.md](references/sysmon.md) — install/config/uninstall, the full Event ID table, community configs, and querying.
  - [networking-and-system.md](references/networking-and-system.md) — tcpvcon, psping, whois, coreinfo, pipelist, du, contig, junction, findlinks, ntfsinfo, ru, sync, movefile/pendmoves, hex2dec, volumeid, diskext, clockres.
- **[ms-docs/](references/ms-docs/)** — the verbatim official Microsoft Learn page for **every** Sysinternals tool (`ms-docs/<tool>.md`), including the GUI-only ones not covered above. This is the authoritative fallback: when you need a flag the category reference didn't list, or a tool that isn't in the tables, read `ms-docs/<tool>.md`. **Trust this over the summaries for exact flag spelling.**

## Helper scripts

Ready-to-run PowerShell collectors in `scripts/` that chain the tools for common jobs. Each takes a `-ToolsDir` (where the EXEs live) and writes timestamped output to an evidence folder. Read the header of each before running.

- **[host-triage.ps1](scripts/host-triage.ps1)** — one-shot live-IR snapshot: processes, unsigned DLLs, handles, network endpoints, logon sessions, autostart persistence, recent security/system events → a single evidence folder.
- **[persistence-audit.ps1](scripts/persistence-audit.ps1)** — autorunsc + sigcheck sweep focused on *unsigned / non-Microsoft* autostarts, optionally with VirusTotal.
- **[malware-file-triage.ps1](scripts/malware-file-triage.ps1)** — point at a file or folder: sigcheck (hash/signature/entropy + optional VT), streams (ADS), and strings (ASCII+Unicode, IOC grep) into a report.
