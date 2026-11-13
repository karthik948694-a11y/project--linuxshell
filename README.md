# Linux Daily Reporter

Automated Linux system monitoring that writes a structured daily report to files. There is no interactive dashboard. Run the generator once, or schedule it with cron.

**Version:** 1.3.0  
**Language:** Bash (plus standard Linux commands)

---

## What it does

On each run the application collects host metrics and writes timestamped files under `reports/`:

| Format | File name |
|--------|-----------|
| TXT | `daily-report-YYYYMMDD-HHMMSS.txt` |
| HTML | `daily-report-YYYYMMDD-HHMMSS.html` |
| CSV | `daily-report-YYYYMMDD-HHMMSS.csv` |

Each report is organized into numbered sections:

1. Header (host, OS, kernel, uptime, timestamp)
2. Health summary (CPU / memory / disk vs thresholds)
3. System information
4. CPU statistics and top processes
5. Memory statistics and top processes
6. Disk and partition usage
7. Network interfaces, traffic, connectivity
8. Process summary
9. Security events and system errors
10. Overall assessment

Existing files are never overwritten. A numeric suffix is added if a name already exists.

---

## Project layout

```
Automated-daily-report/
├── main.sh
├── install.sh
├── uninstall.sh
├── config/settings.conf
├── modules/          cpu, memory, disk, network, process, security, report, sqlite
├── scheduler/cron_manager.sh
├── utils/            bootstrap, helpers, logger, colors
├── reports/          generated output
├── logs/
├── tests/run_tests.sh
└── docs/sample-daily-report.txt
```

---

## Dependencies

Required: `bash`, `awk`, `sed`, `grep`, coreutils.

Recommended: `procps`, `iproute2`, `iputils-ping`, `cron`/`cronie`, `util-linux`.

Optional: `journalctl`, `sqlite3`.

Debian / Ubuntu:

```bash
sudo apt update
sudo apt install -y bash coreutils gawk grep sed procps iproute2 iputils-ping cron util-linux
```

Fedora / RHEL:

```bash
sudo dnf install -y bash coreutils gawk grep sed procps-ng iproute iputils cronie util-linux
```

Arch Linux:

```bash
sudo pacman -S --needed bash coreutils gawk grep sed procps-ng iproute2 iputils cronie util-linux
```

Run this project on Linux (native, VM, or WSL2). Windows Explorer can hold the source; generation needs `/proc` and Linux commands.

---

## Installation

```bash
cd Automated-daily-report
sed -i 's/\r$//' install.sh uninstall.sh main.sh tests/run_tests.sh \
  utils/*.sh modules/*.sh scheduler/*.sh
chmod +x install.sh uninstall.sh main.sh tests/run_tests.sh
./install.sh
```

Root is not required.

---

## Generate reports

```bash
./main.sh
```

That is the same as `./main.sh --generate-report`. Paths of the new files are printed:

```
Report generated at 2026-11-09 20:00:01 +0530
Health: WARNING
TXT : .../reports/daily-report-20261109-200001.txt
HTML: .../reports/daily-report-20261109-200001.html
CSV : .../reports/daily-report-20261109-200001.csv
```

List previous files:

```bash
./main.sh --list
```

Open a report:

```bash
less reports/daily-report-*.txt
xdg-open reports/daily-report-*.html   # optional
```

A static example is in [`docs/sample-daily-report.txt`](docs/sample-daily-report.txt).

---

## Daily automation (cron)

```bash
./main.sh --cron-install 8 0    # every day at 08:00 local time
./main.sh --cron-status
./main.sh --cron-remove
```

Installed line (example):

```
0 8 * * * /usr/bin/env bash /home/student/Automated-daily-report/main.sh --generate-report >> /home/student/Automated-daily-report/logs/cron.log 2>&1 # linux-daily-reporter
```

Install and remove are idempotent and only touch lines tagged `# linux-daily-reporter`.

---

## Configuration

Edit `config/settings.conf`:

| Key | Default | Meaning |
|-----|---------|---------|
| `REPORT_FORMATS` | `txt html csv` | Which files to write |
| `CPU_WARN_THRESHOLD` | 80 | CPU warning percent |
| `MEM_WARN_THRESHOLD` | 85 | Memory warning percent |
| `DISK_WARN_THRESHOLD` | 90 | Disk warning percent |
| `DISK_WARN_PATH` | `/` | Filesystem for the primary disk check |
| `PING_TARGET` | `8.8.8.8` | Connectivity probe |
| `FAILED_LOGIN_UNUSUAL` | 8 | Failed-auth review threshold |
| `SQLITE_ENABLED` | `false` | Optional metadata store |

---

## Testing

```bash
./install.sh
./tests/run_tests.sh
./main.sh
./main.sh --list
ls -l reports/
```

---

## Troubleshooting

| Symptom | Action |
|---------|--------|
| `bash^M: bad interpreter` | `sed -i 's/\r$//' *.sh utils/*.sh modules/*.sh scheduler/*.sh tests/*.sh` |
| Empty CPU/disk values | Run on Linux so `/proc` and `df` exist |
| Sparse security section | Need read access to `journalctl` or `/var/log/auth.log` |
| Cron did not run | `crontab -l` and `tail logs/cron.log` |
| Ping failed | Change `PING_TARGET` or allow ICMP |

Security checks are detection-only. The tool does not block IPs or kill processes.

---

## Uninstall

```bash
./uninstall.sh
```

Removes the cron tag. You can keep or delete generated reports when prompted.
