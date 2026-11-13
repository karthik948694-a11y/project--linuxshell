#!/usr/bin/env bash
# CPU monitoring: utilization, load, top processes, hardware info.

ldr_cpu_sample_idle() {
  awk '/^cpu / {print $5, $2+$3+$4+$5+$6+$7+$8+$9+$10+$11}' /proc/stat 2>/dev/null
}

ldr_cpu_utilization() {
  local sample_secs="${CPU_SAMPLE_SECONDS:-1}"
  local idle1 total1 idle2 total2
  if [[ ! -r /proc/stat ]]; then
    echo "0"
    return 1
  fi
  read -r idle1 total1 < <(ldr_cpu_sample_idle)
  sleep "${sample_secs}"
  read -r idle2 total2 < <(ldr_cpu_sample_idle)
  awk -v i1="${idle1}" -v t1="${total1}" -v i2="${idle2}" -v t2="${total2}" 'BEGIN {
    di=i2-i1; dt=t2-t1
    if (dt<=0) { print 0; exit }
    u=(1-di/dt)*100
    if (u<0) u=0
    if (u>100) u=100
    printf "%.0f", u
  }'
}

ldr_cpu_info_text() {
  local model cores mhz
  if [[ -r /proc/cpuinfo ]]; then
    model="$(awk -F': ' '/model name/ {print $2; exit}' /proc/cpuinfo)"
    cores="$(grep -c '^processor' /proc/cpuinfo)"
    mhz="$(awk -F': ' '/cpu MHz/ {print $2; exit}' /proc/cpuinfo)"
  fi
  model="${model:-Unknown CPU}"
  cores="${cores:-$(ldr_nproc)}"
  cat <<EOF
CPU model     : ${model}
Logical cores : ${cores}
CPU MHz       : ${mhz:-n/a}
Architecture  : $(uname -m 2>/dev/null || echo n/a)
Load average  : $(ldr_loadavg)
EOF
}

ldr_cpu_top_processes() {
  local limit="${1:-${TOP_PROCESS_LIMIT:-8}}"
  if ! ldr_command_exists ps; then
    echo "ps is not available"
    return 1
  fi
  ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu 2>/dev/null | awk -v lim="${limit}" '
    NR==1 { printf "%-8s %-12s %6s %6s  %s\n", "PID", "USER", "%CPU", "%MEM", "COMMAND"; next }
    NR<=lim+1 { printf "%-8s %-12s %6s %6s  %s\n", $1, $2, $3, $4, $5 }
  '
}

ldr_cpu_summary_line() {
  local util load
  util="$(ldr_cpu_utilization)"
  load="$(ldr_loadavg)"
  printf 'CPU %s%% | load %s' "${util}" "${load}"
}

ldr_cpu_metrics_kv() {
  local util
  util="$(ldr_cpu_utilization)"
  printf 'cpu_percent=%s\n' "${util}"
  printf 'load_avg=%s\n' "$(ldr_loadavg)"
  printf 'cpu_cores=%s\n' "$(ldr_nproc)"
}
