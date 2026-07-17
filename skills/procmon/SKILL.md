---
name: procmon
description: >-
  Cheatsheet for Microsoft Sysinternals Process Monitor (Procmon) on Windows. Use it for general
  dynamic analysis and troubleshooting of applications, services, installers, and system activity:
  file and Registry access, process/thread and DLL activity, configuration discovery, permissions,
  unexpected writes, startup failures, slow I/O, and PML/CSV/XML captures. Covers GUI filters,
  headless capture/export, and trace interpretation. Not a malware-analysis or DFIR skill.
---

# Procmon

Use Procmon to observe what Windows software does at runtime. Keep captures narrow and base
conclusions on event sequences, not isolated failures.

## Rules

1. Run Procmon elevated for complete capture. Use `/AcceptEula` only when unattended acceptance is
   authorized.
2. Define one reproduction and record the executable, arguments, working directory, user, integrity,
   and expected behavior.
3. Filter by PID plus descendants from **Tools > Process Tree**. Do not rely on process name alone.
4. Leave **Filter > Drop Filtered Events** off until a filter is proven; ordinary display filters are
   non-destructive.
5. Write to and preserve an all-events `.pml`. Treat CSV/XML as derived analysis formats.
6. Interpret `Operation`, `Path`, `Result`, and `Detail` together. Common results such as
   `NAME NOT FOUND`, `BUFFER OVERFLOW`, `REPARSE`, and `NO MORE FILES` are often normal.
7. Prefer `/Runtime` to stop unattended captures. `/Terminate` stops every Procmon instance; boot
   logging requires an authorized reboot.
8. Use another tool for packet payloads, heap state, crash dumps, or durable historical telemetry.

For malware triage, threat hunting, or DFIR, use the sibling `sysinternals-cli` skill.

## Goal cheatsheet

| Goal | Start with |
| --- | --- |
| Launch or configuration failure | Target tree; file, Registry, process/thread, and image activity; follow probes through the final success or missing fallback |
| Missing DLL | `Load Image` plus `.dll` file probes; compare the full loader search sequence |
| Permission problem | Highlight `ACCESS DENIED`; inspect user, requested access, retries, and later successes |
| Unexpected write/delete | `WriteFile`, `RegSetValue`, `RegDelete*`, and `Set*InformationFile` |
| Child process or command | `Process Create`, `Process Start`, command line, parent, user, and exit |
| Slow startup or I/O | Add `Duration`; use summaries to find candidates, then return to the timeline and stack |
| Installer, updater, or service | Include the launcher plus `msiexec`, service helpers, and all descendants |
| Network endpoint activity | Procmon v4 TCP/UDP events; use packet capture for protocol contents |
| Working versus failing run | Match version, user, arguments, working directory, filters, and cache assumptions; find the first meaningful divergence |

## Essential controls and commands

Use **Ctrl+E** to start/stop, **Ctrl+X** to clear, **Ctrl+L** for filters, and **File > Export
Configuration...** to create a repeatable `.pmc`.

```powershell
procmon.exe /AcceptEula /Quiet /Minimized /LoadConfig C:\Cases\App.pmc /BackingFile C:\Cases\Run.pml /Runtime 30
procmon.exe /WaitForIdle
procmon.exe /OpenLog C:\Cases\Run.pml /SaveAs C:\Cases\Run.csv /Quiet
procmon.exe /OpenLog C:\Cases\Run.pml /LoadConfig C:\Cases\App.pmc /SaveAs C:\Cases\Filtered.csv /SaveApplyFilter /Quiet
```

In Procmon v4.04, `/Runtime` accepts 1–3600 seconds. Verify each output exists and is nonempty before
replacing or deleting anything.

## Reading a trace

- Treat `CreateFile` as open-or-create; inspect `Disposition`, `Desired Access`, and `ShareMode`.
- Correlate successful opens with later reads/writes and follow failed probes to their fallback.
- Confirm process identity, parent/children, command line, user, and exit before attributing activity.
- Use an event stack to identify the caller, but do not claim causality from unresolved frames.
- Report a compact causal sequence and separate what the trace proves from inference.

## References

- [cheatsheet.md](references/cheatsheet.md) — filter recipes, event/result meanings, CSV queries, and comparison guidance.
- [command-line.md](references/command-line.md) — Procmon v4.04 switches and automation details.
- [microsoft-learn-procmon.md](references/microsoft-learn-procmon.md) — copied Microsoft Learn reference.
