# Signature, Strings, ADS, ACL & Secure-Delete CLI

> File integrity/signature verification, string extraction, NTFS alternate data streams, effective-permission auditing, and secure deletion — the core CLI kit for malware triage and privilege-escalation auditing. Authoritative per-tool docs (full flag tables) live in `references/ms-docs/<tool>.md`.

## Sigcheck (`sigcheck`)
**Purpose:** Dump file version/signature info, verify digital signatures and cert chains, and check hashes against VirusTotal.
**Privilege / EULA:** Runs as standard user (admin needed to read protected paths). Suppress first-run EULA with `-accepteula`; suppress banner with `-nobanner`. VirusTotal features additionally require `-vt` to accept VT terms non-interactively (otherwise it prompts and hangs).
**Synopsis:**
```text
sigcheck [-a][-h][-i][-e][-l][-n][[-s]|[-c|-ct]|[-m]][-q][-r][-u][-vt][-v[r][s]][-f catalog file] <file or directory>
sigcheck -d [-c|-ct] <file or directory>
sigcheck -t[u][v] [-i] [-c|-ct] <certificate store name|*>
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-e` | Scan executable images only (regardless of extension) |
| `-u` | With VirusTotal: show files unknown by VT or with non-zero detection; otherwise show only unsigned files |
| `-s` | Recurse subdirectories |
| `-h` | Show file hashes |
| `-a` | Extended version info (includes entropy in bits/byte) |
| `-i` | Show catalog name and signing chain |
| `-r` | Disable certificate revocation check |
| `-v[rs]` | Query VirusTotal by hash; `r` opens reports for non-zero detections; `s` uploads unscanned files |
| `-vt` | Accept VirusTotal terms of service (required for VT, non-interactive) |
| `-o` | VirusTotal lookups of hashes in a CSV previously captured with `-h` (offline-system workflow) |
| `-c` / `-ct` | CSV output, comma / tab delimited |
| `-f <catalog>` | Look for signature in the specified catalog file |
| `-accepteula` | Silently accept the EULA |
| `-nobanner` | Suppress banner |

**Examples:**
```cmd
# Find unsigned executables in System32 (classic malware triage)
sigcheck -accepteula -nobanner -u -e c:\windows\system32

# Recursively hash + dump signature data to CSV for an evidence baseline
sigcheck -accepteula -nobanner -h -s -ct c:\windows\system32 > sigs.tsv

# VirusTotal hash lookup of a suspect file (accept VT terms inline)
sigcheck -accepteula -nobanner -vt -v c:\temp\suspect.exe

# Recursively flag files VT does not know or has flagged
sigcheck -accepteula -nobanner -vt -u -s c:\users\public

# Show full version info + entropy (packed binaries show high entropy)
sigcheck -accepteula -nobanner -a c:\temp\suspect.exe

# Offline workflow: VT-lookup hashes from a CSV captured earlier with -h
sigcheck -accepteula -nobanner -vt -o captured.csv
```
**Output / parsing:** `-c` (comma) / `-ct` (tab) emit CSV for ingestion; combine with `-h` for hash columns and `-s` for recursion. `-ct` (tab) is safest when paths contain commas. `-o` re-feeds a previously captured CSV to VirusTotal for air-gapped systems.
**Full reference:** `references/ms-docs/sigcheck.md`

## Strings (`strings`)
**Purpose:** Extract ASCII and UNICODE strings embedded in binaries/object files.
**Privilege / EULA:** Standard user. Suppress banner with `-nobanner`. (Doc lists no `-accepteula` flag; on first interactive run the Sysinternals EULA may appear — pre-accept once via the registry value `HKCU\Software\Sysinternals\Strings\EulaAccepted=1` for unattended use.)
**Synopsis:**
```text
strings [-a] [-f offset] [-b bytes] [-n length] [-o] [-q] [-s] [-u] <file or directory>
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-a` | ASCII-only search (default is Unicode + ASCII) |
| `-u` | Unicode-only search |
| `-n <length>` | Minimum string length (default 3) |
| `-o` | Print file offset where each string was found |
| `-b <bytes>` | Number of bytes of the file to scan |
| `-f <offset>` | File offset at which to start scanning |
| `-s` | Recurse subdirectories |
| `-nobanner` | Suppress banner |

