# Procmon behavior-analysis cheatsheet

Use this reference after reading the operating rules in `../SKILL.md`. Operation names and fields
can vary slightly by Windows and Procmon version; verify unfamiliar values in the event's `Detail`
and in the current Procmon UI.

## Contents

- [Build filters correctly](#build-filters-correctly)
- [Route by troubleshooting question](#route-by-troubleshooting-question)
- [Read the operation, path, result, and detail together](#read-the-operation-path-result-and-detail-together)
- [Interpret common results](#interpret-common-results)
- [Reconstruct a causal sequence](#reconstruct-a-causal-sequence)
- [Use stacks for attribution](#use-stacks-for-attribution)
- [Triage an exported CSV](#triage-an-exported-csv)
- [Compare a working and failing run](#compare-a-working-and-failing-run)
- [Report the finding](#report-the-finding)

## Build filters correctly

- Start with one target PID. Add descendant PIDs after checking **Tools > Process Tree**.
- Use multiple include rules on the same field to express alternatives. Procmon ORs rules that
  reference the same field and ANDs include rules across different fields. An exclude rule removes a
  matching event, so inspect the full filter list when an expected event disappears.
- Prefer `is` for a PID, process, operation, or exact result; `begins with` for a directory or
  Registry subtree; and `ends with` for a known extension. Use `contains` only when necessary.
- Filter the displayed view first. Do not enable **Drop Filtered Events** until a test reproduction
  proves that the filter retains the target and every helper process.
- Keep `Result` out of the initial include filter. A success immediately before or after a failure
  often explains the fallback behavior.
- Use **Reset Filter** or `/NoFilter` when inherited per-user state is uncertain. For automation,
  import/export a known `.pmc` and load it explicitly.
- Disable profiling events unless investigating CPU samples. `Process Profiling` and
  `Thread Profiling` are periodic samples, not proof that an application performed I/O.

## Route by troubleshooting question

| Question | First diagnostic view | What constitutes useful evidence |
| --- | --- | --- |
| Why does the app fail to launch? | Target plus children; process/thread, image, file, and Registry categories | Process start/command line, final dependency or configuration attempt, fallback or lack of fallback, then exit status |
| Which configuration source wins? | Target PID; `Path` begins with likely app/user/machine config roots; `ReadFile`, `RegQueryValue`, `RegEnumValue` | Ordered probes ending in the successful read whose data governs the observed behavior |
| Is a file or DLL missing? | `Load Image` plus file operations; `Path` ends with the name or `.dll` | The complete loader search sequence and whether a later candidate succeeds; a lone `NAME NOT FOUND` is not enough |
| Is this a permissions problem? | Target tree; then highlight `Result is ACCESS DENIED` | User/integrity context, requested access in `Detail`, denied object, retries, and whether a less-privileged access later succeeds |
| What did the app write or delete? | Target tree; `WriteFile`, `RegSetValue`, `RegDeleteValue`, `RegCreateKey`, `RegDeleteKey`, and `Set*InformationFile` | Open disposition/access followed by write, rename, truncate, or disposition/delete events on the same object |
| What child process or command was launched? | Process/thread category; `Process Create` and `Process Start`; Process Tree | Parent/child relationship, image, full command line, user/session, and child exit |
| Why is startup slow? | Target tree; add `Duration`; File/Registry/Network summaries | A repeatable long operation or wait near the critical path, followed by stack attribution or a controlled comparison |
| What did an installer/updater change? | Installer launcher plus `msiexec.exe`, service helpers, and descendants; file/Registry/process categories | Writes under installation/config/service roots, process handoffs, rollback activity, and final exit status |
| Why does a service behave differently? | Service PID and helpers; add `User`, `Session`, `Command Line`, and working paths | Differences in identity, profile/Registry hive, current directory, environment-dependent paths, or access results |
| Which endpoint did the app contact? | Procmon v4 network category; target tree; TCP/UDP connect/send/receive operations | Process-to-endpoint metadata and ordering relative to config/I/O; use a packet tool for payloads or protocol diagnosis |
| What happens before logon? | Boot logging, then narrow the converted PML by process/path/time | Early process, driver, file, and Registry sequence; obtain reboot authorization before enabling it |
| What precedes an intermittent symptom? | Backing file plus ring-buffer/flight-recorder mode | The retained interval immediately before the observed trigger, with a recorded wall-clock marker |

For a known path but unknown process, omit the process include temporarily and use `Path begins with`
the narrowest safe root. Once the responsible PID is found, switch back to a process-tree view.

## Read the operation, path, result, and detail together

| Operation family | Meaning and interpretation |
| --- | --- |
| `CreateFile` | Opens **or** creates a file/directory. Inspect `Desired Access`, `Disposition`, `Options`, `ShareMode`, and `OpenResult`; do not infer creation from the operation name. |
| `ReadFile` / `WriteFile` | Reads/writes a byte range. Correlate offset/length and the preceding open. A successful open alone does not prove content was consumed. |
| `QueryDirectory` | Enumerates directory entries. Repeated wildcard probes and a terminating `NO MORE FILES` are normal. |
| `SetRenameInformationFile`, `SetDispositionInformationFile`, other `Set*InformationFile` | Renames, marks for deletion, truncates, changes allocation, timestamps, or attributes. Confirm the specific information class and target in `Detail`. |
| `Cleanup` / `CloseFile` | Ends handle use. Treat these as lifecycle events, not deletion evidence. |
| `RegOpenKey` / `RegCreateKey` | Opens or creates a Registry key. Inspect the result and follow-on value operations. |
| `RegQueryValue` / `RegEnumValue` / `RegEnumKey` | Reads or enumerates configuration. Missing optional values and enumeration termination are common. |
| `RegSetValue`, `RegDeleteValue`, `RegDeleteKey` | Mutates Registry configuration. Record value name/type/data from `Detail` when available. |
| `Process Create` / `Process Start` | Establishes parent, child, image, command line, user/session, and architecture. Use the process tree to avoid missing helpers. |
| `Process Exit` | Ends a process. Inspect exit status, but do not assume a nonzero code's meaning without the application's contract. |
| `Thread Create` / `Thread Exit` | Shows thread lifetime. Usually supporting context; use thread ID and stacks when a particular caller matters. |
| `Load Image` | Maps an executable, DLL, or other image. Pair with preceding file probes to understand loader search behavior. |
| `TCP *` / `UDP *` | Shows endpoint and transfer metadata in Procmon v4. It is not packet capture and does not reveal application payloads. |
| `Process Profiling` / `Thread Profiling` | Periodic CPU/stack samples generated when profiling is enabled. Do not mistake them for file, Registry, or network behavior. |

## Interpret common results

| Result | Default interpretation | Escalate when |
| --- | --- | --- |
| `SUCCESS` | The requested operation completed. | The returned data/path is wrong, the duration is abnormal, or a later event rejects the result. |
| `NAME NOT FOUND` | One candidate name/value was absent; probing is common. | It is the final required candidate, there is no successful fallback, or it differs from a working run. |
| `PATH NOT FOUND` | A parent component was absent. | The path is required and the application does not create/fall back to another location. |
| `ACCESS DENIED` | Requested access was rejected; sometimes an intentional privilege probe. | The same required operation has no reduced-access retry or the denial directly precedes failure. Inspect `Desired Access` and identity. |
| `BUFFER OVERFLOW` | The caller's buffer was too small and may be retried after learning the required size. | No successful retry follows or the application mishandles the returned length. It does not mean Procmon lost events. |
| `REPARSE` | Windows encountered a reparse point and will resolve/redrive the request. | Resolution redirects to an unintended location or the subsequent operation fails. |
| `NO MORE FILES` / `NO MORE ENTRIES` | Normal end of enumeration. | The application expected an entry that never appeared earlier in the enumeration. |
| `END OF FILE` | Read reached the end of available data. | It occurs earlier than expected or after an incorrect size/offset calculation. |
| `SHARING VIOLATION` / `LOCK NOT GRANTED` | Another handle or lock conflicts with the request. | Retries are exhausted or this is the last event before the symptom; identify the owner with Handle/Process Explorer if needed. |
| `DELETE PENDING` | An object is already marked for deletion. | A required open/write cannot proceed and no retry follows after handles close. |
| `FAST IO DISALLOWED` | The fast path was declined; Windows normally retries through the regular I/O path. | The normal retry is absent or fails. Do not treat this result alone as an application error. |
| `NOT SUPPORTED` / `INVALID DEVICE REQUEST` | That object/provider does not implement the requested operation. | The application requires the feature and has no fallback. |
| `CANCELLED` | An operation was cancelled by the caller, I/O manager, timeout, or teardown. | Cancellation explains the visible failure and can be tied to a caller/timeout with adjacent events or a stack. |

Treat result coloring as navigation, not diagnosis. Always inspect at least several events before and
after a candidate and check the same sequence in a known-good run when one is available.

## Reconstruct a causal sequence

1. Anchor on `Process Start`, the user's action, a bookmark, or an external timestamp.
2. Follow one PID and, when useful, one thread ID in `Sequence` or `Relative Time` order.
3. Identify the final successful setup step before the behavior diverges.
4. Follow probes through their fallback chain. Record both unsuccessful candidates and the candidate
   that ultimately succeeds—or prove that none does.
5. Correlate an open with later reads/writes and close/cleanup on the same path.
6. Correlate parent process creation with child activity and exit. Do not assign a child's I/O to the
   launcher merely because their names or timestamps are close.
7. Use File, Registry, Process Activity, Stack, and Network summaries to locate concentrations, then
   return to the event list to prove chronological ordering.
8. Test the hypothesis by changing one input—file presence, ACL, configuration value, working
   directory, identity, or endpoint—and repeating the same short capture.

The last event before exit is a lead, not automatically the cause. Buffered logging, asynchronous
threads, exception handling, and process teardown can all produce misleading final events.

## Use stacks for attribution

Open an event's properties and inspect **Stack** when the operation is known but the responsible code
is not. Configure symbols under **Options > Configure Symbols...**. A common public-symbol path is:

```text
srv*C:\Symbols*https://msdl.microsoft.com/download/symbols
```

Prefer the first meaningful application or third-party module above Windows plumbing. Record whether
symbols resolved and retain the PML; CSV does not preserve the full stack. For automated export,
`/SaveAs1` includes stack addresses in XML and `/SaveAs2` also resolves symbols, which is slower and
depends on symbol availability. A stack attributes the caller of an operation; it does not by itself
prove that the operation caused the symptom.

## Triage an exported CSV

Export from PML first, then inspect the actual column names because configured columns can differ:

```powershell
$events = @(Import-Csv -LiteralPath 'C:\ProcmonCaptures\Run-filtered.csv')
$events[0].PSObject.Properties.Name
```

Count results and operation/result combinations before narrowing:

```powershell
$events |
    Group-Object -Property Result |
    Sort-Object -Property Count -Descending |
    Select-Object -Property Count, Name

$events |
    Group-Object -Property Operation, Result |
    Sort-Object -Property Count -Descending |
    Select-Object -First 40 -Property Count, Name
```

Show a compact target timeline:

```powershell
$events |
    Where-Object { $_.'Process Name' -eq 'app.exe' } |
    Select-Object -Property 'Time of Day', Sequence, 'Process Name', PID, Operation, Path, Result, Detail
```

Inspect access denials without assuming every denial is causal:

```powershell
$events |
    Where-Object { $_.Result -eq 'ACCESS DENIED' } |
    Select-Object -Property 'Time of Day', 'Process Name', PID, Operation, Path, Detail
```

Find likely mutations:

```powershell
$writeOperations = @(
    'WriteFile', 'RegSetValue', 'RegDeleteValue', 'RegCreateKey', 'RegDeleteKey'
)
$events |
    Where-Object {
        $_.Operation -in $writeOperations -or $_.Operation -match '^Set.*InformationFile$'
    } |
    Select-Object -Property 'Time of Day', 'Process Name', PID, Operation, Path, Result, Detail
```

Find process creation and the longest exported operations:

```powershell
$events |
    Where-Object { $_.Operation -in @('Process Create', 'Process Start', 'Process Exit') } |
    Select-Object -Property 'Time of Day', 'Process Name', PID, Operation, Path, Result, Detail

$events |
    Where-Object { -not [string]::IsNullOrWhiteSpace($_.Duration) } |
    Sort-Object {
        [double]::Parse($_.Duration, [Globalization.CultureInfo]::InvariantCulture)
    } -Descending |
    Select-Object -First 30 -Property Duration, 'Process Name', PID, Operation, Path, Result
```

Do not pipe formatted tables into CSV/JSON analysis. Preserve objects until the final display or
export boundary.

## Compare a working and failing run

Capture both runs with the same Procmon version, `.pmc`, duration policy, application build,
arguments, working directory, user/integrity, and warmed/cold-cache assumptions. Record unavoidable
differences.

1. Preserve both raw PML files.
2. Export both with the same `/LoadConfig` and `/SaveApplyFilter` settings.
3. Remove volatile columns such as absolute timestamps and PIDs only in derived comparison data.
4. Compare process trees first, then ordered event sequences for the relevant process/path.
5. Aggregate by `Process Name`, `Operation`, `Path`, and `Result` to find large differences, but use
   the original timelines to identify the first meaningful divergence.
6. Verify that the suspected difference is not cache state, first-run initialization, antivirus,
   search-order probing, or a helper process excluded by the filter.

Do not diff entire raw CSV rows and call every difference meaningful. Procmon traces contain timing,
PID, thread, cache, and environment noise even when behavior is functionally identical.

## Report the finding

Use this compact structure:

```text
Question/reproduction:
Execution context:
Capture: Procmon version, interval, categories, filters, drop-filtered state, artifact paths

Observed sequence:
1. <time/sequence> <process:pid> <operation> <path> <result> <decisive detail>
2. ...

Conclusion:
- Proven by the trace:
- Inferred, with reason:
- Ruled out / benign results:
- Remaining uncertainty:

Next smallest test or next tool:
```

State a behavior-level conclusion such as “the elevated helper reads the machine-wide value and
never queries the user's value” or “the final DLL candidate is denied execute access and no later
load succeeds,” not merely “Procmon shows failures.”
