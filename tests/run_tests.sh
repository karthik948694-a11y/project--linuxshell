#!/usr/bin/env bash
# Lightweight self-tests. Run on Linux: ./tests/run_tests.sh

set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck disable=SC1091
source "${ROOT}/utils/bootstrap.sh"
ldr_bootstrap "${ROOT}"

PASS=0
FAIL=0

assert() {
  local name="$1"
  if eval "$2"; then
    printf '  PASS  %s\n' "${name}"
    PASS=$((PASS + 1))
  else
    printf '  FAIL  %s\n' "${name}"
    FAIL=$((FAIL + 1))
  fi
}

printf 'Linux Daily Reporter tests\n'

assert "settings present" "[[ -f \"${ROOT}/config/settings.conf\" ]]"
assert "main present" "[[ -f \"${ROOT}/main.sh\" ]]"

v="$(ldr_cpu_utilization)"
assert "cpu percent numeric" "[[ \"${v}\" =~ ^[0-9]+$ ]] && (( v >= 0 && v <= 100 ))"

v="$(ldr_memory_percent)"
assert "memory percent numeric" "[[ \"${v}\" =~ ^[0-9]+$ ]] && (( v >= 0 && v <= 100 ))"

v="$(ldr_disk_percent)"
assert "disk percent numeric" "[[ \"${v}\" =~ ^[0-9]+$ ]] && (( v >= 0 && v <= 100 ))"

v="$(ldr_process_count)"
assert "process count numeric" "[[ \"${v}\" =~ ^[0-9]+$ ]]"

h="$(ldr_health_from_metrics 10 10 10)"
assert "health classification" "[[ \"${h}\" == HEALTHY ]]"

escaped="$(ldr_html_escape '<x>')"
assert "html escape" "[[ \"${escaped}\" == '&lt;x&gt;' ]]"

f="$(ldr_unique_path "${LDR_REPORT_DIR}/test-unique.txt")"
printf 'a\n' >"${f}"
f2="$(ldr_unique_path "${f}")"
assert "unique path does not overwrite" "[[ \"${f}\" != \"${f2}\" ]]"
rm -f "${f}"

printf '\nGenerating a sample report for integration check...\n'
REPORT_FORMATS="txt html csv"
out="$(ldr_generate_daily_report)"
assert "report generator produced output" "[[ -n \"${out}\" ]]"
assert "txt report exists" "ls -1 \"${LDR_REPORT_DIR}\"/daily-report-*.txt >/dev/null 2>&1"
assert "html report exists" "ls -1 \"${LDR_REPORT_DIR}\"/daily-report-*.html >/dev/null 2>&1"
assert "csv report exists" "ls -1 \"${LDR_REPORT_DIR}\"/daily-report-*.csv >/dev/null 2>&1"

printf '\n%s passed, %s failed\n' "${PASS}" "${FAIL}"
if (( FAIL > 0 )); then
  exit 1
fi
exit 0