**Examples:**
```cmd
# Pull printable strings from a suspect binary (URLs, IPs, mutexes, etc.)
strings -nobanner -accepteula suspect.exe

# Grep extracted strings for IOCs (pipe to findstr)
strings -nobanner suspect.exe | findstr /i "http:// https:// .onion"

# Only long Unicode strings (cuts noise) with file offsets
strings -nobanner -u -o -n 8 suspect.exe

# Recurse a dropped-payload directory, ASCII only
strings -nobanner -a -s c:\temp\dropper\

# Scan only the first 4KB (header region) of a file
strings -nobanner -b 4096 suspect.bin
```
**Output / parsing:** Plain-text, one string per line; `-o` prepends the file offset for triage. Pipe to `findstr /i` (or `sort`/`uniq`) to hunt IOCs. No CSV mode.
**Full reference:** `references/ms-docs/strings.md`

## Streams (`streams`)
**Purpose:** Reveal (and optionally delete) NTFS alternate data streams on files and directories — a common malware hiding spot and Zone.Identifier carrier.
**Privilege / EULA:** Standard user for read; write/delete needs permission on the target. Suppress first-run EULA with `-accepteula`. (No `-nobanner` flag.)
**Synopsis:**
```text
streams [-s] [-d] <file or directory>
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-s` | Recurse subdirectories |
| `-d` | Delete streams |
| `-accepteula` | Silently accept the EULA |

**Examples:**
```cmd
# List alternate data streams on a single file
streams -accepteula suspect.exe

# Recursively hunt for ADS across a download/temp tree
streams -accepteula -s c:\users\public\downloads

# Wildcard scan of a directory's text files
streams -accepteula *.txt

# Strip all alternate data streams recursively (removes Zone.Identifier / hidden payloads)
streams -accepteula -s -d c:\users\public\downloads
```
**Output / parsing:** Text output listing each stream name and size per file. No CSV mode — parse the `:streamname:$DATA` lines yourself. `-d` is destructive; enumerate first before deleting.
**Full reference:** `references/ms-docs/streams.md`

## AccessChk (`accesschk`)
**Purpose:** Report effective permissions on files, directories, registry keys, services, processes, shares, and Object Manager objects — core privesc-audit tool.
**Privilege / EULA:** Standard user (admin needed to read security on protected objects). Suppress first-run EULA with `-accepteula`; suppress banner with `-nobanner`.
**Synopsis:**
```text
accesschk [-s][-e][-u][-r][-w][-n][-v]-[f <account>,...][[-a]|[-k]|[-p [-f] [-t]]|[-h][-o [-t <object type>]][-c]|[-d]] [[-l [-i]]|[username]] <file, directory, registry key, process, service, object>
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-c` | Name is a Windows service (`*` = all, `scmanager` = SCM) |
| `-k` | Name is a registry key (e.g. `hklm\software`) |
| `-p` | Name is a process name or PID (`*` = all); `-f` adds full token (groups/privileges), `-t` adds threads |
| `-h` | Name is a file or printer share (`*` = all shares) |
| `-o` | Name is an Object Manager object; `-t <type>` filters (e.g. `section`) |
| `-a` | Name is a Windows account right (`*` = all rights for a user) |
| `-w` / `-r` / `-n` | Show only objects with write / read / no access |
| `-s` | Recurse |
| `-e` | Only show explicitly set integrity levels |
| `-v` | Verbose; dump specific access bits (includes integrity level) |
| `-l [-i]` | Show full security descriptor; `-i` ignores inherited ACEs |
| `-u` | Suppress errors |
| `-nobanner` | Suppress banner |

**Examples:**
```cmd
# Services that standard Users can modify (service-hijack / privesc check)
accesschk -accepteula -nobanner -uwc users *

# Writable files under System32 for Users (binary-planting surface)
accesschk -accepteula -nobanner -uws users c:\windows\system32

# Effective access of an account to a registry hive
accesschk -accepteula -nobanner -k hklm\software

# Full token (groups + privileges) of a running process
accesschk -accepteula -nobanner -p -f cmd.exe

# Global objects Everyone can modify
accesschk -accepteula -nobanner -wuo everyone \basednamedobjects

# All rights assigned to a user account
accesschk -accepteula -nobanner -a domain\user *

# Dump full security descriptor of a key, ignoring inherited ACEs
accesschk -accepteula -nobanner -l -i -k hklm\software
```
**Output / parsing:** Prints `R`/`W` per object by default; `-v` dumps specific access bits. No CSV mode — filter with `-w`/`-r`/`-n` and pipe to `findstr`. `-u` suppresses access-denied noise for clean scripted output.
**Full reference:** `references/ms-docs/accesschk.md`

