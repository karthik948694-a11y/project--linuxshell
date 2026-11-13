#!/usr/bin/env bash
# Disk and partition monitoring.

ldr_disk_percent() {
  local path="${DISK_WARN_PATH:-/}"
  if ! ldr_command_exists df; then
    echo 0
    return 1
  fi
  df -P "${path}" 2>/dev/null | awk 'NR==2 {gsub(/%/,"",$5); print $5+0}'
}

ldr_disk_partitions() {
  if ! ldr_command_exists df; then
    echo "df is not available"
    return 1
  fi
  df -hTP -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -hP
}

ldr_disk_inode_usage() {
  if ! ldr_command_exists df; then
    return 0
  fi
  df -iP -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR==1 || $5+0>=70 {print}'
}

ldr_disk_warnings() {
  local threshold="${DISK_WARN_THRESHOLD:-90}"
  if ! ldr_command_exists df; then
    return 0
  fi
  df -P -x tmpfs -x devtmpfs 2>/dev/null | awk -v th="${threshold}" 'NR>1 {
    gsub(/%/,"",$5)
    if ($5+0 >= th) printf "WARNING: %s is %s%% full (threshold %s%%)\n", $6, $5, th
  }'
}

ldr_disk_summary() {
  local path="${DISK_WARN_PATH:-/}" pct
  pct="$(ldr_disk_percent)"
  printf 'Watched path   : %s\n' "${path}"
  printf 'Disk usage     : %s\n' "$(ldr_bar "${pct}")"
  printf '\nMounted filesystems:\n'
  ldr_disk_partitions
  printf '\n'
  ldr_disk_warnings || true
  ldr_warn_if_threshold "Disk utilization (${path})" "${pct}" "${DISK_WARN_THRESHOLD}" || true
}

ldr_disk_metrics_kv() {
  local path="${DISK_WARN_PATH:-/}"
  local line total used avail pct
  line="$(df -Pk "${path}" 2>/dev/null | awk 'NR==2 {print $2, $3, $4, $5}')"
  read -r total used avail pct <<<"${line}"
  pct="${pct%%%}"
  printf 'disk_path=%s\n' "${path}"
  printf 'disk_total_kib=%s\n' "$(ldr_to_int "${total}")"
  printf 'disk_used_kib=%s\n' "$(ldr_to_int "${used}")"
  printf 'disk_avail_kib=%s\n' "$(ldr_to_int "${avail}")"
  printf 'disk_percent=%s\n' "$(ldr_to_int "${pct}")"
}
