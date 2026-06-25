# DFIR & Threat-Hunting Playbooks with Sysinternals CLI

Real-world, chained workflows for incident response, malware triage, threat hunting, and privilege-escalation auditing — distilled from practitioner blogs (DFIR Madness, Jai Minton, Red Canary, Unit 42, TrustedSec, Synacktiv, HackTricks, Olaf Hartong, SwiftOnSecurity) and Microsoft Learn. Sources are listed at the bottom.

> **Evidence-integrity rule for live IR:** write all output to an **external drive or share (`D:\evidence\…`)**, never the suspect's own disk — you don't want to overwrite unallocated space/slack. Collect in **order of volatility**: network + process + handle state first, disk-heavy collection last. Hash your outputs. And remember: *running these tools is itself logged* (the EULA registry key, Prefetch, your `.dmp` files) — document every tool run so an analyst doesn't mistake your triage for the attacker.

---

## 1. Live host triage — process & module sweep

Goal: enumerate running processes, their loaded modules, and flag injected/unsigned code before pulling a memory image.

```cmd
:: 1. Process tree — hunt anomalous lineage (winword.exe -> cmd.exe -> powershell.exe)
pslist64 -accepteula -t
:: 2. Scope to a name and show memory/threads/handles (e.g. a fake/misplaced svchost)
pslist64 -accepteula -x svchost
:: 3. Unsigned DLLs loaded ANYWHERE — strongest single injection/sideload indicator
listdlls64 -accepteula -u
:: 4. Per-PID: version+signature, flag DLLs relocated from base (hollowing/injection)
listdlls64 -accepteula -r -v 1234
:: 5. Reverse lookup: every process that loaded a known-bad DLL
listdlls64 -accepteula -d evil.dll
:: 6. All handle types for a suspect PID — named mutexes reveal malware family; section/process handles reveal injection targets
handle64 -accepteula -a -p 1234
```

## 2. Suspicious-process memory capture (for offline analysis)

Goal: capture a full image of one suspect process without taking the box down.

```cmd
:: Identify the PID first (dump-by-name fails on multiple matches like svchost/powershell)
pslist64 -accepteula
:: FULL dump (-ma = image+mapped+private memory) to the EVIDENCE drive
procdump64 -accepteula -ma 1234 D:\evidence\susp_1234.dmp
:: To catch a transient unpacker, arm the dump BEFORE detonation:
procdump64 -accepteula -ma -w sample.exe D:\evidence
:: To catch self-terminating injectors, dump at termination:
procdump64 -accepteula -ma -t malware.exe D:\evidence
:: Then, on the ANALYST workstation (not the victim): pull IOCs from the dump
strings -accepteula -nobanner -n 8 D:\evidence\susp_1234.dmp | findstr /i "http https .onion -enc powershell"
```

**Why `-ma`:** the default minidump omits most private memory — but the *unpacked* code is exactly what lives in newly-committed private/RWX regions, so full dump is mandatory for unpacking. After dumping, carve PEs with pe-sieve/hollows_hunter or a memory-forensics framework and re-run `sigcheck`/`strings` on the recovered image.

## 3. Network-to-process mapping (find the C2 channel)

```cmd
:: All endpoints (-a includes listeners+UDP), no DNS (-n: faster, doesn't tip off attacker). Unlike netstat, tcpvcon shows the owning process+PID.
tcpvcon -accepteula -a -n
:: Same as CSV to the evidence drive for offline correlation vs threat-intel IP/domain lists
tcpvcon -accepteula -a -c -n > D:\evidence\HOST_tcp.csv
:: For the PID owning a suspicious connection, corroborate via its handles (dropped files, pipes, mutexes)
handle64 -accepteula -a -p 1234
```

## 4. Persistence / autostart capture

