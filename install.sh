#!/usr/bin/env bash
# Dependency checks, permissions, and first-run setup.
# Does not require root.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/utils/bootstrap.sh"
ldr_bootstrap "${ROOT}"

REQUIRED_CMDS=(bash awk sed grep cut tr date uname cat mkdir chmod mktemp)
OPTIONAL_CMDS=(journalctl sqlite3 ip ping ss crontab df ps free last who uptime nproc find)

missing=()
optional_missing=()

printf '%s%s v%s installer%s\n' "${C_BOLD}" "${APP_NAME}" "${APP_VERSION}" "${C_RESET}"
printf 'Application root: %s\n\n' "${ROOT}"

for cmd in "${REQUIRED_CMDS[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    missing+=("${cmd}")
  fi
done

for cmd in "${OPTIONAL_CMDS[@]}"; do
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    optional_missing+=("${cmd}")
  fi
done

if ((${#missing[@]} > 0)); then
  printf '%sMissing required commands:%s %s\n' "${C_RED}" "${C_RESET}" "${missing[*]}"
  printf '\nInstall examples:\n'
  printf '  Debian/Ubuntu : sudo apt update && sudo apt install -y bash coreutils gawk grep sed procps iproute2 iputils-ping cron util-linux\n'
  printf '  Fedora/RHEL   : sudo dnf install -y bash coreutils gawk grep sed procps-ng iproute iputils cronie util-linux\n'
  printf '  Arch Linux    : sudo pacman -S --needed bash coreutils gawk grep sed procps-ng iproute2 iputils cronie util-linux\n'
  exit 1
fi

chmod 755 "${ROOT}/main.sh" "${ROOT}/install.sh" "${ROOT}/uninstall.sh"
find "${ROOT}/modules" "${ROOT}/utils" "${ROOT}/scheduler" "${ROOT}/tests" -type f -name '*.sh' -exec chmod 755 {} \;
chmod 600 "${ROOT}/config/settings.conf" 2>/dev/null || true
chmod 700 "${ROOT}/reports" "${ROOT}/logs" "${ROOT}/data" "${ROOT}/config" 2>/dev/null || true

touch "${ROOT}/logs/app.log" "${ROOT}/logs/cron.log"
chmod 600 "${ROOT}/logs/app.log" "${ROOT}/logs/cron.log" 2>/dev/null || true

if [[ ! -f "${ROOT}/.installed" ]]; then
  date '+%Y-%m-%d %H:%M:%S' >"${ROOT}/.installed"
  chmod 600 "${ROOT}/.installed"
fi

printf '%sRequired commands: OK%s\n' "${C_GREEN}" "${C_RESET}"
if ((${#optional_missing[@]} > 0)); then
  printf '%sOptional commands not found:%s %s\n' "${C_YELLOW}" "${C_RESET}" "${optional_missing[*]}"
  printf 'The generator still runs. Missing tools skip related sections (journald, SQLite, cron).\n'
else
  printf '%sOptional commands: OK%s\n' "${C_GREEN}" "${C_RESET}"
fi

printf '\nNext steps:\n'
printf '  ./main.sh                 # write TXT/HTML/CSV reports now\n'
printf '  ./main.sh --list          # list generated files\n'
printf '  ./main.sh --cron-install 8 0\n'
printf '  ./tests/run_tests.sh\n'
printf '\nInstall completed.\n'
ldr_log_info "Installation completed"
