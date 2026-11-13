#!/usr/bin/env bash
# Daily report generation in TXT, HTML, and CSV. Never overwrites existing files.

ldr_collect_report_data() {
  local cpu mem disk health os_line
  cpu="$(ldr_cpu_utilization)"
  mem="$(ldr_memory_percent)"
  disk="$(ldr_disk_percent)"
  health="$(ldr_health_from_metrics "${cpu}" "${mem}" "${disk}")"
  os_line="$(ldr_read_os_release)"
  REPORT_TS="$(date '+%Y-%m-%d %H:%M:%S %z')"
  REPORT_STAMP="$(date '+%Y%m%d-%H%M%S')"
  REPORT_HOST="$(ldr_hostname)"
  REPORT_KERNEL="$(ldr_kernel)"
  REPORT_OS="${os_line%%|*}"
  REPORT_UPTIME="$(ldr_uptime_pretty | tr '\n' ' ')"
  REPORT_CPU="${cpu}"
  REPORT_MEM="${mem}"
  REPORT_DISK="${disk}"
  REPORT_HEALTH="${health}"
  REPORT_LOAD="$(ldr_loadavg)"
  REPORT_CORES="$(ldr_nproc)"
  REPORT_PROCS="$(ldr_process_count)"
  REPORT_FAILED_AUTH="$(ldr_security_failed_counts)"
}

ldr_unique_path() {
  local path="$1" n=1 candidate="${path}"
  while [[ -e "${candidate}" ]]; do
    candidate="${path%.${path##*.}}.${n}.${path##*.}"
    n=$((n + 1))
  done
  printf '%s' "${candidate}"
}

ldr_threshold_flag() {
  local value="$1" threshold="$2"
  value="$(ldr_to_int "${value}")"
  threshold="$(ldr_to_int "${threshold}")"
  if (( value >= threshold )); then
    printf 'EXCEEDED'
  else
    printf 'OK'
  fi
}

ldr_write_txt_report() {
  local file="$1"
  {
    printf '================================================================================\n'
    printf 'DAILY SYSTEM REPORT\n'
    printf '%s v%s\n' "${APP_NAME}" "${APP_VERSION}"
    printf '================================================================================\n'
    printf '\n'
    printf '1. HEADER\n'
    printf '--------------------------------------------------------------------------------\n'
    printf 'Generated        : %s\n' "${REPORT_TS}"
    printf 'Hostname         : %s\n' "${REPORT_HOST}"
    printf 'Distribution     : %s\n' "${REPORT_OS}"
    printf 'Kernel           : %s\n' "${REPORT_KERNEL}"
    printf 'Uptime           : %s\n' "${REPORT_UPTIME}"
    printf '\n'
    printf '2. HEALTH SUMMARY\n'
    printf '--------------------------------------------------------------------------------\n'
    printf 'Overall health   : %s\n' "${REPORT_HEALTH}"
    printf 'CPU              : %3s%%  %-24s  threshold %s%%  [%s]\n' \
      "${REPORT_CPU}" "$(ldr_bar "${REPORT_CPU}")" "${CPU_WARN_THRESHOLD}" \
      "$(ldr_threshold_flag "${REPORT_CPU}" "${CPU_WARN_THRESHOLD}")"
    printf 'Memory           : %3s%%  %-24s  threshold %s%%  [%s]\n' \
      "${REPORT_MEM}" "$(ldr_bar "${REPORT_MEM}")" "${MEM_WARN_THRESHOLD}" \
      "$(ldr_threshold_flag "${REPORT_MEM}" "${MEM_WARN_THRESHOLD}")"
    printf 'Disk %-12s: %3s%%  %-24s  threshold %s%%  [%s]\n' \
      "(${DISK_WARN_PATH})" "${REPORT_DISK}" "$(ldr_bar "${REPORT_DISK}")" "${DISK_WARN_THRESHOLD}" \
      "$(ldr_threshold_flag "${REPORT_DISK}" "${DISK_WARN_THRESHOLD}")"
    printf 'Load average     : %s  (%s cores)\n' "${REPORT_LOAD}" "${REPORT_CORES}"
    printf 'Process count    : %s\n' "${REPORT_PROCS}"
    printf 'Failed auth (24h): %s  (review threshold %s)\n' "${REPORT_FAILED_AUTH}" "${FAILED_LOGIN_UNUSUAL}"
    printf '\n'
    printf '3. SYSTEM INFORMATION\n'
    printf '--------------------------------------------------------------------------------\n'
    ldr_cpu_info_text
    printf '\n'
    printf '4. CPU STATISTICS\n'
    printf '--------------------------------------------------------------------------------\n'
    printf 'CPU utilization  : %s%% (warning at %s%%)\n' "${REPORT_CPU}" "${CPU_WARN_THRESHOLD}"
    printf '\nTop CPU-consuming processes:\n'
    ldr_cpu_top_processes
    printf '\n'
    printf '5. MEMORY STATISTICS\n'
    printf '--------------------------------------------------------------------------------\n'
    ldr_memory_stats
    printf '\nTop memory-consuming processes:\n'
    ldr_memory_top_processes
    printf '\n'
    printf '6. DISK STATISTICS\n'
    printf '--------------------------------------------------------------------------------\n'
    ldr_disk_summary
    printf '\nInode usage (entries at or above 70%%):\n'
    ldr_disk_inode_usage
    printf '\n'
    printf '7. NETWORK STATISTICS\n'
    printf '--------------------------------------------------------------------------------\n'
    ldr_network_summary
    printf '\nListening sockets (sample):\n'
    ldr_net_listening
    printf '\n'
    printf '8. PROCESS SUMMARY\n'
    printf '--------------------------------------------------------------------------------\n'
    ldr_process_summary
    printf '\n'
    printf '9. SECURITY EVENTS AND SYSTEM ERRORS\n'
    printf '--------------------------------------------------------------------------------\n'
    ldr_security_summary
    printf '\n'
    printf '10. OVERALL ASSESSMENT\n'
    printf '--------------------------------------------------------------------------------\n'
    printf 'Status           : %s\n' "${REPORT_HEALTH}"
    printf 'CPU %s%% | Memory %s%% | Disk %s%% | Failed auth events %s\n' \
      "${REPORT_CPU}" "${REPORT_MEM}" "${REPORT_DISK}" "${REPORT_FAILED_AUTH}"
    if [[ "${REPORT_HEALTH}" == "HEALTHY" ]]; then
      printf 'Assessment       : Resource usage is within configured thresholds.\n'
    else
      printf 'Assessment       : One or more thresholds were exceeded. Review sections 2, 4, 5, and 6.\n'
    fi
    printf 'Notes            : Informational monitoring only. No IPs were blocked and no processes were terminated.\n'
    printf '\nEnd of report.\n'
  } >"${file}"
}

