# Networking, Disk & System-Info CLI

> Command-line reference for Sysinternals network-connection enumeration, latency/bandwidth testing, NTFS/disk/link inspection, CPU topology, registry usage, named pipes, and number conversions. All tools accept the universal Sysinternals `-accepteula` switch to dismiss the first-run EULA dialog non-interactively (critical for automation — the EULA popup will otherwise hang an unattended run). Authoritative per-tool docs (full flag tables) live in `references/ms-docs/<tool>.md`.

## TCPVcon (`tcpvcon`)
**Purpose:** Command-line TCPView — enumerate all TCP/UDP endpoints with owning process (netstat replacement).
**Privilege / EULA:** Standard user runs; admin recommended to resolve all process owners. First run shows a EULA — pass `-accepteula` for automation. No `-nobanner` flag; use `-c` (CSV) for clean machine output.
**Synopsis:**
```text
tcpvcon [-a] [-c] [-n] [process name or PID]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-a` | Show all endpoints (default shows only established TCP connections). |
| `-c` | Print output as CSV. |
| `-n` | Don't resolve addresses (faster; avoids DNS noise/leaks). |
**Examples:**
```cmd
# Dump every TCP/UDP endpoint, no DNS resolution, as CSV for triage
tcpvcon -accepteula -a -c -n

# List only established TCP connections (default)
tcpvcon -accepteula

# Show all endpoints owned by a suspect process by name
tcpvcon -accepteula -a -n powershell

# Show all endpoints for a specific PID
tcpvcon -accepteula -a -c 4242
```
**Output / parsing:** `-c` emits CSV (proto, process/PID, state, local/remote address+port) — pipe to a file or PowerShell `ConvertFrom-Csv`. Combine `-n` to keep raw IPs for IOC matching.
**Full reference:** `references/ms-docs/tcpview.md`

## PsPing (`psping`)
**Purpose:** ICMP ping, TCP-connect ping, and TCP/UDP latency & bandwidth measurement.
**Privilege / EULA:** Standard user for client tests; opening a firewall port (`-f`) or binding a server may need admin. Pass `-accepteula` on first run. No banner-suppression flag; use `-q` to silence per-iteration output.
**Synopsis:**
```text
ICMP ping: psping [[-6]|[-4]] [-h [buckets|v1,v2,...]] [-i <interval>] [-l <size>[k|m]] [-q] [-t|-n <count>] [-w <count>] <destination>
TCP ping:  psping [[-6]|[-4]] [-h ...] [-i <interval>] [-l <size>[k|m]] [-q] [-t|-n <count>] [-w <count>] <destination:port>
Latency server: psping [[-6]|[-4]] [-f] <-s source:port>
Latency client: psping [[-6]|[-4]] [-f] [-u] [-h ...] [-r] <-l size>[k|m] <-n count> [-w <count>] <destination:port>
Bandwidth client: psping [-b] [[-6]|[-4]] [-f] [-u] [-h ...] [-r] <-l size>[k|m] <-n count> [-i <outstanding>] [-w <count>] <destination:port>
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-n <count>` | Number of pings/sends (append `s` for seconds, e.g. `10s`). |
| `-i <interval>` | Interval in seconds; `0` for fast ping (bandwidth: number of outstanding I/Os). |
| `-l <size>[k\|m]` | Request/buffer size (required for latency/bandwidth tests). |
| `-w <count>` | Warmup iterations (excluded from stats). |
| `-q` | No per-ping output (summary only). |
| `-h <buckets>` | Print latency histogram (count or comma-separated bucket list). |
| `-t` | Ping until Ctrl+C (Ctrl+Break for interim stats). |
| `-b` | Bandwidth test (client). |
| `-u` | UDP instead of TCP (latency/bandwidth). |
| `-s <src:port>` | Run as latency/bandwidth server bound to address:port. |
| `-f` | Open source firewall port for the run. |
| `-r` | Receive from server instead of sending. |
| `-4` / `-6` | Force IPv4 / IPv6. |
**Examples:**
```cmd
# ICMP ping a host, 10 iterations with 3 warmups
psping -accepteula -n 10 -w 3 server01

# TCP-connect test to port 443 as fast as possible, summary only
psping -accepteula -n 100 -i 0 -q server01:443

# Start a latency/bandwidth server bound to 192.168.2.2:5000
psping -accepteula -s 192.168.2.2:5000

# TCP latency: 8KB packets, 10000 sends, 100-bucket histogram
psping -accepteula -l 8k -n 10000 -h 100 192.168.2.2:5000

# TCP bandwidth test to a psping server, 100-bucket histogram
psping -accepteula -b -l 8k -n 10000 -h 100 192.168.2.2:5000
```
**Output / parsing:** Summary reports min/avg/max latency; `-h` adds a histogram. Use `-q` to suppress per-iteration lines for cleaner log capture. No CSV; scrape the summary block.
**Full reference:** `references/ms-docs/psping.md`