```cmd
:: Real DFIR command (DFIR Madness Case 001): ALL ASEPs, signatures, hashes, CSV
autorunsc64 -accepteula -a * -s -h -c > D:\evidence\autoruns-HOST.csv
:: Noise-reduced hunt: hide signed Microsoft, add VirusTotal hash lookups, clean header
autorunsc64 -accepteula -a * -c -h -s -v -m -nobanner > D:\evidence\autoruns-HOST.csv
:: Targeted: scheduled tasks only (also: l=logon s=services w=winlogon m=wmi d=appinit h=imagehijack)
autorunsc64 -accepteula -a t -c -h -nobanner > D:\evidence\schtasks.csv
:: Dead-box: scan a mounted/offline image instead of the live host
autorunsc64 -accepteula -a * -c -h -s -z E:\Windows > D:\evidence\autoruns-offline.csv
```

Triage tip: diff the CSV against a known-good baseline of the same image to surface *new* persistence. Treat a "clean" VirusTotal verdict on a low-prevalence/targeted sample with suspicion — low prevalence ≠ benign.

## 5. Account / session / logon triage

```cmd
:: Locally logged-on users + users connected via shares (\\HOST for remote)
psloggedon -accepteula
:: Active logon sessions with auth package, logon type (RemoteInteractive=RDP), SID, time; -p ties processes to a (possibly attacker) session
logonsessions -accepteula -p
:: Files opened on THIS host remotely over SMB — surfaces lateral-movement file staging
psfile -accepteula
:: Security log -> CSV one-record-per-line for grep/spreadsheet triage of 4624/4625
psloglist -accepteula -s -x security > D:\evidence\HOST_security.csv
:: Filter: System-log service installs (7045) in last 3 days — classic PsExec/persistence artifact
psloglist -accepteula -s -d 3 -i 7045 system
```

## 6. Malware file triage (signature, strings, ADS)

```cmd
:: Unsigned executables (by PE header, not extension) in System32 — official MS malware-hunt example
sigcheck64 -accepteula -u -e -s c:\windows\system32
:: Higher-yield: user profile trees where unprivileged malware drops payloads, hashed, CSV
sigcheck64 -accepteula -e -u -s -h -c c:\users > D:\evidence\unsigned_users.csv
:: Entropy check — ~7.x/8 bits/byte flags packing/encryption before you bother unpacking
sigcheck64 -accepteula -a c:\suspect\packed.exe
:: VirusTotal by HASH only (no upload): -v performs the query, -vt accepts the VT ToS non-interactively, -h prints the hashes
sigcheck64 -accepteula -vt -v -h c:\suspect\dropper.exe
:: Recursively reveal NTFS Alternate Data Streams hiding payloads / mark-of-the-web
streams -accepteula -s C:\Users\victim\Downloads
:: Read a suspected stream (cmd 'type' will NOT accept stream syntax) — capture BEFORE deleting
more < "C:\Lab\readme.txt:hidden"
```

**Air-gapped VirusTotal pattern** (victim host never touches the internet):
```cmd
:: Stage 1, on the isolated victim: hash everything to CSV (no network). Output via redirect (sigcheck has no -w flag; -o is the VT-from-CSV reader used in stage 2)
sigcheck64 -accepteula -e -s -h -c C:\Windows\System32 > C:\out.csv
:: Stage 2, on an online analyst box: -o re-reads the hashes and runs the VT lookups
sigcheck64 -accepteula -vt -o C:\out.csv > C:\VTout.csv
```

⚠️ Never use `streams -d` (deletes streams) or `sigcheck -vs` (uploads files to public VirusTotal) on a real case — the first destroys evidence, the second can leak confidential data. Use `-vt`/`-v` (hash lookup only) for reputation.

## 7. Hunt injected / sideloaded / unsigned DLLs

