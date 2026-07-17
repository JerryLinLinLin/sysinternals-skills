# Process, Memory & Crash-Dump CLI

> Tools for inspecting running processes, their loaded modules and handles, and capturing memory/crash dumps. This is the core of live malware triage and incident response. Authoritative per-tool docs (full flag tables) live in `references/ms-docs/<tool>.md`.

## ProcDump (`procdump`)
**Purpose:** Monitor a process and capture configurable crash/memory dumps on CPU spikes, exceptions, hangs, performance-counter thresholds, or termination.
**Privilege / EULA:** Run elevated (admin) to dump processes you don't own / system processes. Suppress the first-run EULA for automation with `-accepteula`. No `-nobanner`; pass `-accepteula` once non-interactively to avoid the dialog hang.
**Synopsis:**
```text
procdump.exe [-mm] [-ma] [-mt] [-mp] [-mc <Mask>] [-md <Callback_DLL>] [-mk]
            [-n <Count>]
            [-s <Seconds>]
            [-c|-cl <CPU_Usage> [-u]]
            [-m|-ml <Commit_Usage>]
            [-p|-pl <Counter> <Threshold>]
            [-h]
            [-e [1] [-g] [-b] [-ld] [-ud] [-ct] [-et]]
            [-l]
            [-t]
            [-f  <Include_Filter>, ...]
            [-fx <Exclude_Filter>, ...]
            [-dc <Comment>]
            [-o]
            [-r [1..5] [-a]]
            [-at <Timeout>]
            [-wer]
            [-64]
            {
                {{[-w] <Process_Name> | <Service_Name> | <PID>} [<Dump_File> | <Dump_Folder>]}
            |
                {-x <Dump_Folder> <Image_File> [Argument, ...]}
            }
procdump.exe -i [Dump_Folder] [-mm|-ma|-mt|-mp|-mc <Mask>|-md <DLL>|-mk] [-r] [-at <Timeout>] [-k] [-wer]
procdump.exe -u
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-ma` | Full dump (all memory + metadata). |
| `-mp` | MiniPlus dump (private + R/W image/mapped; ~10-75% of full size). |
| `-mt` | Triage dump (stacks + limited metadata; attempts to strip sensitive data). |
| `-mk` | Also write a kernel dump (thread kernel stacks). |
| `-e [1]` | Dump on unhandled exception; add `1` for first-chance too. |
| `-h` | Dump when the process has a hung window (>5s unresponsive). |
| `-c` / `-cl` | Dump when CPU is above / below threshold (`-u` = relative to one core). |
| `-m` / `-ml` | Dump when commit (MB) rises above / drops below threshold. |
| `-p` / `-pl` | Dump when a perf counter is at/above / below a threshold. |
| `-t` | Dump on process termination. |
| `-n <Count>` | Number of dumps before exiting. |
| `-s <Seconds>` | Consecutive seconds the condition must hold (default 10). |
| `-f` / `-fx` | Include / exclude filter (exception text, debug log, DLL name; wildcards). |
| `-l` | Display the target's debug-string output (use with `-f` to filter). |
| `-w` | Wait for a not-yet-running process to launch. |
| `-x <Folder> <Image> [args]` | Launch image and monitor it (Store apps supported). |
| `-r [1..5]` | Dump via a clone (PSS/reflection) to minimize outage; optional concurrency. |
| `-o` | Overwrite an existing dump file. |
| `-i [Folder]` / `-u` | Install / uninstall ProcDump as the AeDebug postmortem debugger. |
| `-cancel <PID>` | Gracefully stop all ProcDump instances monitoring that PID. |
**Examples:**
```cmd
# Full dump on 2nd-chance unhandled exception (classic crash capture)
procdump -accepteula -ma -e w3wp.exe c:\dumps

# Capture 3 full dumps, 5s apart, when a process pegs CPU >80% (suspected miner)
procdump -accepteula -ma -n 3 -s 5 -c 80 suspicious.exe c:\dumps

# Full dump immediately on a hung window, plus kernel stacks
procdump -accepteula -ma -mk -h hang.exe c:\dumps

# Dump on first- OR second-chance exception whose text contains "NotFound"
procdump -accepteula -ma -n 10 -e 1 -f NotFound w3wp.exe

# Install ProcDump as the system postmortem (AeDebug) debugger, full dumps to c:\dumps
procdump -accepteula -ma -i c:\dumps

# Live-launch and monitor a sample for exceptions, low-outage clone capture
procdump -accepteula -e -r -ma -x c:\dumps sample.exe
```
**Output / parsing:** Dumps default to `PROCESSNAME_YYMMDD_HHMMSS.dmp`; substitutions `PROCESSNAME`, `PID`, `EXCEPTIONCODE`, `YYMMDD`, `HHMMSS` let you template the filename/folder for scripted collection. `-dc <Comment>` embeds a comment in the dump. Exit/termination is graceful via `-cancel <PID>` or an event named `ProcDump-<PID>`, so wrapper scripts can stop monitoring cleanly. `-wer` queues the dump to Windows Error Reporting.
**Full reference:** `references/ms-docs/procdump.md`

