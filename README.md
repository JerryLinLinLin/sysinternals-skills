# sysinternals-skills

An AI Agent **skill** — [`sysinternals-cli`](sysinternals-cli/SKILL.md) — for
driving the [Microsoft Sysinternals](https://learn.microsoft.com/sysinternals/)
command-line tools on Windows from a shell. It's a cheatsheet + bundled reference
docs for system administration, troubleshooting, and — heavily — digital forensics,
incident response (DFIR), threat hunting, and malware triage: process / handle / DLL
inspection, memory & crash dumps (ProcDump), persistence enumeration (Autoruns),
signature + VirusTotal checks (Sigcheck), strings & NTFS alternate-data-stream
hunting, permission / privilege-escalation auditing (AccessChk), remote execution
(PsExec & PsTools), network-to-process mapping (TCPView), and endpoint telemetry
(Sysmon).

```
sysinternals-skills/
├── README.md                     ← you are here (setup / install)
├── LICENSE
└── sysinternals-cli/
    ├── SKILL.md                  ← the cheatsheet entry point (routes by goal → tool → reference)
    ├── references/               ← cheatsheet, DFIR playbooks, per-category guides
    │   └── ms-docs/              ← the verbatim Microsoft Learn page for every tool (authoritative fallback)
    └── scripts/                  ← PowerShell collectors (host triage, persistence audit, file triage)
```

The skill **assumes the Sysinternals executables are available on the host**. They
are **not on `PATH` by default** and pop a one-time **EULA dialog** that hangs a
non-interactive shell unless you pass `-accepteula`. Get the tools once with the
guide below, then use the skill (it bakes in `-accepteula`, the `*64.exe` variants,
and the admin/bitness rules).

---

## Get the Sysinternals tools

The tools are standalone signed `.exe` files — no installer, no runtime needed.

### Whole suite (recommended)

```powershell
winget install --id Microsoft.Sysinternals.Suite -e      # the whole suite (moniker: sysinternals)
# or just the tools you need, e.g.:  winget install --id Microsoft.Sysinternals.ProcessExplorer -e
```

### A single tool on demand (Sysinternals Live)

Every tool can run straight from the web share, no download:

```powershell
\\live.sysinternals.com\tools\procdump64.exe -accepteula -ma <pid> C:\dumps
# or fetch one file:
Invoke-WebRequest "https://live.sysinternals.com/procdump64.exe" -OutFile "C:\tools\procdump64.exe"
```

## Verify the install

```powershell
& "C:\tools\sysinternals\sigcheck64.exe" -accepteula -nobanner -h C:\Windows\System32\notepad.exe
& "C:\tools\sysinternals\pslist64.exe"   -accepteula -t            # process tree -> proves it runs
```

The first run of each tool writes `HKCU\Software\Sysinternals\<Tool>\EulaAccepted=1`.
Three things make these tools work non-interactively, all enforced by the skill:
**(1)** pass `-accepteula` or the first run hangs on a GUI dialog; **(2)** prefer the
`*64.exe` build on 64-bit Windows; **(3)** most tools need an **elevated** shell and
fail *quietly* without it. See [`sysinternals-cli/SKILL.md`](sysinternals-cli/SKILL.md)
for the full operating rules.

---

## Install this skill into your AI agent (global / user space)

Claude Code, Codex CLI, and GitHub Copilot all read the **same `SKILL.md` Agent Skill
format** from a personal skills dir — installing is just dropping the
`sysinternals-cli/` folder into each:

| Agent | Global skills dir (Windows) |
|---|---|
| Claude Code | `%USERPROFILE%\.claude\skills\` |
| OpenAI Codex CLI | `%USERPROFILE%\.codex\skills\` |
| GitHub Copilot | `%USERPROFILE%\.copilot\skills\` |

```powershell
$src = "C:\projects\sysinternals-skills\sysinternals-cli"     # adjust to where you cloned it
foreach ($a in '.claude', '.codex', '.copilot') {             # keep only the agents you use
  $dst = "$env:USERPROFILE\$a\skills"
  New-Item -ItemType Directory -Force $dst | Out-Null
  Copy-Item -Recurse -Force $src $dst
}
```

Each agent auto-discovers the skill by its `name`/`description` and loads it when a
task matches (in Claude Code, run `/skills` to confirm).

## Licensing

- This skill (the `sysinternals-cli/` authored content and `scripts/`) is released
  under the [MIT License](LICENSE).
- `sysinternals-cli/references/ms-docs/` contains the official Sysinternals
  documentation by Microsoft, redistributed from the
  [MicrosoftDocs/sysinternals](https://github.com/MicrosoftDocs/sysinternals) repo
  under its original **Creative Commons Attribution 4.0** license. Those pages are
  © Microsoft; see <https://learn.microsoft.com/sysinternals/> for the canonical
  source. The Sysinternals tools themselves are distributed by Microsoft under the
  Sysinternals Software License Terms and are **not** included here.