ldr_html_metric_card() {
  local title="$1" value="$2" sub="$3"
  cat <<EOF
<article class="card">
  <h3>$(ldr_html_escape "${title}")</h3>
  <p class="metric">$(ldr_html_escape "${value}")</p>
  <p class="sub">$(ldr_html_escape "${sub}")</p>
</article>
EOF
}

ldr_write_html_report() {
  local file="$1"
  local cpu_block mem_block disk_block net_block proc_block sec_block
  cpu_block="$(ldr_cpu_info_text; printf '\nTop CPU-consuming processes:\n'; ldr_cpu_top_processes)"
  mem_block="$(ldr_memory_stats; printf '\nTop memory-consuming processes:\n'; ldr_memory_top_processes)"
  disk_block="$(ldr_disk_summary; printf '\nInode usage:\n'; ldr_disk_inode_usage)"
  net_block="$(ldr_network_summary; printf '\nListening sockets:\n'; ldr_net_listening)"
  proc_block="$(ldr_process_summary)"
  sec_block="$(ldr_security_summary)"

  {
    cat <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>$(ldr_html_escape "${APP_NAME}") — $(ldr_html_escape "${REPORT_HOST}") $(ldr_html_escape "${REPORT_TS}")</title>
  <style>
    :root { --bg:#0b1220; --panel:#141c2e; --text:#e8eefc; --muted:#9aa8c7; --accent:#3ee0c5; --warn:#f5c542; --crit:#ff6b6b; --ok:#4ade80; }
    * { box-sizing: border-box; }
    body { margin:0; font-family:"Segoe UI",system-ui,sans-serif; background:radial-gradient(circle at top,#1a2744,var(--bg) 55%); color:var(--text); }
    header, section, footer { padding: 1.2rem 4vw; }
    header { border-bottom:1px solid #243152; }
    header h1 { margin:0 0 .35rem; font-size:1.6rem; }
    header p { margin:.2rem 0; color:var(--muted); }
    .health { display:inline-block; margin-top:.8rem; padding:.25rem .7rem; border-radius:999px; font-weight:700; }
    .HEALTHY { background:#14532d; color:var(--ok); }
    .WARNING { background:#4a3b12; color:var(--warn); }
    .CRITICAL { background:#4a1515; color:var(--crit); }
    .grid { display:grid; grid-template-columns:repeat(auto-fit,minmax(180px,1fr)); gap:1rem; padding:1.2rem 4vw; }
    .card { background:var(--panel); border:1px solid #2a3a60; border-radius:16px; padding:1rem; }
    .metric { font-size:1.8rem; margin:.2rem 0; color:var(--accent); }
    .sub { margin:0; color:var(--muted); font-size:.9rem; }
    pre { background:#0a1020; border:1px solid #223056; border-radius:12px; padding:1rem; overflow:auto; line-height:1.45; color:#d7e3ff; white-space:pre-wrap; }
    h2 { margin:0 0 .6rem; font-size:1.1rem; letter-spacing:.04em; text-transform:uppercase; color:var(--muted); }
    footer { color:var(--muted); font-size:.85rem; }
  </style>
</head>
<body>
  <header>
    <h1>$(ldr_html_escape "${APP_NAME}") v$(ldr_html_escape "${APP_VERSION}")</h1>
    <p>Daily system report for $(ldr_html_escape "${REPORT_HOST}") · $(ldr_html_escape "${REPORT_TS}")</p>
    <p>$(ldr_html_escape "${REPORT_OS}") · kernel $(ldr_html_escape "${REPORT_KERNEL}") · $(ldr_html_escape "${REPORT_UPTIME}")</p>
    <span class="health ${REPORT_HEALTH}">Health: $(ldr_html_escape "${REPORT_HEALTH}")</span>
  </header>
  <div class="grid">
    $(ldr_html_metric_card "CPU" "${REPORT_CPU}%" "Warning at ${CPU_WARN_THRESHOLD}% · $(ldr_threshold_flag "${REPORT_CPU}" "${CPU_WARN_THRESHOLD}")")
    $(ldr_html_metric_card "Memory" "${REPORT_MEM}%" "Warning at ${MEM_WARN_THRESHOLD}% · $(ldr_threshold_flag "${REPORT_MEM}" "${MEM_WARN_THRESHOLD}")")
    $(ldr_html_metric_card "Disk ${DISK_WARN_PATH}" "${REPORT_DISK}%" "Warning at ${DISK_WARN_THRESHOLD}% · $(ldr_threshold_flag "${REPORT_DISK}" "${DISK_WARN_THRESHOLD}")")
    $(ldr_html_metric_card "Processes" "${REPORT_PROCS}" "Running process count")
    $(ldr_html_metric_card "Failed auth" "${REPORT_FAILED_AUTH}" "Last ${SECURITY_LOG_HOURS} hours")
    $(ldr_html_metric_card "Load" "${REPORT_LOAD}" "${REPORT_CORES} cores")
  </div>
EOF
    printf '<section><h2>1. CPU</h2><pre>'
    printf '%s\n' "${cpu_block}" | ldr_html_escape_stream
    printf '</pre></section>\n'
    printf '<section><h2>2. Memory</h2><pre>'
    printf '%s\n' "${mem_block}" | ldr_html_escape_stream
    printf '</pre></section>\n'
    printf '<section><h2>3. Disk</h2><pre>'
    printf '%s\n' "${disk_block}" | ldr_html_escape_stream
    printf '</pre></section>\n'
    printf '<section><h2>4. Network</h2><pre>'
    printf '%s\n' "${net_block}" | ldr_html_escape_stream
    printf '</pre></section>\n'
    printf '<section><h2>5. Processes</h2><pre>'
    printf '%s\n' "${proc_block}" | ldr_html_escape_stream
    printf '</pre></section>\n'
    printf '<section><h2>6. Security and errors</h2><pre>'
    printf '%s\n' "${sec_block}" | ldr_html_escape_stream
    printf '</pre></section>\n'
    cat <<EOF
  <footer>Generated by $(ldr_html_escape "${APP_NAME}"). Informational monitoring only — no automated blocking.</footer>
</body>
</html>
EOF
  } >"${file}"
}

ldr_write_csv_report() {
  local file="$1"
  {
    printf 'section,key,value\n'
    printf 'header,generated_at,%s\n' "$(ldr_csv_escape "${REPORT_TS}")"
    printf 'header,hostname,%s\n' "$(ldr_csv_escape "${REPORT_HOST}")"
    printf 'header,os,%s\n' "$(ldr_csv_escape "${REPORT_OS}")"
    printf 'header,kernel,%s\n' "$(ldr_csv_escape "${REPORT_KERNEL}")"
    printf 'header,uptime,%s\n' "$(ldr_csv_escape "${REPORT_UPTIME}")"
    printf 'health,overall,%s\n' "$(ldr_csv_escape "${REPORT_HEALTH}")"
    printf 'health,cpu_flag,%s\n' "$(ldr_threshold_flag "${REPORT_CPU}" "${CPU_WARN_THRESHOLD}")"
    printf 'health,memory_flag,%s\n' "$(ldr_threshold_flag "${REPORT_MEM}" "${MEM_WARN_THRESHOLD}")"
    printf 'health,disk_flag,%s\n' "$(ldr_threshold_flag "${REPORT_DISK}" "${DISK_WARN_THRESHOLD}")"
    printf 'cpu,percent,%s\n' "${REPORT_CPU}"
    printf 'cpu,threshold,%s\n' "${CPU_WARN_THRESHOLD}"
    printf 'cpu,load,%s\n' "$(ldr_csv_escape "${REPORT_LOAD}")"
    printf 'cpu,cores,%s\n' "${REPORT_CORES}"
    printf 'memory,percent,%s\n' "${REPORT_MEM}"
    printf 'memory,threshold,%s\n' "${MEM_WARN_THRESHOLD}"
    printf 'disk,path,%s\n' "$(ldr_csv_escape "${DISK_WARN_PATH}")"
    printf 'disk,percent,%s\n' "${REPORT_DISK}"
    printf 'disk,threshold,%s\n' "${DISK_WARN_THRESHOLD}"
    printf 'process,count,%s\n' "${REPORT_PROCS}"
    printf 'security,failed_auth,%s\n' "${REPORT_FAILED_AUTH}"
    printf 'security,unusual_threshold,%s\n' "${FAILED_LOGIN_UNUSUAL}"
    ldr_memory_metrics_kv | awk -F= '{printf "memory,%s,%s\n", $1, $2}'
    ldr_disk_metrics_kv | awk -F= '{printf "disk,%s,%s\n", $1, $2}'
    ldr_network_metrics_kv | awk -F= '{printf "network,%s,%s\n", $1, $2}'
  } >"${file}"
}

ldr_generate_daily_report() {
  local formats="${1:-${REPORT_FORMATS}}"
  local txt_path="" html_path="" csv_path=""
  ldr_safe_mkdir "${LDR_REPORT_DIR}"
  ldr_collect_report_data
  ldr_log_info "Generating daily report stamp=${REPORT_STAMP} health=${REPORT_HEALTH}"

  if [[ " ${formats} " == *" txt "* ]]; then
    txt_path="$(ldr_unique_path "${LDR_REPORT_DIR}/daily-report-${REPORT_STAMP}.txt")"
    ldr_write_txt_report "${txt_path}"
    chmod 600 "${txt_path}" 2>/dev/null || true
  fi
  if [[ " ${formats} " == *" html "* ]]; then
    html_path="$(ldr_unique_path "${LDR_REPORT_DIR}/daily-report-${REPORT_STAMP}.html")"
    ldr_write_html_report "${html_path}"
    chmod 600 "${html_path}" 2>/dev/null || true
  fi
  if [[ " ${formats} " == *" csv "* ]]; then
    csv_path="$(ldr_unique_path "${LDR_REPORT_DIR}/daily-report-${REPORT_STAMP}.csv")"
    ldr_write_csv_report "${csv_path}"
    chmod 600 "${csv_path}" 2>/dev/null || true
  fi

  ldr_sqlite_init
  ldr_sqlite_insert_report "${REPORT_TS}" "${REPORT_HOST}" "${REPORT_HEALTH}" \
    "${REPORT_CPU}" "${REPORT_MEM}" "${REPORT_DISK}" \
    "${txt_path}" "${html_path}" "${csv_path}"

  {
    echo "Report generated at ${REPORT_TS}"
    echo "Health: ${REPORT_HEALTH}"
    [[ -n "${txt_path}" ]] && echo "TXT : ${txt_path}"
    [[ -n "${html_path}" ]] && echo "HTML: ${html_path}"
    [[ -n "${csv_path}" ]] && echo "CSV : ${csv_path}"
  }
  ldr_log_info "Report complete txt=${txt_path} html=${html_path} csv=${csv_path}"
}
