#!/usr/bin/env bash
# Shared helpers: command detection, numeric parsing, config I/O.

ldr_command_exists() {
  command -v "$1" >/dev/null 2>&1
}

ldr_require_file() {
  local path="$1"
  if [[ ! -r "${path}" ]]; then
    ldr_log_warn "Cannot read ${path}"
    return 1
  fi
  return 0
}

ldr_clamp_int() {
  local value="${1:-0}" min="${2:-0}" max="${3:-100}"
  value="${value%%.*}"
  [[ "${value}" =~ ^-?[0-9]+$ ]] || value=0
  if (( value < min )); then value="${min}"; fi
  if (( value > max )); then value="${max}"; fi
  printf '%s' "${value}"
}

ldr_to_int() {
  local value="${1:-0}"
  value="${value//%/}"
  value="${value%%.*}"
  [[ "${value}" =~ ^-?[0-9]+$ ]] || value=0
  printf '%s' "${value}"
}

ldr_human_bytes() {
  local bytes="${1:-0}"
  awk -v b="${bytes}" 'BEGIN {
    if (b+0 != b) b=0
    split("B KB MB GB TB PB", u, " ")
    i=1
    while (b>=1024 && i<6) { b=b/1024; i++ }
    if (i==1) printf "%d %s", b, u[i]
    else printf "%.1f %s", b, u[i]
  }'
}

ldr_kib_to_human() {
  local kib="${1:-0}"
  kib="$(ldr_to_int "${kib}")"
  ldr_human_bytes $((kib * 1024))
}

ldr_read_os_release() {
  local pretty="Unknown Linux" id="linux" version="unknown"
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    pretty="$(. /etc/os-release; printf '%s' "${PRETTY_NAME:-$NAME}")"
    # shellcheck disable=SC1091
    id="$(. /etc/os-release; printf '%s' "${ID:-linux}")"
    # shellcheck disable=SC1091
    version="$(. /etc/os-release; printf '%s' "${VERSION_ID:-unknown}")"
  elif ldr_command_exists lsb_release; then
    pretty="$(lsb_release -ds 2>/dev/null | tr -d '"')"
  fi
  printf '%s|%s|%s' "${pretty}" "${id}" "${version}"
}

ldr_kernel() {
  uname -r 2>/dev/null || echo "unknown"
}

ldr_hostname() {
  hostname 2>/dev/null || uname -n 2>/dev/null || echo "localhost"
}

ldr_uptime_pretty() {
  if ldr_command_exists uptime; then
    uptime -p 2>/dev/null && return 0
  fi
  if [[ -r /proc/uptime ]]; then
    awk '{
      s=int($1)
      d=int(s/86400); s-=d*86400
      h=int(s/3600); s-=h*3600
      m=int(s/60)
      printf "up %d days, %d hours, %d minutes\n", d, h, m
    }' /proc/uptime
    return 0
  fi
  echo "uptime unavailable"
}

ldr_loadavg() {
  if [[ -r /proc/loadavg ]]; then
    awk '{print $1, $2, $3}' /proc/loadavg
    return 0
  fi
  if ldr_command_exists uptime; then
    uptime | awk -F'load average:' '{gsub(/^ +| +$/,"",$2); print $2}'
    return 0
  fi
  echo "n/a n/a n/a"
}

ldr_nproc() {
  if ldr_command_exists nproc; then
    nproc
  elif [[ -r /proc/cpuinfo ]]; then
    grep -c '^processor' /proc/cpuinfo
  else
    echo 1
  fi
}

ldr_confirm() {
  local prompt="${1:-Continue?}"
  local reply
  printf '%s [y/N]: ' "${prompt}"
  read -r reply || return 1
  [[ "${reply}" =~ ^[Yy]$ ]]
}

ldr_prompt_int() {
  local prompt="$1" default="$2" min="$3" max="$4" value
  printf '%s [%s]: ' "${prompt}" "${default}" >&2
  read -r value || true
  value="${value:-$default}"
  if [[ ! "${value}" =~ ^[0-9]+$ ]]; then
    echo "${default}"
    return 1
  fi
  if (( value < min || value > max )); then
    echo "${default}"
    return 1
  fi
  echo "${value}"
}

