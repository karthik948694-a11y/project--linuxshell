#!/usr/bin/env bash
# Optional SQLite history for generated reports.

ldr_sql_escape() {
  local s="${1:-}"
  s="${s//\'/\'\'}"
  printf '%s' "${s}"
}

ldr_sqlite_available() {
  [[ "${SQLITE_ENABLED}" == "true" ]] && ldr_command_exists sqlite3
}

ldr_sqlite_init() {
  ldr_sqlite_available || return 0
  mkdir -p "$(dirname "${LDR_ROOT}/${SQLITE_DB}")"
  local db="${LDR_ROOT}/${SQLITE_DB}"
  sqlite3 "${db}" <<'SQL'
CREATE TABLE IF NOT EXISTS reports (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  generated_at TEXT NOT NULL,
  hostname TEXT,
  health TEXT,
  cpu_percent INTEGER,
  mem_percent INTEGER,
  disk_percent INTEGER,
  txt_path TEXT,
  html_path TEXT,
  csv_path TEXT
);
SQL
  chmod 600 "${db}" 2>/dev/null || true
}

ldr_sqlite_insert_report() {
  ldr_sqlite_available || return 0
  local db="${LDR_ROOT}/${SQLITE_DB}"
  sqlite3 "${db}" <<SQL
INSERT INTO reports (generated_at, hostname, health, cpu_percent, mem_percent, disk_percent, txt_path, html_path, csv_path)
VALUES (
  '$(ldr_sql_escape "${1}")',
  '$(ldr_sql_escape "${2}")',
  '$(ldr_sql_escape "${3}")',
  $(ldr_to_int "${4}"),
  $(ldr_to_int "${5}"),
  $(ldr_to_int "${6}"),
  '$(ldr_sql_escape "${7}")',
  '$(ldr_sql_escape "${8}")',
  '$(ldr_sql_escape "${9}")'
);
SQL
}

ldr_sqlite_list() {
  if ! ldr_sqlite_available; then
    echo "SQLite history is disabled or sqlite3 is not installed."
    return 1
  fi
  sqlite3 -header -column "${LDR_ROOT}/${SQLITE_DB}" \
    'SELECT id, generated_at, hostname, health, cpu_percent, mem_percent, disk_percent FROM reports ORDER BY id DESC LIMIT 20;'
}
