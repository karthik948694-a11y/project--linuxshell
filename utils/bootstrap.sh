#!/usr/bin/env bash
# Resolve application root and source all libraries.

ldr_resolve_root() {
  local source_path="${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}"
  local dir
  dir="$(cd "$(dirname "${source_path}")" && pwd)"
  if [[ -f "${dir}/main.sh" ]]; then
    printf '%s' "${dir}"
  elif [[ -f "${dir}/../main.sh" ]]; then
    (cd "${dir}/.." && pwd)
  else
    printf '%s' "${dir}"
  fi
}

ldr_bootstrap() {
  local root="${1:-}"
  if [[ -z "${root}" ]]; then
    root="$(ldr_resolve_root)"
  fi
  export LDR_ROOT="${root}"
  export LDR_CONFIG_FILE="${LDR_ROOT}/config/settings.conf"
  export LDR_REPORT_DIR="${LDR_ROOT}/reports"
  export LDR_LOG_DIR="${LDR_ROOT}/logs"
  export LDR_TMP_DIR="${LDR_ROOT}/logs/tmp"
  export LDR_DATA_DIR="${LDR_ROOT}/data"

  mkdir -p "${LDR_REPORT_DIR}" "${LDR_LOG_DIR}" "${LDR_TMP_DIR}" "${LDR_DATA_DIR}"
  chmod 700 "${LDR_REPORT_DIR}" "${LDR_LOG_DIR}" "${LDR_TMP_DIR}" "${LDR_DATA_DIR}" 2>/dev/null || true

  umask 077

  # shellcheck disable=SC1090
  source "${LDR_CONFIG_FILE}"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/utils/colors.sh"
  ldr_init_colors
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/utils/logger.sh"
  ldr_log_init
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/utils/helpers.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/cpu.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/memory.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/disk.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/network.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/process.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/security.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/sqlite.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/modules/report.sh"
  # shellcheck disable=SC1091
  source "${LDR_ROOT}/scheduler/cron_manager.sh"
}