## Handle (`handle`)
**Purpose:** List open handles (files, registry keys, sections, processes, threads, etc.) system-wide or per process; find which process holds a named object; close handles.
**Privilege / EULA:** Requires administrative privilege. Suppress the first-run EULA with `-accepteula` (not in the flag table but accepted by all Sysinternals tools); essential for non-interactive runs. No banner-suppression flag.
**Synopsis:**
```text
handle [[-a [-l]] [-v|-vt] [-u] | [-c <handle> [-y]] | [-s]] [-p <process>|<pid>] [name]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-a` | Dump all handle types, not just files (ports, keys, threads, processes, etc.). |
| `-l` | Show only pagefile-backed section handles. |
| `-s` | Print a count of each handle type open. |
| `-u` | Show the owning user name. |
| `-g` | Print granted access. |
| `-p <proc|pid>` | Limit scan to processes whose name starts with `proc`, or a PID. |
| `-c <handle> [-y]` | Close the given hex handle in the `-p` PID (`-y` = no confirm). |
| `-v` | CSV output, comma-delimited. |
| `-vt` | CSV output, tab-delimited. |
| `name` | Search: which process holds a handle to an object matching this name fragment (case-insensitive). |
**Examples:**
```cmd
# Find which process has a locked/held file open (search by path fragment)
handle -accepteula -u C:\Users\victim\report.docx

# Dump all handle types for a suspect process, with owning user
handle -accepteula -a -u -p malware.exe

# Machine-readable CSV of all handles for parsing/IR tooling
handle -accepteula -a -v > handles.csv

# Summarize handle counts by type for a PID (handle-leak / injection hunting)
handle -accepteula -s -p 4321

# Force-close a leaked/locking handle (hex value) in a PID without prompting
handle -accepteula -c 0x1A4 -p 4321 -y
```
**Output / parsing:** `-v` (comma) and `-vt` (tab) produce CSV for scripting. `-s` gives per-type counts. Default text output groups handles per process under a dashed separator; in name-search mode it prints `process  pid  :  object` rows.
**Full reference:** `references/ms-docs/handle.md`

## ListDLLs (`listdlls`)
**Purpose:** List DLLs/modules loaded into processes, with version and code-signing info; reverse-lookup which processes loaded a given DLL; flag relocated or unsigned modules.
**Privilege / EULA:** Run elevated to inspect other users' / system processes. Suppress the first-run EULA with `-accepteula` for automation. No banner-suppression flag.
**Synopsis:**
```text
listdlls [-r] [-v | -u] [processname|pid]
listdlls [-r] [-v] [-d dllname]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-r` | Flag DLLs that relocated (not loaded at their base address). |
| `-u` | List only unsigned DLLs. |
| `-v` | Show DLL version info (includes digital signature). |
| `-d <dllname>` | Show only processes that have loaded the named DLL. |
| `processname` | Dump DLLs for matching process (partial name accepted). |
| `pid` | Dump DLLs for the given PID. |
**Examples:**
```cmd
# Hunt unsigned DLLs across every process (injected / sideloaded module triage)
listdlls -accepteula -u

# Find every process that loaded a suspicious DLL (sideloading / hijack hunt)
listdlls -accepteula -d evil.dll

# Full module + version + signature listing for one suspect process
listdlls -accepteula -v malware.exe

# Flag relocated DLLs in a PID (possible base-address conflict / injection)
listdlls -accepteula -r 4321
```
**Output / parsing:** Plain text only (no CSV). Combine `-u` (unsigned) with a process/PID to scope the scan; `-d` does the reverse DLL-to-process lookup that is central to DLL-sideloading investigations.
**Full reference:** `references/ms-docs/listdlls.md`

