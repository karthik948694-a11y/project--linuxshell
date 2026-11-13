#!/usr/bin/env bash
# Security log analysis. Detection only — never blocks IPs or kills processes.

ldr_security_journal_available() {
  ldr_command_exists journalctl && journalctl --system -n 1 >/dev/null 2>&1
}

ldr_security_failed_ssh() {
  local hours="${SECURITY_LOG_HOURS:-24}"
  local auth_log
  printf 'Failed SSH / authentication events (last %s hours):\n' "${hours}"
  if ldr_security_journal_available; then
    journalctl --since "-${hours} hours" -u ssh -u sshd -u 'ssh@*' --no-pager 2>/dev/null \
      | grep -Ei 'Failed password|Invalid user|authentication failure|Failed publickey' \
      | tail -n 40 || true
    if ! journalctl --since "-${hours} hours" --no-pager 2>/dev/null \
      | grep -Ei 'Failed password|Invalid user|authentication failure' >/dev/null; then
      journalctl --since "-${hours} hours" _COMM=sshd --no-pager 2>/dev/null \
        | grep -Ei 'Failed|Invalid' | tail -n 40 || true
    fi
    return 0
  fi
  auth_log="$(ldr_auth_log_path)"
  if [[ -n "${auth_log}" ]]; then
    grep -Ei 'Failed password|Invalid user|authentication failure|Failed publickey' "${auth_log}" \
      | tail -n 40 || true
    return 0
  fi
  echo "No readable authentication log. journalctl/auth.log/secure not accessible."
  return 1
}

ldr_security_failed_counts() {
  local hours="${SECURITY_LOG_HOURS:-24}"
  local source=""
  if ldr_security_journal_available; then
    source="$(journalctl --since "-${hours} hours" --no-pager 2>/dev/null || true)"
  else
    local auth_log
    auth_log="$(ldr_auth_log_path)"
    if [[ -n "${auth_log}" ]]; then
      source="$(cat "${auth_log}" 2>/dev/null || true)"
    fi
  fi
  printf '%s\n' "${source}" | awk '
    /Failed password|Invalid user|authentication failure|Failed publickey/ {c++}
    END {print c+0}
  '
}

ldr_security_suspicious() {
  local hours="${SECURITY_LOG_HOURS:-24}"
  printf 'Suspicious authentication / sudo events:\n'
  if ldr_security_journal_available; then
    journalctl --since "-${hours} hours" --no-pager 2>/dev/null \
      | grep -Ei 'sudo:|authentication failure|BREAK-IN|Invalid user|session opened|POSSIBLE BREAK' \
      | tail -n 30 || true
    return 0
  fi
  local auth_log
  auth_log="$(ldr_auth_log_path)"
  if [[ -n "${auth_log}" ]]; then
    grep -Ei 'sudo:|authentication failure|Invalid user|session opened' "${auth_log}" | tail -n 30 || true
    return 0
  fi
  echo "No authentication source available."
}

ldr_security_errors() {
  local hours="${SECURITY_LOG_HOURS:-24}"
  printf 'Recent system errors (priority err and worse):\n'
  if ldr_security_journal_available; then
    journalctl -p err..alert --since "-${hours} hours" --no-pager 2>/dev/null | tail -n 40 || true
    return 0
  fi
  local syslog
  syslog="$(ldr_first_existing /var/log/syslog /var/log/messages || true)"
  if [[ -n "${syslog}" ]]; then
    grep -Ei 'error|fail|fatal|panic' "${syslog}" | tail -n 40 || true
    return 0
  fi
  echo "System error logs are not readable without additional permissions."
}

ldr_security_logins() {
  printf 'Recent login history:\n'
  if ldr_command_exists last; then
    last -n 15 -a 2>/dev/null || last -n 15 2>/dev/null || true
  else
    echo "last is not available"
  fi
  if ldr_command_exists lastb; then
    printf '\nFailed login database (lastb), if readable:\n'
    lastb -n 10 2>/dev/null || echo "lastb is not readable without additional privileges."
  fi
  printf '\nCurrently logged-in users:\n'
  if ldr_command_exists who; then
    who 2>/dev/null || true
  elif ldr_command_exists w; then
    w 2>/dev/null || true
  else
    echo "who/w not available"
  fi
}

ldr_security_unusual() {
  local failed threshold="${FAILED_LOGIN_UNUSUAL:-8}"
  failed="$(ldr_security_failed_counts)"
  printf 'Failed authentication events counted: %s\n' "${failed}"
  if (( failed >= threshold )); then
    printf 'UNUSUAL ACTIVITY: failed logins (%s) exceed review threshold (%s).\n' "${failed}" "${threshold}"
    printf 'This is an informational finding only. No IPs were blocked.\n'
  else
    printf 'Failed login volume is within the configured review threshold (%s).\n' "${threshold}"
  fi
}

ldr_security_summary() {
  ldr_security_failed_ssh
  printf '\n'
  ldr_security_suspicious
  printf '\n'
  ldr_security_errors
  printf '\n'
  ldr_security_logins
  printf '\n'
  ldr_security_unusual
}

ldr_security_metrics_kv() {
  printf 'failed_auth_count=%s\n' "$(ldr_security_failed_counts)"
}
