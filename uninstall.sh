#!/usr/bin/env bash
# Remove cron entries created by this application. Does not delete reports unless requested.

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/utils/bootstrap.sh"
ldr_bootstrap "${ROOT}"

printf '%s%s uninstall%s\n' "${C_BOLD}" "${APP_NAME}" "${C_RESET}"
printf 'This removes the scheduled cron job. Generated report files in %s are kept unless you confirm deletion.\n' "${LDR_REPORT_DIR}"

ldr_cron_remove || true
rm -f "${ROOT}/.installed"

printf 'Delete generated reports, logs, and SQLite history as well? [y/N]: '
read -r answer || true
if [[ "${answer}" =~ ^[Yy]$ ]]; then
  rm -f "${LDR_REPORT_DIR}"/daily-report-* "${LDR_LOG_DIR}"/*.log
  rm -rf "${LDR_TMP_DIR}" "${LDR_DATA_DIR}"
  mkdir -p "${LDR_REPORT_DIR}" "${LDR_LOG_DIR}" "${LDR_TMP_DIR}" "${LDR_DATA_DIR}"
  echo "Reports, logs, and history were removed."
else
  echo "Reports and logs were left in place."
fi

echo "Uninstall finished. Application files remain in ${ROOT}."
ldr_log_info "Uninstall finished"