## VMMap (`vmmap`)
**Purpose:** Analyze a process's virtual and physical (working-set) memory layout by region type; primarily a GUI, with documented command-line options for scripted snapshot/export.
**Privilege / EULA:** Run elevated to analyze processes you don't own. Suppress the first-run EULA with `-accepteula`. The published doc describes the GUI; specific command-line export flags are not enumerated in it.
**Synopsis:**
```text
vmmap [-accepteula] <process>   (GUI; command-line/export options enable scripting per docs)
```
**Key flags:** The source doc states VMMap "includes command-line options that enable scripting scenarios" and native export/reload, but does not list the individual flags. Use `-accepteula` to avoid the EULA prompt; see the GUI Help / full reference for the export switches before scripting.
**Examples:**
```cmd
# Launch VMMap against a live process for memory-layout / leak analysis
vmmap -accepteula suspicious.exe
```
**Output / parsing:** Supports exporting data in multiple forms including a native format that can be reloaded, plus CSV/text export from the GUI; consult the help file for the exact command-line export switches (not enumerated in the published doc).
**Full reference:** `references/ms-docs/vmmap.md`

## RAMMap (`rammap`)
**Purpose:** Analyze how Windows is using physical RAM (use counts, standby/cache, per-process working sets, file data in RAM).
**Privilege / EULA:** GUI-only — no meaningful CLI; listed for completeness. Run elevated; `-accepteula` suppresses the first-run EULA if launched non-interactively. RAMMap is driven through its tabs (Use Counts, Processes, Physical Pages, File Summary, etc.) and supports saving/loading snapshots from the GUI.
**Full reference:** `references/ms-docs/rammap.md`

## Process Monitor (`procmon`)
**Purpose:** Real-time capture of file system, registry, process/thread and DLL activity; the workhorse for behavioral malware triage. Supports unattended/boot-time capture from the command line.
**Privilege / EULA:** Requires admin (loads a kernel driver). Suppress the first-run EULA with `/accepteula`. Procmon uses `/`-style switches; the published doc does not enumerate the CLI flags, so confirm switch names against the in-app Help / full reference before scripting.
**Synopsis:**
```text
procmon /accepteula [/Quiet] [/Minimized] [/BackingFile <path.pml>]
        [/LoadConfig <cfg.pmc>] [/Runtime <seconds>] [/Terminate]
procmon /OpenLog <path.pml> /SaveAs <out.csv> [/Quiet /Minimized]   (headless .PML -> .CSV)
        (consult in-app Help for the authoritative switch list)
```
**Key flags:** The published doc covers capabilities (non-destructive filters, full thread stacks, scalable logging to `.PML`, boot-time logging) but does not include a CLI flag table. Switches used for automation (all verified working): `/accepteula` (suppress EULA), `/Quiet`, `/Minimized`, `/BackingFile <pml>` (log target), `/LoadConfig <pmc>` (apply saved filters), `/Runtime <sec>` (auto-stop after N seconds), `/Terminate` (signal a running instance to stop), `/OpenLog <pml>` (open a saved log), `/SaveAs <csv|xml>` (export the loaded log — the headless equivalent of GUI File>Save). Launch the capture non-blocking (e.g. `Start-Process`) since the procmon process keeps running while it captures; stop it with `/Runtime` or a follow-up `/Terminate`.
**Examples:**
```cmd
# Headless timed capture to a backing file, pre-loaded filter config (sandbox detonation)
procmon /accepteula /Quiet /Minimized /LoadConfig triage.pmc /BackingFile C:\ir\run.pml /Runtime 60

# Start a logging-only capture to a fixed PML file
procmon /accepteula /Quiet /Minimized /BackingFile C:\ir\capture.pml

# Stop the running capture cleanly so the PML can be collected
procmon /Terminate

# Convert the captured .PML to CSV WITHOUT the GUI, then parse the CSV (essential for headless use)
procmon /OpenLog C:\ir\run.pml /SaveAs C:\ir\run.csv /Quiet /Minimized
```
**Output / parsing:** The native `.PML` is **binary and only reopens inside Process Monitor** — so for headless/scripted analysis you must convert it: `procmon /OpenLog <pml> /SaveAs <out.csv>` (or `/SaveAs` an `.xml`) writes a parseable file with no GUI. CSV columns are `Time of Day, Process Name, PID, Operation, Path, Result, Detail`; filter by `Process Name` to scope to one process. **Gotcha:** an unfiltered capture also contains periodic **Process Profiling / Thread Profiling** events — these are Procmon's own ~1/second CPU+RAM samples of every process, *not* application I/O. Exclude them when analyzing behavior (a process that shows *only* profiling events did nothing during the window). Filters are saved as `.PMC` config files and applied with `/LoadConfig`.
**Full reference:** `references/ms-docs/procmon.md`

