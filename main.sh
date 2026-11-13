#!/usr/bin/env bash
# Linux Daily Reporter — generate structured daily reports to files.
#
#   ./main.sh
#   ./main.sh --generate-report
#   ./main.sh --list
#   ./main.sh --cron-install 8 0
#   ./main.sh --cron-remove
#   ./main.sh --help

set -u

LDR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck disable=SC1091
source "${LDR_ROOT}/utils/bootstrap.sh"
ldr_bootstrap "${LDR_ROOT}"

ldr_usage() {
  cat <<EOF
${APP_NAME} v${APP_VERSION}

Generates structured daily system reports as files (TXT, HTML, CSV).
There is no interactive dashboard.

Usage:
  ./main.sh                      Generate reports now (default)
  ./main.sh --generate-report    Same as above (used by cron)
  ./main.sh --list               List existing report files
  ./main.sh --cron-install [H] [M]
                                 Schedule daily generation (default ${CRON_HOUR}:${CRON_MINUTE})
  ./main.sh --cron-remove        Remove this application's cron job
  ./main.sh --cron-status        Show cron status
  ./main.sh --help               Show this help

Reports are written under:
  ${LDR_REPORT_DIR}

Formats are set in config/settings.conf (REPORT_FORMATS).
Existing report files are never overwritten.
EOF
}

case "${1:-}" in
  --help|-h)
    ldr_usage
    ;;
  --list)
    ldr_list_reports
    ;;
  --cron-install)
    ldr_cron_install "${2:-${CRON_HOUR}}" "${3:-${CRON_MINUTE}}"
    ldr_cron_show
    ;;
  --cron-remove)
    ldr_cron_remove
    ;;
  --cron-status)
    ldr_cron_show
    ;;
  --generate-report|"")
    ldr_generate_daily_report
    ldr_rotate_logs
    ldr_rotate_reports
    ;;
  *)
    echo "Unknown option: $1"
    ldr_usage
    exit 2
    ;;
esac