## Whois (`whois`)
**Purpose:** Look up the registration record for a domain name or IP address.
**Privilege / EULA:** Standard user. Pass `-accepteula` on first run for automation. No banner-suppression flag.
**Synopsis:**
```text
whois [-v] domainname [whois.server]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-v` | Print whois information for referrals (follow referral chain). |
| `[whois.server]` | Query a specific whois server instead of the default. |
**Examples:**
```cmd
# Look up a domain's registration record
whois -accepteula sysinternals.com

# Resolve ownership of a suspicious IP (IOC enrichment)
whois -accepteula 66.193.254.46

# Follow referral servers for the full authoritative record
whois -accepteula -v evil-domain.example

# Query a specific whois server
whois -accepteula example.org whois.iana.org
```
**Output / parsing:** Plain-text registrar record. `-v` chases referrals to the authoritative registry. Accepts either a DNS name or IP address as input.
**Full reference:** `references/ms-docs/whois.md`

## Coreinfo (`coreinfo`)
**Purpose:** Dump CPU topology — logical/physical core mapping, NUMA nodes, sockets, caches, and CPU feature flags (incl. virtualization support).
**Privilege / EULA:** Standard user for most output; `-v` (virtualization features) requires admin on Intel. Pass `-accepteula` on first run. Run on bare metal (no hypervisor) for accurate VMX/EPT reporting.
**Synopsis:**
```text
coreinfo [-c][-f][-g][-l][-n][-s][-m][-v]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-c` | Dump information on cores. |
| `-f` | Dump core feature information (instruction sets, security flags). |
| `-g` | Dump information on groups. |
| `-l` | Dump information on caches. |
| `-n` | Dump information on NUMA nodes. |
| `-s` | Dump information on sockets. |
| `-m` | Dump NUMA access cost matrix. |
| `-v` | Dump only virtualization features incl. SLAT (admin on Intel). |
**Examples:**
```cmd
# Full topology + feature dump (all sections except -v are default)
coreinfo -accepteula

# Check virtualization / SLAT support before deploying Hyper-V / WSL2
coreinfo -accepteula -v

# Core and cache topology only
coreinfo -accepteula -c -l

# NUMA node layout plus inter-node access costs
coreinfo -accepteula -n -m

# CPU feature flags (verify AVX2/AES/NX availability)
coreinfo -accepteula -f
```
**Output / parsing:** Text with `*` marking applicable logical processors per resource line; features show `*` (present) or `-` (absent). No CSV — parse fixed-width columns or grep specific feature rows.
**Full reference:** `references/ms-docs/coreinfo.md`

## PipeList (`pipelist`)
**Purpose:** List named pipes (NPFS) on the system with max and active instance counts.
**Privilege / EULA:** Standard user. Pass `-accepteula` on first run. No documented flags.
**Synopsis:**
```text
pipelist
```
**Key flags:** None documented (the tool takes no parameters beyond the universal `-accepteula`).
**Examples:**
```cmd
# Enumerate all named pipes with instance counts (malware/C2 pipe hunting)
pipelist -accepteula

# Capture pipe inventory to a file for baseline comparison
pipelist -accepteula > pipes-baseline.txt
```
**Output / parsing:** Plain-text columns: pipe name, max instances, active instances. Redirect to file and diff against a clean baseline to spot anomalous IPC pipes.
**Full reference:** `references/ms-docs/pipelist.md`

