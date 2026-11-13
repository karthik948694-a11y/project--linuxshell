#!/usr/bin/env bash
# Terminal color and formatting helpers.

ldr_init_colors() {
  if [[ -t 1 ]] && command -v tput >/dev/null 2>&1 && [[ "$(tput colors 2>/dev/null || echo 0)" -ge 8 ]]; then
    C_RESET="$(tput sgr0)"
    C_BOLD="$(tput bold)"
    C_DIM="$(tput dim 2>/dev/null || true)"
    C_RED="$(tput setaf 1)"
    C_GREEN="$(tput setaf 2)"
    C_YELLOW="$(tput setaf 3)"
    C_BLUE="$(tput setaf 4)"
    C_MAGENTA="$(tput setaf 5)"
    C_CYAN="$(tput setaf 6)"
    C_WHITE="$(tput setaf 7)"
  else
    C_RESET=""
    C_BOLD=""
    C_DIM=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_MAGENTA=""
    C_CYAN=""
    C_WHITE=""
  fi

  export C_RESET C_BOLD C_DIM C_RED C_GREEN C_YELLOW C_BLUE C_MAGENTA C_CYAN C_WHITE
}

ldr_health_color() {
  local status="${1:-UNKNOWN}"
  case "${status}" in
    HEALTHY) printf '%s' "${C_GREEN}" ;;
    WARNING) printf '%s' "${C_YELLOW}" ;;
    CRITICAL) printf '%s' "${C_RED}" ;;
    *) printf '%s' "${C_CYAN}" ;;
  esac
}

ldr_bar() {
  local percent="${1:-0}"
  local width="${2:-24}"
  local filled empty i
  percent="$(ldr_clamp_int "${percent}" 0 100)"
  filled=$((percent * width / 100))
  empty=$((width - filled))
  printf '['
  for ((i = 0; i < filled; i++)); do printf '#'; done
  for ((i = 0; i < empty; i++)); do printf '-'; done
  printf '] %3d%%' "${percent}"
}
