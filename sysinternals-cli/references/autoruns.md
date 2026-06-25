# Autorunsc — Autostart / Persistence Enumeration CLI

> Autorunsc is the command-line version of Autoruns, the most comprehensive enumerator of Windows autostart extensibility points (ASEPs) — a core tool for persistence hunting. It dumps logon entries, services, drivers, scheduled tasks, WMI, image hijacks, and more, with CSV/tab output, file hashes, signature verification, and VirusTotal lookups. Authoritative per-tool docs (full flag tables) live in `references/ms-docs/autoruns.md`.

## Autorunsc (`autorunsc`)
**Purpose:** Enumerate all Windows autostart extensibility points (persistence locations) from the command line for DFIR and audit.
**Privilege / EULA:** Run elevated (admin) for complete coverage of services, drivers, and all-user entries. Suppress the first-run EULA dialog for non-interactive/automation use with `-accepteula` (otherwise it hangs on the popup). VirusTotal terms must also be accepted non-interactively via `-vt`. No `-nobanner` flag exists; in CSV/tab/XML modes the banner is not part of the data rows.
**Synopsis:**
```text
Usage: autorunsc [-a <*|bdeghiklmoprsw>] [-c|-ct] [-h] [-m] [-s] [-u] [-vt] [[-z ] | [user]]]
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-a <cats>` | Select autostart categories (see codes below). `-a *` = all. Default is `l` (logon). |
| `-c` | Output as CSV. |
| `-ct` | Output as tab-delimited values. |
| `-x` | Output as XML. |
| `-h` | Show file hashes (MD5/SHA/etc.). |
| `-s` | Verify digital signatures. |
| `-m` | Hide Microsoft entries (per the docs, hides *signed* entries when combined with `-v`) — zoom in on third-party. In practice commonly paired with `-s` (signature verification) to cut signed-Microsoft noise during persistence hunts. |
| `-t` | Show timestamps in normalized UTC (`YYYYMMDD-hhmmss`). |
| `-v[rs]` | Query VirusTotal by file hash. `r` = open reports for non-zero detections; `s` = upload unknown files. |
| `-vt` | Accept VirusTotal terms of service (required for non-interactive `-v`). |
| `-u` | With VirusTotal: show only unknown/non-zero-detection files; otherwise show only unsigned files. |
| `-z <dir>` | Scan an offline Windows system (mounted image / dead-box). |
| `user` | Scan a specific user account; `*` = all user profiles. |

Category codes for `-a`: `b` boot execute, `d` AppInit DLLs, `e` Explorer addons, `g` sidebar gadgets, `h` image hijacks, `i` IE addons, `k` known DLLs, `l` logon (default), `m` WMI, `n` Winsock/network providers, `o` codecs, `p` printer monitor DLLs, `r` LSA security providers, `s` autostart services + non-disabled drivers, `t` scheduled tasks, `w` Winlogon entries, `*` all.

**Examples:**
```cmd
# Full ASEP sweep of all users with hashes + signature checks, CSV to file (DFIR baseline)
autorunsc -accepteula -a * -s -h -ct -t * > autoruns_%COMPUTERNAME%.tsv

# Hunt third-party persistence: hide signed Microsoft entries, verify signatures
autorunsc -accepteula -a * -m -s -ct *

# Triage with VirusTotal: hash-check all entries, accept ToS, show only unknown/flagged
autorunsc -accepteula -a * -h -vt -v -u -ct *

# Services and drivers only, with signatures and hashes (rootkit / malicious driver hunt)
autorunsc -accepteula -a s -s -h -ct

# Scheduled tasks, WMI subscriptions, and logon entries (common persistence vectors)
autorunsc -accepteula -a tml -s -h -ct *

# Scan an offline / mounted image for autostarts (dead-box forensics)
autorunsc -accepteula -a * -s -h -ct -z D:\mnt\Windows
```
**Output / parsing:** Use `-ct` (tab-delimited) or `-c` (CSV) for machine-readable rows; `-x` for XML. Combine with `-t` for normalized UTC timestamps that sort/diff cleanly. Redirect to a file and diff against a known-good baseline to spot new persistence. `-h` adds hash columns for IOC matching; `-s` adds verification status. For non-interactive runs always include `-accepteula` (and `-vt` when using VirusTotal) to avoid blocking prompts.
**Full reference:** `references/ms-docs/autoruns.md`