## Du (`du`)
**Purpose:** Report disk-space usage by directory, recursing subdirectories by default.
**Privilege / EULA:** Standard user (admin needed to traverse protected paths). Pass `-accepteula` on first run. Suppress the startup banner with `-nobanner` and per-line noise with `-q`.
**Synopsis:**
```text
du [-c[t]] [-l <levels> | -n | -v] [-u] [-q] [-nobanner] <directory>
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-c` / `-ct` | Output as CSV / tab-delimited. |
| `-l <levels>` | Subdirectory depth to report (default 0). |
| `-n` | Do not recurse. |
| `-v` | Show size (KB) of intermediate directories. |
| `-u` | Count each instance of a hardlinked file. |
| `-q` | Quiet. |
| `-nobanner` | Suppress startup banner / copyright. |
**Examples:**
```cmd
# Total size of a tree as CSV (scriptable)
du -accepteula -nobanner -c C:\Users\jdoe

# Per-subdirectory sizes one level deep
du -accepteula -l 1 C:\inetpub

# Tab-delimited output, intermediate dir sizes shown
du -accepteula -ct -v D:\data

# Single-directory size, no recursion
du -accepteula -n C:\Windows\Temp
```
**Output / parsing:** CSV header is `Path, CurrentFileCount, CurrentFileSize, FileCount, DirectoryCount, DirectorySize, DirectorySizeOnDisk`. Use `-ct` for tab-delimited when paths contain commas.
**Full reference:** `references/ms-docs/du.md`

## Contig (`contig`)
**Purpose:** Single-file defragmenter; analyze fragmentation, defrag individual files, or create contiguous new files.
**Privilege / EULA:** Standard user for analysis; admin required for `-l` (quick file creation). Pass `-accepteula` on first run. Use `-q` for quiet output.
**Synopsis:**
```text
contig [-a] [-s] [-q] [-v] [existing file]
contig [-f] [-q] [-v] [drive:]
contig [-v] [-l] -n [new file] [new file length]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-a` | Analyze fragmentation (report only, no defrag). |
| `-f` | Analyze free-space fragmentation of a drive. |
| `-s` | Recurse subdirectories. |
| `-n` | Create a new contiguous file of the given length. |
| `-l` | Set valid data length for quick file creation (admin). |
| `-q` | Quiet mode. |
| `-v` | Verbose. |
**Examples:**
```cmd
# Analyze fragmentation of a file without moving it
contig -accepteula -a C:\db\large.mdf

# Recursively analyze fragmentation of all files in a tree
contig -accepteula -a -s C:\logs\*

# Defragment a frequently-rewritten file
contig -accepteula -v C:\db\large.mdf

# Analyze free-space fragmentation of a drive
contig -accepteula -f C:

# Create a 1GB contiguous file
contig -accepteula -n D:\preallocated.dat 1073741824
```
**Output / parsing:** Reports fragment counts before/after. Can also target NTFS metadata files (`$Mft`, `$LogFile`, `$Bitmap`, `$Boot`, etc.). Use `-q` to limit output for scripting.
**Full reference:** `references/ms-docs/contig.md`

## Junction (`junction`)
**Purpose:** Create, delete, and query NTFS junction points / reparse points.
**Privilege / EULA:** Standard user can query; creating/deleting junctions in protected paths needs admin. Pass `-accepteula` on first run. Use `-q` to suppress reparse-point query noise.
**Synopsis:**
```text
junction [-s] [-q] <file or directory>          (query)
junction <junction directory> <junction target> (create)
junction -d <junction directory>                (delete)
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-s` | Recurse subdirectories (scan for junctions/reparse points). |
| `-q` | Quiet — don't print the reparse-point scan header. |
| `-d` | Delete the specified junction point. |
**Examples:**
```cmd
# Check whether a path is a junction / reparse point
junction -accepteula C:\test

# Recursively hunt for junctions under a root (reparse-point abuse / persistence)
junction -accepteula -s C:\

# Create a junction C:\Program-Files pointing at "C:\Program Files"
junction -accepteula C:\Program-Files "C:\Program Files"

# Delete a junction
junction -accepteula -d C:\Program-Files
```
**Output / parsing:** Query prints whether each path is a reparse point and its target. Return codes: `0` success/non-fatal failures, `-1` on failed junction creation. `-s` is the DFIR workhorse for finding rogue reparse points.
**Full reference:** `references/ms-docs/junction.md`