ldr_set_config() {
  local key="$1" value="$2" file="${LDR_CONFIG_FILE}"
  local tmp
  tmp="$(mktemp "${LDR_TMP_DIR}/cfg.XXXXXX")"
  awk -v k="${key}" -v v="${value}" '
    BEGIN { found=0 }
    $0 ~ "^" k "=" {
      print k "=" v
      found=1
      next
    }
    { print }
    END { if (!found) print k "=" v }
  ' "${file}" >"${tmp}"
  mv "${tmp}" "${file}"
  chmod 600 "${file}" 2>/dev/null || true
}

ldr_safe_mkdir() {
  mkdir -p "$1"
  chmod 700 "$1" 2>/dev/null || true
}

ldr_tmpfile() {
  mktemp "${LDR_TMP_DIR}/ldr.XXXXXX"
}

ldr_health_from_metrics() {
  local cpu="$1" mem="$2" disk="$3"
  cpu="$(ldr_to_int "${cpu}")"
  mem="$(ldr_to_int "${mem}")"
  disk="$(ldr_to_int "${disk}")"
  if (( cpu >= CPU_WARN_THRESHOLD || mem >= MEM_WARN_THRESHOLD || disk >= DISK_WARN_THRESHOLD )); then
    if (( cpu >= 95 || mem >= 95 || disk >= 98 )); then
      echo "CRITICAL"
    else
      echo "WARNING"
    fi
  else
    echo "HEALTHY"
  fi
}

ldr_warn_if_threshold() {
  local label="$1" value="$2" threshold="$3" unit="${4:-%}"
  value="$(ldr_to_int "${value}")"
  threshold="$(ldr_to_int "${threshold}")"
  if (( value >= threshold )); then
    printf '%sWARNING:%s %s is %s%s (threshold %s%s)\n' \
      "${C_YELLOW}" "${C_RESET}" "${label}" "${value}" "${unit}" "${threshold}" "${unit}"
    return 1
  fi
  return 0
}

ldr_run_or_msg() {
  local cmd="$1"
  shift || true
  if ldr_command_exists "${cmd}"; then
    "${cmd}" "$@"
    return $?
  fi
  printf 'Command not available: %s\n' "${cmd}"
  return 127
}

ldr_first_existing() {
  local path
  for path in "$@"; do
    if [[ -r "${path}" ]]; then
      printf '%s' "${path}"
      return 0
    fi
  done
  return 1
}

ldr_auth_log_path() {
  ldr_first_existing /var/log/auth.log /var/log/secure /var/log/messages || true
}

ldr_trim() {
  local s="${1:-}"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "${s}"
}

ldr_csv_escape() {
  local s="${1:-}"
  s="${s//\"/\"\"}"
  printf '"%s"' "${s}"
}

ldr_html_escape() {
  local s="${1:-}"
  s="${s//&/&amp;}"
  s="${s//</&lt;}"
  s="${s//>/&gt;}"
  s="${s//\"/&quot;}"
  printf '%s' "${s}"
}

ldr_html_escape_stream() {
  awk '{
    gsub(/&/, "\\&amp;")
    gsub(/</, "\\&lt;")
    gsub(/>/, "\\&gt;")
    gsub(/"/, "\\&quot;")
    print
  }'
}

ldr_pager() {
  local file="$1"
  if ldr_command_exists less; then
    less -R "${file}"
  else
    cat "${file}"
    printf '\nPress Enter to continue...'
    read -r _ || true
  fi
}

ldr_list_reports() {
  ls -1t "${LDR_REPORT_DIR}"/daily-report-* 2>/dev/null || true
}

ldr_rotate_reports() {
  local days="${REPORT_RETENTION_DAYS:-90}"
  find "${LDR_REPORT_DIR}" -type f -mtime "+${days}" -delete 2>/dev/null || true
}