```cmd
:: Fastest "what doesn't belong": every unsigned DLL in any process (needs admin)
listdlls64 -accepteula -u
:: DLLs relocated from preferred base — manual-mapping / injection collision hint
listdlls64 -accepteula -r outlook
:: Full version + signature per module of a sideload-prone app — eyeball publisher mismatches
listdlls64 -accepteula -v outlook
:: Pivot once you have a suspect DLL name: which processes loaded it
listdlls64 -accepteula -d evil.dll
:: Cross-tool pivot: every process holding a handle to the suspect path (-a all types, -u owner)
handle64 -accepteula -a -u C:\ProgramData\evil
```
Detection telemetry behind this (Unit 42): **Sysmon Event ID 7 (ImageLoad)** with `Signed=false` / signature unavailable, loaded from `ProgramData`/`AppData`/user/Public paths or by `rundll32.exe`/`regsvr32.exe`. High module entropy and randomized DLL names in odd subfolders add signal.

## 8. PsExec abuse — detection & forensics

PsExec is a top lateral-movement tool. Whether you're the responder confirming attacker activity or the admin who must not be mistaken for one, know its artifacts.

**The execution pattern IR sees most:** `psexec \\target -s -d cmd /c "<command>"` — run as SYSTEM (`-s`), fire-and-forget (`-d`). Attackers rename the service with `-r` to dodge name-based detection (`psexec \\target -r mssecsvc -s cmd`).

**Forensic artifacts on the TARGET:**
| Artifact | Detail |
| -------- | ------ |
| **System 7045** | Service installed: name `PSEXESVC`, image `%SystemRoot%\PSEXESVC.exe`, account LocalSystem. Most reliable single artifact. |
| **System 7036** | SCM: `PSEXESVC` running→stopped pair bracketing the exec window. |
| **Security 4624 Type 3** | Network logon from the source host, often paired with **4672** (special/admin privileges). |
| **Security 5145** | `ADMIN$` share object checked (where PSEXESVC.exe is written). |
| **`C:\Windows\PSEXEC-<SOURCEHOST>-<8char>.key`** | v2.30+ drops this; **embeds the SOURCE hostname** — gold for tracing which box launched the movement (e.g. ransomware). Visible in USN Journal/MFT; timestamp matches the 7045. |
| **Named pipes** (Sysmon 17/18) | `\\.\pipe\PSEXESVC` + per-exec `\\.\pipe\PSEXESVC-<HOST>-<PID>-{stdin,stdout,stderr}`. Clones: RemCom→`remcom_communication`, PAExec→pipe w/`PAExec`, CSExec→`csexecsvc`, Impacket→`RemCom_communication` + random `*.exe` on ADMIN$. |
| **Prefetch** | Target: `PSEXESVC.EXE-<hash>.pf`. Source: `PSEXEC.EXE-<hash>.pf`. |

**Quick hunt for the service-install artifact:**
```cmd
psloglist -accepteula -s -d 7 -i 7045 system | findstr /i "PSEXESVC"
```

**Artifact on the SOURCE host:** `HKCU\Software\Sysinternals\PsExec\EulaAccepted = 1` proves PsExec was run by that user (per-SID under `HKU\<SID>`). Note this same `EulaAccepted` registry trail exists for **every** Sysinternals tool (`...\Sysinternals\<Tool>\EulaAccepted`) — it's both an attacker-attribution artifact and how responders de-conflict their own tool usage. Adversaries can delete it, so absence is not exoneration.

**Cleanup of a stuck PsExec** (leftover service blocks re-runs): `sc \\target delete PSEXESVC`.

## 9. accesschk — privilege-escalation auditing

Goal: find a misconfiguration a low-privileged user can leverage to reach SYSTEM. (Authorized assessment / hardening review.)

