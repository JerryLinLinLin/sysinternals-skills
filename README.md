# sysinternals-skills

Two AI Agent skills for using Microsoft Sysinternals on Windows:

- [`sysinternals-cli`](skills/sysinternals-cli/SKILL.md) is the broad command-line cheatsheet and
  router for Sysinternals/PsTools administration, troubleshooting, DFIR, and security workflows.
- [`procmon`](skills/procmon/SKILL.md) is a focused Process Monitor cheatsheet for general application
  and system behavior analysis: launch failures, configuration discovery, missing dependencies,
  permissions, writes, child processes, installers, services, performance clues, and working/failing
  trace comparison. It is intentionally not a malware-analysis playbook.

```text
sysinternals-skills/
├── README.md
├── LICENSE
└── skills/
    ├── sysinternals-cli/
    │   ├── SKILL.md
    │   ├── references/
    │   │   └── ms-docs/          # copied Microsoft Learn pages for the suite
    │   └── scripts/              # PowerShell collectors
    └── procmon/
        ├── SKILL.md
        ├── agents/openai.yaml
        └── references/           # Procmon recipes, CLI reference, copied Microsoft page
```

## Get the Sysinternals tools

The skills assume the relevant Sysinternals executables are installed and available on `PATH`.
Install the whole suite with winget:

```powershell
winget install --id Microsoft.Sysinternals.Suite -e
```

Or run/download an individual tool from Sysinternals Live:

```powershell
\\live.sysinternals.com\tools\procmon.exe
Invoke-WebRequest -Uri 'https://live.sysinternals.com/procmon.exe' `
    -OutFile 'C:\Tools\Sysinternals\procmon.exe'
```

A winget or Microsoft Store installation exposes the already-native build under the plain tool name,
such as `procmon.exe`, `procdump.exe`, or `sigcheck.exe`. A manually extracted archive is the main
case where an architecture-suffixed executable may be selected deliberately.

Verify discovery in a new shell:

```powershell
Get-Command -Name 'procmon.exe', 'sigcheck.exe', 'pslist.exe' -CommandType Application
sigcheck.exe -accepteula -nobanner -h 'C:\Windows\System32\notepad.exe'
pslist.exe -accepteula -t
```

Sysinternals tools show a one-time per-user EULA prompt. An unattended invocation can block unless
the applicable `-accepteula` or `/AcceptEula` option is used after acceptance is authorized. Procmon
and many inspection tools also require an elevated shell for complete results.

## Install the skills into an AI agent

Claude Code, Codex CLI, and GitHub Copilot use the same `SKILL.md` Agent Skill format. Copy either or
both folders from `skills/` into the agent's personal skill directory:

| Agent | Personal skills directory on Windows |
| --- | --- |
| Claude Code | `%USERPROFILE%\.claude\skills\` |
| OpenAI Codex CLI | `%USERPROFILE%\.codex\skills\` |
| GitHub Copilot | `%USERPROFILE%\.copilot\skills\` |

```powershell
$repositorySkills = 'C:\projects\sysinternals-skills\skills' # adjust for the clone location
$skillNames = @('sysinternals-cli', 'procmon')                 # keep only the skills wanted
$agentHomes = @('.claude', '.codex', '.copilot')              # keep only the agents used

foreach ($agentHome in $agentHomes) {
    $destinationRoot = Join-Path $env:USERPROFILE "$agentHome\skills"
    $null = New-Item -ItemType Directory -Path $destinationRoot -Force

    foreach ($skillName in $skillNames) {
        $source = Join-Path $repositorySkills $skillName
        Copy-Item -LiteralPath $source -Destination $destinationRoot -Recurse -Force
    }
}
```

Each agent discovers a skill through the `name` and `description` in its `SKILL.md` and loads the
full instructions only when a task matches.

## Licensing

- The authored skill content and scripts under `skills/` are released under the [MIT License](LICENSE).
- `skills/sysinternals-cli/references/ms-docs/` and
  `skills/procmon/references/microsoft-learn-procmon.md` contain Microsoft Sysinternals documentation
  copied from the [MicrosoftDocs/sysinternals](https://github.com/MicrosoftDocs/sysinternals)
  material under its original **Creative Commons Attribution 4.0** license. The canonical published
  documentation is at [Microsoft Learn](https://learn.microsoft.com/sysinternals/).
- The Sysinternals executables are distributed by Microsoft under the Sysinternals Software License
  Terms and are not included in this repository.