## FindLinks (`findlinks`)
**Purpose:** Report a file's NTFS index and all hard links (alternate paths on the same volume) referencing the same data.
**Privilege / EULA:** Standard user (admin to read protected paths). Pass `-accepteula` on first run. No banner-suppression flag.
**Synopsis:**
```text
findlinks <filename>
```
**Key flags:** None beyond the filename argument (and universal `-accepteula`).
**Examples:**
```cmd
# Enumerate all hard links to a system binary (spot hidden duplicates)
findlinks -accepteula C:\Windows\System32\notepad.exe

# Reveal alternate names of a suspicious file before deletion
findlinks -accepteula C:\ProgramData\suspicious.dll
```
**Output / parsing:** Prints the file Index, link count, and each linking path. Useful in DFIR to confirm that deleting one path won't free the data if other hard links remain.
**Full reference:** `references/ms-docs/findlinks.md`

## NTFSInfo (`ntfsinfo`)
**Purpose:** Dump NTFS volume internals — cluster/allocation-unit size, MFT location & size, MFT-Zone, and metadata-file sizes.
**Privilege / EULA:** Requires administrative privilege. Pass `-accepteula` on first run. No banner-suppression flag.
**Synopsis:**
```text
ntfsinfo x
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `x` | Drive letter of the NTFS volume to examine. |
**Examples:**
```cmd
# Dump NTFS internals for the C: volume (run elevated)
ntfsinfo -accepteula c

# Inspect a data volume's cluster size and MFT layout
ntfsinfo -accepteula d
```
**Output / parsing:** Text dump of volume size, cluster/sector sizes, MFT start cluster and size, MFT-Zone bounds, and sizes of `$Boot`, `$Bitmap`, and other metadata files. Single-argument tool — no machine-readable format.
**Full reference:** `references/ms-docs/ntfsinfo.md`

## Sync (`sync`)
**Purpose:** Flush cached file-system data to disk (and optionally flush/eject removable drives).
**Privilege / EULA:** Requires administrative privilege. Pass `-accepteula` on first run. No banner-suppression flag.
**Synopsis:**
```text
sync [-r] [-e] [drive letter list]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-r` | Flush removable drives. |
| `-e` | Eject removable drives. |
**Examples:**
```cmd
# Flush all fixed drives' cached data to disk (run elevated)
sync -accepteula

# Flush only the C and E volumes
sync -accepteula c e

# Flush and then eject a removable drive
sync -accepteula -e f
```
**Output / parsing:** No structured output; success is silent flush. Specify drive letters to limit the flush to specific volumes (e.g. before imaging or safe-removal).
**Full reference:** `references/ms-docs/sync.md`

## MoveFile / PendMoves (`pendmoves`)
**Purpose:** PendMoves lists file rename/delete operations queued for next boot (`PendingFileRenameOperations`); MoveFile schedules them.
**Privilege / EULA:** Admin recommended (reads HKLM and schedules boot-time moves). Pass `-accepteula` on first run. No banner-suppression flag.
**Synopsis:**
```text
pendmoves
movefile [source] [dest]
```
**Key flags:** PendMoves takes no parameters. MoveFile takes `[source] [dest]`; an empty `dest` (`""`) deletes the source at boot.
**Examples:**
```cmd
# List all file moves/deletes queued for the next reboot (persistence / cleanup audit)
pendmoves -accepteula

# Schedule a locked file to be deleted on next boot
movefile -accepteula C:\malware\locked.exe ""

