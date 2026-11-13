#!/usr/bin/env bash
# Idempotent crontab install/remove for daily report generation.

ldr_cron_marker() {
  printf '%s' "# ${CRON_TAG:-linux-daily-reporter}"
}

ldr_cron_job_line() {
  local hour minute script
  hour="$(ldr_clamp_int "${CRON_HOUR:-8}" 0 23)"
  minute="$(ldr_clamp_int "${CRON_MINUTE:-0}" 0 59)"
  script="${LDR_ROOT}/main.sh"
  printf '%s %s * * * /usr/bin/env bash %s --generate-report >> %s/cron.log 2>&1 %s\n' \
    "${minute}" "${hour}" "${script}" "${LDR_LOG_DIR}" "$(ldr_cron_marker)"
}

ldr_crontab_filtered() {
  crontab -l 2>/dev/null | grep -vF "$(ldr_cron_marker)" || true
}

ldr_cron_status() {
  if crontab -l 2>/dev/null | grep -F "$(ldr_cron_marker)" >/dev/null; then
    echo "enabled"
  else
    echo "disabled"
  fi
}

ldr_cron_show() {
  printf 'Automation status : %s\n' "$(ldr_cron_status)"
  printf 'Configured time   : %02d:%02d (local time)\n' "$(ldr_to_int "${CRON_HOUR}")" "$(ldr_to_int "${CRON_MINUTE}")"
  printf 'CRON_ENABLED      : %s\n' "${CRON_ENABLED}"
  printf '\nInstalled crontab lines for this application:\n'
  crontab -l 2>/dev/null | grep -F "$(ldr_cron_marker)" || echo "(none)"
}

ldr_cron_install() {
  local tmp hour minute
  if ! ldr_command_exists crontab; then
    ldr_log_error "crontab is not available"
    echo "Cannot install schedule: crontab command missing."
    return 1
  fi
  hour="$(ldr_clamp_int "${1:-${CRON_HOUR}}" 0 23)"
  minute="$(ldr_clamp_int "${2:-${CRON_MINUTE}}" 0 59)"
  ldr_set_config CRON_HOUR "${hour}"
  ldr_set_config CRON_MINUTE "${minute}"
  ldr_set_config CRON_ENABLED true
  CRON_HOUR="${hour}"
  CRON_MINUTE="${minute}"
  CRON_ENABLED=true
  tmp="$(ldr_tmpfile)"
  ldr_crontab_filtered >"${tmp}"
  ldr_cron_job_line >>"${tmp}"
  crontab "${tmp}"
  rm -f "${tmp}"
  ldr_log_info "Installed cron job at ${hour}:$(printf '%02d' "${minute}")"
  echo "Daily report scheduling enabled at ${hour}:$(printf '%02d' "${minute}")."
}

ldr_cron_remove() {
  local tmp
  if ! ldr_command_exists crontab; then
    echo "crontab is not available"
    return 1
  fi
  tmp="$(ldr_tmpfile)"
  ldr_crontab_filtered >"${tmp}"
  crontab "${tmp}"
  rm -f "${tmp}"
  ldr_set_config CRON_ENABLED false
  CRON_ENABLED=false
  ldr_log_info "Removed application cron job"
  echo "Daily report scheduling disabled. Other crontab entries were left unchanged."
}
