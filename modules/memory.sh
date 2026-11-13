#!/usr/bin/env bash
# Memory and swap monitoring from /proc/meminfo.

ldr_mem_field() {
  local key="$1"
  awk -v k="${key}" '$1==k {print $2; exit}' /proc/meminfo 2>/dev/null
}

ldr_memory_stats() {
  local total available used percent swap_total swap_free swap_used swap_pct
  if [[ ! -r /proc/meminfo ]]; then
    echo "Memory information is unavailable (/proc/meminfo missing)."
    return 1
  fi
  total="$(ldr_mem_field MemTotal:)"
  available="$(ldr_mem_field MemAvailable:)"
  if [[ -z "${available}" ]]; then
    available="$(awk '/^MemFree:|^Buffers:|^Cached:/ {s+=$2} END{print s+0}' /proc/meminfo)"
  fi
  total="$(ldr_to_int "${total}")"
  available="$(ldr_to_int "${available}")"
  used=$((total - available))
  if (( total > 0 )); then
    percent=$((used * 100 / total))
  else
    percent=0
  fi
  swap_total="$(ldr_to_int "$(ldr_mem_field SwapTotal:)")"
  swap_free="$(ldr_to_int "$(ldr_mem_field SwapFree:)")"
  swap_used=$((swap_total - swap_free))
  if (( swap_total > 0 )); then
    swap_pct=$((swap_used * 100 / swap_total))
  else
    swap_pct=0
  fi
  cat <<EOF
Total RAM     : $(ldr_kib_to_human "${total}")
Used RAM      : $(ldr_kib_to_human "${used}")
Available RAM : $(ldr_kib_to_human "${available}")
RAM usage     : $(ldr_bar "${percent}")
Swap total    : $(ldr_kib_to_human "${swap_total}")
Swap used     : $(ldr_kib_to_human "${swap_used}")
Swap usage    : $(ldr_bar "${swap_pct}")
EOF
  ldr_warn_if_threshold "Memory utilization" "${percent}" "${MEM_WARN_THRESHOLD}" || true
}

ldr_memory_percent() {
  local total available used
  total="$(ldr_to_int "$(ldr_mem_field MemTotal:)")"
  available="$(ldr_to_int "$(ldr_mem_field MemAvailable:)")"
  if (( available == 0 )); then
    available="$(awk '/^MemFree:|^Buffers:|^Cached:/ {s+=$2} END{print s+0}' /proc/meminfo)"
    available="$(ldr_to_int "${available}")"
  fi
  used=$((total - available))
  if (( total > 0 )); then
    echo $((used * 100 / total))
  else
    echo 0
  fi
}

ldr_memory_metrics_kv() {
  local total available used percent swap_total swap_free swap_used
  total="$(ldr_to_int "$(ldr_mem_field MemTotal:)")"
  available="$(ldr_to_int "$(ldr_mem_field MemAvailable:)")"
  used=$((total - available))
  if (( total > 0 )); then percent=$((used * 100 / total)); else percent=0; fi
  swap_total="$(ldr_to_int "$(ldr_mem_field SwapTotal:)")"
  swap_free="$(ldr_to_int "$(ldr_mem_field SwapFree:)")"
  swap_used=$((swap_total - swap_free))
  printf 'mem_total_kib=%s\n' "${total}"
  printf 'mem_used_kib=%s\n' "${used}"
  printf 'mem_available_kib=%s\n' "${available}"
  printf 'mem_percent=%s\n' "${percent}"
  printf 'swap_total_kib=%s\n' "${swap_total}"
  printf 'swap_used_kib=%s\n' "${swap_used}"
}

ldr_memory_top_processes() {
  local limit="${1:-${TOP_PROCESS_LIMIT:-8}}"
  if ! ldr_command_exists ps; then
    echo "ps is not available"
    return 1
  fi
  ps -eo pid,user,pmem,pcpu,rss,comm --sort=-pmem 2>/dev/null | awk -v lim="${limit}" '
    NR==1 { printf "%-8s %-12s %6s %6s %10s  %s\n", "PID", "USER", "%MEM", "%CPU", "RSS", "COMMAND"; next }
    NR<=lim+1 { printf "%-8s %-12s %6s %6s %10s  %s\n", $1, $2, $3, $4, $5, $6 }
  '
}