# Schedule a replacement (rename) at next boot
movefile -accepteula C:\temp\new.dll C:\app\in-use.dll
```
**Output / parsing:** PendMoves prints `Source:`/`Target:` pairs (`Target: DELETE` for deletions) and flags inaccessible sources — a quick way to detect malware staging boot-time replacements.
**Full reference:** `references/ms-docs/pendmoves.md`

## Ru (Registry Usage) (`ru`)
**Purpose:** Report registry space usage for a key (and subkeys), or for keys inside an offline hive file.
**Privilege / EULA:** Admin needed for protected keys / loading hives. Pass `-accepteula` on first run. `-q` doubles as the quiet/no-banner switch.
**Synopsis:**
```text
ru [-c[t]] [-l <levels> | -n | -v] [-q] <absolute path>
ru [-c[t]] [-l <levels> | -n | -v] [-q] -h <hive file> [relative path]
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `-c` / `-ct` | Output as CSV / tab-delimited. |
| `-l <levels>` | Subkey depth to report (default one level). |
| `-n` | Do not recurse. |
| `-v` | Show size of all subkeys. |
| `-q` | Quiet (no banner). |
| `-h <hive>` | Load an offline hive file, size it, then unload/compress. |
**Examples:**
```cmd
# Size a registry subtree as CSV (find registry bloat)
ru -accepteula -q -c HKLM\SOFTWARE

# Show usage two subkey levels deep under Run keys
ru -accepteula -l 2 HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Run

# Full per-subkey sizing of a key
ru -accepteula -v HKCU\Software

# Analyze an offline hive file (DFIR on a collected NTUSER.DAT)
ru -accepteula -c -h C:\evidence\NTUSER.DAT
```
**Output / parsing:** CSV header is `Path,CurrentValueCount,CurrentValueSize,ValueCount,KeyCount,KeySize,WriteTime`. The `-h` mode lets you size hives pulled from a forensic image without loading them into the live registry.
**Full reference:** `references/ms-docs/ru.md`

## Hex2dec (`hex2dec`)
**Purpose:** Convert between hexadecimal and decimal on the command line.
**Privilege / EULA:** Standard user. Pass `-accepteula` on first run if prompted. No banner-suppression flag.
**Synopsis:**
```text
hex2dec [hex|decimal]
```
**Key flags:** None. Prefix input with `x` or `0x` to indicate a hex value; plain digits are treated as decimal.
**Examples:**
```cmd
# Decimal -> hex
hex2dec 1233

# Hex -> decimal (0x prefix marks hex input)
hex2dec 0x1233

# Convert an error/status code seen in hex to decimal
hex2dec 0xC0000022
```
**Output / parsing:** Prints the single converted value to stdout — directly capturable in a script variable.
**Full reference:** `references/ms-docs/hex2dec.md`

## VolumeId (`volumeid`)
**Purpose:** Set the volume ID (serial) of FAT or NTFS drives.
**Privilege / EULA:** Requires administrative privilege. Pass `-accepteula` on first run. No banner-suppression flag.
**Synopsis:**
```text
volumeid <driveletter:> xxxx-xxxx
```
**Key flags:**
| Flag | Meaning |
|------|---------|
| `<driveletter:>` | Target volume (e.g. `D:`). |
| `xxxx-xxxx` | New volume ID in hex (e.g. `1A2B-3C4D`). |
**Examples:**
```cmd
# Set a new volume ID on D: (NTFS change applies after reboot)
volumeid -accepteula D: 1A2B-3C4D

# Re-stamp a FAT volume's serial (close apps using the drive first)
volumeid -accepteula E: ABCD-1234
```
**Output / parsing:** No structured output. NTFS changes are not visible until reboot; close applications using the drive before changing a FAT volume ID. Useful for licensing/evasion testing where software keys to the volume serial.
**Full reference:** `references/ms-docs/volumeid.md`

## DiskExt (`diskext`)
**Purpose:** Display volume-to-physical-disk mappings (which disks and offsets a volume's partitions occupy).
**Privilege / EULA:** Admin recommended for full disk access. Pass `-accepteula` on first run. No documented flags.
**Synopsis:**
```text
diskext [drive letter]
```
**Key flags:** None documented; optionally pass a drive letter to scope the query.
**Examples:**
```cmd
# Show disk-extent mappings for all volumes
diskext -accepteula

# Show which physical disk(s) and offsets back the C: volume
diskext -accepteula C:
```
**Output / parsing:** Plain-text listing of each volume's disk number, starting offset, and extent length (multipartition volumes may span disks). No CSV.
**Full reference:** `references/ms-docs/diskext.md`

## ClockRes (`clockres`)
**Purpose:** Show the system clock resolution (and the maximum timer resolution available).
**Privilege / EULA:** Standard user. Pass `-accepteula` on first run. No documented flags.
**Synopsis:**
```text
clockres
```
**Key flags:** None.
**Examples:**
```cmd
# Print the current and maximum system timer resolution
clockres -accepteula
```
**Output / parsing:** Prints maximum, minimum, and current timer-interval values (via `GetSystemTimeAdjustment`). Single-shot text output — capture stdout.
**Full reference:** `references/ms-docs/clockres.md`