## Process Explorer (`procexp`)
**Purpose:** GUI "super Task Manager" showing process tree, open handles, loaded DLLs/mapped files, and handle/DLL search; the interactive counterpart to Handle and ListDLLs.
**Privilege / EULA:** Run elevated for full handle/DLL detail on other processes. Suppress the first-run EULA with `/accepteula` when launching from a script. Largely GUI-driven; the published doc documents no automation flag table beyond launching the executable.
**Synopsis:**
```text
procexp [/accepteula] [/p:<priority>] [/e] [<dump.dmp>]
        (GUI tool; consult in-app Help for the authoritative switch list)
```
**Key flags:** The published doc describes only GUI usage ("Simply run procexp.exe"). For non-interactive use, `/accepteula` suppresses the EULA dialog so a launch script won't hang. Other switches (e.g., loading a saved dump) are not enumerated in the doc — confirm via `procexp /?` before scripting.
**Examples:**
```cmd
# Launch Process Explorer non-interactively (no EULA hang) for live triage
procexp /accepteula

# Open Process Explorer against a previously saved crash dump (verify switch in-app)
procexp /accepteula C:\dumps\suspect.dmp
```
**Output / parsing:** Primarily interactive. For scripted/machine-readable handle and DLL enumeration, prefer `handle` and `listdlls` (above), which Process Explorer is the GUI equivalent of.
**Full reference:** `references/ms-docs/process-explorer.md`

## LiveKd (`livekd`)
**Purpose:** Run the Microsoft kernel debuggers (kd/WinDbg) against a live local system or Hyper-V VM, and capture consistent live kernel "mirror" dumps without taking the machine down.
**Privilege / EULA:** Requires admin; needs the Debugging Tools for Windows installed. Suppress the first-run EULA with `-accepteula`. By default LiveKd runs `kd.exe`. Use `Ctrl-Break` to terminate/restart the debugger if it hangs.
**Synopsis:**
```text
livekd [[-w]|[-k <debugger>]|[-o filename]] [-vsym] [-m[flags] [[-mp process]|[pid]]] [debugger options]
livekd [[-w]|[-k <debugger>]|[-o filename]] -ml [debugger options]
livekd [[-w]|[-k <debugger>]|[-o filename]] [[-hl]|[-hv <VM name> [[-p]|[-hvd]]]] [debugger options]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-w` | Run WinDbg instead of kd. |
| `-k <debugger>` | Full path/filename of the debugger image to launch. |
| `-o <filename>` | Save a `memory.dmp` to disk instead of launching the debugger. |
| `-m [flags]` | Create a consistent kernel mirror dump (optional region mask, default `0x18F8`). |
| `-mp <process>` | Include a single process's user-mode memory in the mirror dump (with `-m`). |
| `-ml` | Generate a live dump via native OS support (Windows 8.1+). |
| `-hv <VM>` | Debug the named/GUID Hyper-V VM. |
| `-hvl` | List names/GUIDs of running Hyper-V VMs. |
| `-hvd` | Include hypervisor pages (Windows 8.1+). |
| `-p` | Pause the target Hyper-V VM while LiveKd is active (use with `-o`). |
| `-vsym` | Verbose symbol-load diagnostics. |
**Examples:**
```cmd
# Capture a consistent live kernel mirror dump to disk (no debugger UI)
livekd -accepteula -m -o C:\dumps\livekernel.dmp

# Native live kernel dump (Windows 8.1+) saved to disk
livekd -accepteula -ml -o C:\dumps\live.dmp

# Open a live kernel debug session in WinDbg
livekd -accepteula -w

# List running Hyper-V VMs, then dump one (paused for consistency)
livekd -accepteula -hvl
livekd -accepteula -hv "GuestVM" -p -o C:\dumps\guest.dmp
```
**Output / parsing:** `-o` writes a standard `.dmp` consumable by kd/WinDbg and other dump tools; `-m`/`-ml` control how the kernel snapshot is built. All non-LiveKd switches pass through to the underlying debugger, so you can drive scripted debugger commands. RAMMap helps choose `-m` region mask bits.
**Full reference:** `references/ms-docs/livekd.md`
