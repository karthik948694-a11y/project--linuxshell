#!/usr/bin/env bash
# Application logger. Writes to logs/app.log and stderr for errors.

ldr_log_init() {
  mkdir -p "${LDR_LOG_DIR}"
  LDR_LOG_FILE="${LDR_LOG_DIR}/app.log"
  touch "${LDR_LOG_FILE}"
  chmod 600 "${LDR_LOG_FILE}" 2>/dev/null || true
}

ldr_log_level_num() {
  case "${1:-INFO}" in
    DEBUG) echo 10 ;;
    INFO) echo 20 ;;
    WARN) echo 30 ;;
    ERROR) echo 40 ;;
    *) echo 20 ;;
  esac
}

ldr_log() {
  local level="${1:-INFO}"
  shift || true
  local message="$*"
  local now configured current
  configured="$(ldr_log_level_num "${LOG_LEVEL:-INFO}")"
  current="$(ldr_log_level_num "${level}")"
  if (( current < configured )); then
    return 0
  fi
  now="$(date '+%Y-%m-%d %H:%M:%S')"
  printf '[%s] [%s] %s\n' "${now}" "${level}" "${message}" >>"${LDR_LOG_FILE:-/dev/null}"
  if [[ "${level}" == "ERROR" || "${level}" == "WARN" ]]; then
    printf '%s[%s] %s%s\n' "${C_YELLOW:-}" "${level}" "${message}" "${C_RESET:-}" >&2
  fi
}

ldr_log_debug() { ldr_log DEBUG "$*"; }
ldr_log_info() { ldr_log INFO "$*"; }
ldr_log_warn() { ldr_log WARN "$*"; }
ldr_log_error() { ldr_log ERROR "$*"; }

ldr_rotate_logs() {
  local days="${LOG_RETENTION_DAYS:-30}"
  find "${LDR_LOG_DIR}" -type f -name '*.log' -mtime "+${days}" -delete 2>/dev/null || true
}