```cmd
:: Services the Users / Authenticated Users group can MODIFY (the highest-value check)
accesschk64 -accepteula -uwcqv "Authenticated Users" *
accesschk64 -accepteula -uwcqv "Users" *
:: What the CURRENT user specifically can write (avoids guessing group membership)
accesschk64 -accepteula -uwcqv %USERNAME% *
:: Effective rights on one service — SERVICE_CHANGE_CONFIG / SERVICE_ALL_ACCESS to a low-priv group = win
accesschk64 -accepteula -ucqv <ServiceName>
:: Directories / files writable by Users (binary planting, overwriting a service EXE)
accesschk64 -accepteula -uwdqs "Users" c:\
accesschk64 -accepteula -uwqs "Users" c:\*.*
:: Writable service registry keys (a writable ImagePath is directly repointable)
accesschk64 -accepteula -kvuqsw "Users" hklm\System\CurrentControlSet\services
```
accesschk flag letters: `-u` suppress errors · `-w` write-access only · `-c` service · `-d` directory only · `-s` recurse · `-k` registry · `-q` no banner · `-v` verbose. Dropping `-w` floods output; dropping `-c` treats the arg as a path, not a service.

Defensive complement: `psservice \\HOST security <Svc>` reports a service's DACL so you can audit the same weakness from the blue-team side.

## 10. Detection summary — what defenders watch for

If you operate these tools on a monitored network, expect to generate exactly the telemetry below. If you *are* the defender, these are your highest-fidelity signals.

- **Credential dumping (ProcDump/clones vs LSASS, T1003.001)** — the marquee abuse:
  - **Security 4688** (cmd-line auditing on): `procdump`/`procdump64` with `-ma` and `lsass`.
  - **Sysmon Event 10 (ProcessAccess)** to `lsass.exe` — most reliable; alert on GrantedAccess masks `0x1010`, `0x1410`, `0x1438`, `0x1F1FFF`/`0x1FFFFF`. `0x1410` ≈ ProcDump/Task Manager, `0x1010` ≈ Mimikatz.
  - **Sysmon Event 11 (FileCreate)** of `*.dmp`/`*.mdmp` in `Temp`/`AppData`/`Downloads`, ~20–150 MB. Pair Event 10 + Event 11 for high confidence.
  - **Security 4656/4663** on the lsass object (needs a SACL + object-access auditing; off by default).
  - The `rundll32 comsvcs.dll MiniDump` LOLBin is the procdump alternative — watch command lines containing `MiniDump`.
  - Note: the suite is **Microsoft-signed**, so signature allowlisting won't stop it — detection is behavioral.
- **Injection** — Sysmon **Event 8 (CreateRemoteThread)** (Source→Target image, StartFunction), preceded by **Event 10 (OpenProcess)**.
- **PsExec lateral movement** — see §8 (7045/7036, named pipes 17/18, 4624 Type 3, the `.key` file).
- **Persistence** — Sysmon **12/13/14** (registry Run keys), **19/20/21** (WMI), **11** (Startup folder).
- **NTFS ADS execution** — Sysmon **Event 15 (FileCreateStreamHash)**; process-create command lines referencing `file:stream`; a *missing* Zone.Identifier on a freshly-downloaded file = MOTW-evasion.
- **Anti-forensics** — Sysmon **Event 2** (timestomp), **25** (process tampering/hollowing), **23/26** (file delete), **28 (FileBlockShredding)** specifically targets SDelete-style wiping.
- **Sysmon tampering** — **Event 4** (service stopped) / **Event 16** (config changed) outside a deploy window = attacker neutering telemetry.

---

## Operational gotchas (apply to every workflow above)