## SDelete (`sdelete`)
**Purpose:** Securely overwrite files/directories and cleanse free space (DoD 5220.22-M) so deleted/EFS data is unrecoverable.
**Privilege / EULA:** Standard user for own files; cleaning free space / raw-disk access needs admin. Suppress banner with `-nobanner`; use `-q` (quiet) for scripted runs. (No `-accepteula` flag in this doc; pre-accept the EULA once via `HKCU\Software\Sysinternals\SDelete\EulaAccepted=1` for unattended use.)
**Synopsis:**
```text
sdelete [-p passes] [-r] [-s] [-q] [-f] <file or directory [...]>
sdelete [-p passes] [-q] [-z|-c] <drive letter [...]>
sdelete [-p passes] [-q] [-z|-c] <physical disk number [...]>
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-p <passes>` | Number of overwrite passes (default 1) |
| `-s` | Recurse subdirectories |
| `-r` | Remove read-only attribute |
| `-c` | Clean (overwrite) free space |
| `-z` | Zero free space (good for virtual-disk optimization) |
| `-f` | Force a letters-only argument to be treated as a file/dir, not a disk |
| `-q` | Quiet mode |
| `-nobanner` | Suppress banner |

**Examples:**
```cmd
# Securely delete a single sensitive file (3 passes)
sdelete -nobanner -p 3 c:\temp\secret.docx

# Recursively wipe a directory tree, clearing read-only attrs, quietly
sdelete -nobanner -q -s -r c:\temp\sensitive

# Cleanse free space on C: to destroy remnants of already-deleted files
sdelete -nobanner -c c:

# Zero free space (shrink/compact a virtual disk)
sdelete -nobanner -z c:

# Force a letters-only name to be treated as a file, not a drive
sdelete -nobanner -f -p 3 secret
```
**Output / parsing:** Use `-q` to silence per-file output in scripts. Note: free-space cleaning (`-c`/`-z`) requires the drive letter to include `:` (e.g. `D:`); physical disks must have no volumes. SDelete does not wipe file names left in free directory space.
**Full reference:** `references/ms-docs/sdelete.md`

## LogonSessions (`logonsessions`)
**Purpose:** List active logon sessions (user, auth package, logon type, SID, logon server) and optionally the processes in each — useful for spotting unexpected sessions during IR.
**Privilege / EULA:** Run as admin to see all sessions/processes. Suppress first-run EULA with `-accepteula` (Sysinternals standard). (No `-nobanner` flag in this doc.)
**Synopsis:**
```text
logonsessions [-c[t]] [-p]
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-p` | List processes running in each logon session |
| `-c` | Print output as CSV (comma-delimited) |
| `-ct` | Print output as tab-delimited values |

**Examples:**
```cmd
# List all active logon sessions
logonsessions -accepteula

# Include the processes running under each session (IR triage)
logonsessions -accepteula -p

# CSV output for parsing / ingestion
logonsessions -accepteula -c > sessions.csv

# Tab-delimited output (safer with comma-containing fields)
logonsessions -accepteula -ct > sessions.tsv
```
**Output / parsing:** `-c` (comma) and `-ct` (tab) give machine-readable output; `-p` adds a process list per session. Look for unexpected `RemoteInteractive`/`Network` logon types and unknown SIDs.
**Full reference:** `references/ms-docs/logonsessions.md`

## EfsDump (`efsdump`)
**Purpose:** Show which user accounts (and DRAs) are authorized to access EFS-encrypted files.
**Privilege / EULA:** Standard user (needs read access to the target files). Suppress first-run EULA with `-accepteula` (Sysinternals standard). (Doc lists only `-s`; no `-nobanner`.)
**Synopsis:**
```text
efsdump [-s] <file or directory>
```
**Key flags:**

| Flag | Meaning |
|------|---------|
| `-s` | Recurse subdirectories |
| `-accepteula` | Silently accept the EULA |

**Examples:**
```cmd
# Show accounts authorized to decrypt an EFS-encrypted file
efsdump -accepteula secret.docx

# Recurse a directory to audit EFS access across encrypted files
efsdump -accepteula -s c:\users\mark\private

# Wildcard scan of encrypted text files
efsdump -accepteula *.txt
```
**Output / parsing:** Text listing of authorized users/data-recovery agents per file. No CSV mode. Recurse with `-s` to audit who can decrypt across a tree (catches over-broad DRA or shared-key exposure).
**Full reference:** `references/ms-docs/efsdump.md`

## AccessEnum (`accessenum`)
**Purpose:** Browse who has read/write/deny access across a file-system or registry tree to spot permission anomalies. GUI-only — no meaningful CLI; listed for completeness.
**Full reference:** `references/ms-docs/accessenum.md`

## ShareEnum (`shareenum`)
**Purpose:** Enumerate network file/print shares and their security settings to find loosely-secured shares. GUI-only — no meaningful CLI; listed for completeness (run from a domain admin account for full visibility).
**Full reference:** `references/ms-docs/shareenum.md`
