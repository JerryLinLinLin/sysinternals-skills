# Procmon command-line reference

This reference was checked against the **Process Monitor v4.04** built-in **Help > Command Line
Options...** dialog from Microsoft's signed June 17, 2026 download. The Microsoft Learn overview
describes capabilities but does not enumerate these switches. Recheck the installed version's help
before relying on a switch in long-lived automation.

Procmon documents `/`-prefixed, case-insensitive switches. Use the documented spelling below.

## Contents

- [Invocation rules](#invocation-rules)
- [Option table](#option-table)
- [Create a repeatable PMC](#create-a-repeatable-pmc)
- [Run a timed capture safely](#run-a-timed-capture-safely)
- [Export PML to CSV, XML, or PML](#export-pml-to-csv-xml-or-pml)
- [Use ring-buffer mode](#use-ring-buffer-mode)
- [Use boot logging](#use-boot-logging)
- [Avoid automation traps](#avoid-automation-traps)

## Invocation rules

- Run capture operations from an elevated Windows account.
- Use the plain installed name `procmon.exe`; a Store/winget Sysinternals install resolves it to the
  native build. Use a suffixed executable only when deliberately working from a manually extracted
  archive or opening an old 32-bit log.
- Use `/AcceptEula` only when the license has been accepted or unattended acceptance is authorized.
- Use `/Quiet` with `/LoadConfig` so a filter-confirmation dialog cannot block an unattended run.
- Prefer a local, absolute, writable PML path with ample free space. Do not place the backing file
  inside the application directory being diagnosed.
- Prefer `/Runtime` for a bounded capture. It accepts **1 through 3600 seconds** in v4.04.
- Treat `/Terminate` as machine-global Procmon coordination: the built-in help says it terminates
  **all** Procmon instances.
- Preserve the original PML. Use `/SaveAs` outputs as derivatives and verify them before replacing
  any prior artifact.

## Option table

| Option | Built-in purpose | Practical note |
| --- | --- | --- |
| `/OpenLog <PML file>` | Open a previously saved event file. | Required for command-line export. Treat supplied PML as read-only evidence. |
| `/BackingFile <PML file>` | Save captured events in the specified backing file. | Prefer this over keeping a large capture only in memory. Use a new path for each run. |
| `/NoConnect` | Do not automatically begin collecting at startup. | Useful when opening/configuring the GUI without immediately capturing. |
| `/NoFilter` | Clear the filter at startup. | Use to avoid inherited per-user filters when no explicit `.pmc` is available. |
| `/AcceptEula` | Accept the EULA automatically without a dialog. | Prevents first-run blocking, but only use when acceptance is authorized. |
| `/Profiling` | Enable thread profiling. | Generates periodic profiling events; leave off for normal I/O/configuration analysis. |
| `/PagingFile` | Save events in virtual memory. | Specialized alternative to normal storage; prefer an explicit backing file for reproducible work. |
| `/Minimized` | Start Procmon minimized. | Pair with `/Quiet` for an unobtrusive attended or lab capture. |
| `/Terminate` | Terminate all Procmon instances and exit. | Never use blindly on a shared host or while another capture may be active. |
| `/Quiet` | Do not confirm filter settings during startup. | Essential with `/LoadConfig` in unattended automation. |
| `/Run32` | Run the 32-bit version to load 32-bit log files on x64. | Use only for a log that requires it; native capture should use the native build. |
| `/WaitForIdle` | Wait for a Procmon instance to become ready. | Invoke after starting capture and before starting the reproduction. |
| `/HookRegistry` | Hook Registry for legacy SoftGrid troubleshooting on x86 Vista. | Legacy-only; do not use for current general troubleshooting. |
| `/SaveAs <path>` | Export the opened log to XML, CSV, or PML. | Valid only with `/OpenLog`; the destination extension selects the format. |
| `/SaveAs1 <XML path>` | Export XML including stack traces. | Use when stack addresses are required outside PML. |
| `/SaveAs2 <XML path>` | Export XML including stack traces with symbols. | Slower and dependent on configured symbol resolution. |
| `/LoadConfig <PMC file>` | Load a previously saved configuration. | Use a checked-in/case-specific `.pmc` for repeatable categories, filters, and columns. |
| `/SaveApplyFilter` | Apply the current filter while exporting. | Valid only with a save option. Omit it when creating an all-events derivative. |
| `/EnableBootLogging` | Configure logging of the next boot. | Requires a reboot and explicit authorization; record that boot logging was enabled. |
| `/ConvertBootLog <PML file>` | Process the boot log after reboot into the named PML. | Convert promptly and verify the output before changing boot-log state again. |
| `/Runtime <seconds>` | Capture for the specified seconds, then terminate. | v4.04 validates the range as 1–3600 seconds. Prefer this to a later global `/Terminate`. |
| `/RingBuffer` | Enable flight-recorder mode. | Retains a rolling interval rather than unbounded history. Validate retention on a test run. |
| `/RingBufferSize <MB>` | Set ring-buffer size in megabytes. | Choose from event rate, available disk/memory, and required look-back window. |
| `/RingBufferLen <minutes>` | Set ring-buffer length in minutes. | Time-based retention; verify that the resulting event volume fits the host. |
| `/Altitude <number>` | Set the driver's numeric altitude. | Specialist driver-conflict option; do not change it without a documented requirement. |

Do not rely on hidden strings or undocumented switches found in the executable. Use only the
built-in command-line help for the installed build.

## Create a repeatable PMC

1. Open Procmon interactively as Administrator.
2. Stop and clear capture.
3. Configure event categories, filters, columns, backing/ring settings, and symbol settings required
   for the scenario. Leave **Drop Filtered Events** off while validating.
4. Run a short test reproduction and verify that the target plus every helper process is visible.
5. Use **File > Export Configuration...** and save a case-specific `.pmc`.
6. Re-import the `.pmc` once to prove it is self-contained. Record the Procmon version used to
   create it.

A `.pmc` can carry more than filter rules. Review it after Procmon upgrades and do not assume that a
configuration exported under one Windows/user context is universally appropriate.

## Run a timed capture safely

For simple paths without spaces, this is the compact form:

```powershell
procmon.exe /AcceptEula /Quiet /Minimized `
    /LoadConfig C:\ProcmonCaptures\AppStartup.pmc `
    /BackingFile C:\ProcmonCaptures\Run-001.pml `
    /Runtime 45

procmon.exe /WaitForIdle
& 'C:\Program Files\Contoso\App.exe' '--reproduce-startup'
```

For arbitrary paths, start Procmon with a real argv list instead of building a quoted command
string. This PowerShell 7 pattern preserves spaces and punctuation:

```powershell
$procmon = (Get-Command -Name 'procmon.exe' -CommandType Application -ErrorAction Stop).Source
$captureArgs = @(
    '/AcceptEula'
    '/Quiet'
    '/Minimized'
    '/LoadConfig'
    'C:\Cases\App startup\AppStartup.pmc'
    '/BackingFile'
    'C:\Cases\App startup\Run-001.pml'
    '/Runtime'
    '45'
)

$startInfo = [Diagnostics.ProcessStartInfo]::new()
$startInfo.FileName = $procmon
$startInfo.UseShellExecute = $false
foreach ($argument in $captureArgs) {
    $null = $startInfo.ArgumentList.Add($argument)
}
$captureLauncher = [Diagnostics.Process]::Start($startInfo)
if ($null -eq $captureLauncher) {
    throw 'Procmon did not start.'
}

& $procmon '/WaitForIdle'
if ($LASTEXITCODE -ne 0) {
    throw "Procmon /WaitForIdle failed with exit code $LASTEXITCODE"
}

& 'C:\Program Files\Contoso\App.exe' '--reproduce-startup'
```

After the bounded runtime, verify the PML exists, has nonzero length, and opens successfully. The
initial launcher process can hand off to a native-architecture child, so do not use only the
launcher PID's exit as proof that capture completed.

## Export PML to CSV, XML, or PML

Export all captured events to CSV:

```powershell
procmon.exe /OpenLog C:\ProcmonCaptures\Run-001.pml `
    /SaveAs C:\ProcmonCaptures\Run-001-all.csv /Quiet
```

Apply a known `.pmc` filter during export:

```powershell
procmon.exe /OpenLog C:\ProcmonCaptures\Run-001.pml `
    /LoadConfig C:\ProcmonCaptures\AppStartup.pmc `
    /SaveAs C:\ProcmonCaptures\Run-001-filtered.csv `
    /SaveApplyFilter /Quiet
```

Export XML with raw stack frames or symbolized stack frames:

```powershell
procmon.exe /OpenLog C:\ProcmonCaptures\Run-001.pml `
    /SaveAs1 C:\ProcmonCaptures\Run-001-stacks.xml /Quiet

procmon.exe /OpenLog C:\ProcmonCaptures\Run-001.pml `
    /SaveAs2 C:\ProcmonCaptures\Run-001-symbols.xml /Quiet
```

Use `/SaveAs2` only when symbol configuration and network/cache behavior are controlled. It can be
substantially slower. After every export, wait for completion and check the output exists, is
nonempty, and contains the expected columns/events.

## Use ring-buffer mode

Use a ring buffer when the symptom is intermittent and only the lead-up matters. Start with a test
size and a bounded runtime:

```powershell
procmon.exe /AcceptEula /Quiet /Minimized `
    /LoadConfig C:\ProcmonCaptures\Intermittent.pmc `
    /BackingFile C:\ProcmonCaptures\Rolling.pml `
    /RingBuffer /RingBufferSize 512 /Runtime 3600
```

Alternatively choose `/RingBufferLen <minutes>` for a time-based look-back. Measure actual event
rate on the target host; a nominal duration does not guarantee the same retained detail across
different workloads. Record the symptom time externally so the retained window can be aligned.

## Use boot logging

Boot logging is disruptive and persistent across the next reboot. Use it only when a normal capture
cannot observe the failure.

```powershell
# Enable only after the user authorizes the reboot workflow.
procmon.exe /AcceptEula /EnableBootLogging

# After the authorized reboot and reproduction:
procmon.exe /AcceptEula /ConvertBootLog C:\ProcmonCaptures\Boot.pml /Quiet
```

Verify the converted PML before cleanup or another boot-log attempt. Record the boot time, login
time, and reproduction marker so the large trace can be narrowed accurately.

## Avoid automation traps

- Do not start the target until `/WaitForIdle` returns successfully.
- Do not reuse a PML filename; a stale file can be mistaken for a new capture.
- Do not inherit an unknown GUI filter. Load a known `.pmc` or use `/NoFilter`.
- Do not enable **Drop Filtered Events** merely to reduce noise. First prove the process tree and
  filter on a short run.
- Do not call `/Terminate` without checking for all Procmon instances and coordinating with their
  owners.
- Do not parse PML directly. Export to CSV/XML with Procmon and retain the PML.
- Do not assume a CSV contains stacks or every rich process property.
- Do not infer completion from process launch alone. Verify output artifacts and, for export, open or
  parse the result.
- Do not treat Procmon's periodic profiling events as application I/O.
- Do not run long unfiltered in-memory captures; use backing or ring-buffer storage and a bounded
  window.