- **EULA hangs automation.** The first run of any tool shows a GUI EULA dialog that blocks a headless shell forever. Always pass `-accepteula` (or pre-seed `reg add HKCU\Software\Sysinternals /v EulaAccepted /t REG_DWORD /d 1 /f`). It's **per-user (HKCU)** — running as SYSTEM/another account re-prompts. A previously *declined* EULA may not be overridden by `-accepteula`.
- **Admin required.** `handle`, `listdlls` (full view), `procdump -ma`, `pslist`, `sysmon`, `ntfsinfo`, autorunsc `-a *` need elevation — without it you get partial/empty output or access-denied, not an obvious error.
- **Use the 64-bit binary** (`*64.exe`) on 64-bit Windows — a 32-bit tool under WOW64 sees a redirected/incomplete view (SysWOW64 vs System32) and misses 64-bit process internals. `procdump -64` forces a 64-bit dump of a WOW64 process.
- **AV/EDR flags the tools themselves.** `procdump.exe`, `psexec.exe`, `handle.exe`, `accesschk.exe` are common LOLBins — EDR may quarantine them mid-incident. Stage from a known-good signed copy; verify the tool runs before relying on it.
- **Name-prefix matching.** `pslist`/`handle`/`listdlls -p` take a name **prefix**, not exact match (`pslist exp` matches explorer *and* anything starting "exp"). Use a PID, or `pslist -e` for exact match, to avoid acting on the wrong process.
- **Dump-by-name fails on duplicates** (svchost, powershell) — resolve the PID and dump by PID.
- **Not on PATH.** The suite isn't on PATH by default — invoke by absolute path (`D:\tools\procdump64.exe`) in scripts.
- **CSV quirks.** `sigcheck`/`autorunsc -c` uses non-standard double-quoted cells; an Excel round-trip corrupts the format for `-o` re-import. Parse with a real CSV reader; use `-ct` (tab) if fields contain commas.

## Sources

- DFIR Madness — Case 001 AutoRuns Analysis · <https://dfirmadness.com/case-001-autoruns-analysis/>
- Jai Minton — DFIR Cheatsheet · <https://www.jaiminton.com/cheatsheet/DFIR/>
- Red Canary — LSASS Memory (T1003.001) · <https://redcanary.com/threat-detection-report/techniques/lsass-memory/>
- Red Canary — Threat hunting for PsExec & lateral movement · <https://redcanary.com/blog/threat-detection/threat-hunting-psexec-lateral-movement/>
- Unit 42 (Palo Alto) — Hunting for Unsigned DLLs to Find APTs · <https://unit42.paloaltonetworks.com/unsigned-dlls/>
- Synacktiv — Traces of Windows remote command execution · <https://www.synacktiv.com/en/publications/traces-of-windows-remote-command-execution>
- DFIR Dominican — The Key to Identify PsExec · <https://dfirdominican.com/the-key-to-identify-psexec/>
- Nasreddine Bencherchali — Hunting Malware with Sysinternals: Autoruns · <https://nasbench.medium.com/hunting-malware-with-windows-sysinternals-autoruns-19cbfe4103c2>
- tech-no.org — Sigcheck offline CSV + VirusTotal `-o` workflow · <https://tech-no.org/?p=1519>
- HackTricks — Windows Local Privilege Escalation · <https://angelica.gitbook.io/hacktricks/windows-hardening/windows-local-privilege-escalation>
- ired.team — Weak Service Permissions · <https://www.ired.team/offensive-security/privilege-escalation/weak-service-permissions>
- Hacking Articles — Unquoted Service Path · <https://www.hackingarticles.in/windows-privilege-escalation-unquoted-service-path/>
- Olaf Hartong — sysmon-modular · <https://github.com/olafhartong/sysmon-modular>
- SwiftOnSecurity — sysmon-config · <https://github.com/SwiftOnSecurity/sysmon-config>
- TrustedSec — Sysmon Community Guide · <https://github.com/trustedsec/SysmonCommunityGuide>
- Splunk Security Content — Credential Dumping with ProcDump · <https://research.splunk.com/endpoint/e102e297-dbe6-4a19-b319-5c08f4c19a06/>
- MITRE ATT&CK — Credential Dumping: LSASS Memory (T1003.001) · <https://attack.mitre.org/techniques/T1003/001/>
- Microsoft Learn — Sysinternals · <https://learn.microsoft.com/sysinternals/>
