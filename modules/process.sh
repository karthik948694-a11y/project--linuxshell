#!/usr/bin/env bash
# Process inventory and resource consumers.

ldr_process_count() {
  if ldr_command_exists ps; then
    ps -e --no-headers 2>/dev/null | wc -l | tr -d ' '
    return 0
  fi
  if [[ -d /proc ]]; then
    find /proc -maxdepth 1 -type d -regex '/proc/[0-9]+' | wc -l | tr -d ' '
    return 0
  fi
  echo 0
}

ldr_process_running_sample() {
  local limit="${1:-20}"
  if ! ldr_command_exists ps; then
    echo "ps is not available"
    return 1
  fi
  ps -eo pid,stat,user,pcpu,pmem,etime,comm --sort=-pcpu 2>/dev/null | awk -v lim="${limit}" 'NR<=lim+1'
}

ldr_process_summary() {
  printf 'Running processes : %s\n' "$(ldr_process_count)"
  printf '\nTop CPU consumers:\n'
  ldr_cpu_top_processes "${TOP_PROCESS_LIMIT:-8}"
  printf '\nTop memory consumers:\n'
  ldr_memory_top_processes "${TOP_PROCESS_LIMIT:-8}"
}

ldr_process_metrics_kv() {
  printf 'process_count=%s\n' "$(ldr_process_count)"
  if ldr_command_exists ps; then
    printf 'top_cpu_proc=%s\n' "$(ps -eo comm --sort=-pcpu --no-headers 2>/dev/null | awk 'NR==1{print; exit}')"
    printf 'top_mem_proc=%s\n' "$(ps -eo comm --sort=-pmem --no-headers 2>/dev/null | awk 'NR==1{print; exit}')"
  fi
}
