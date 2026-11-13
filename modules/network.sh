#!/usr/bin/env bash
# Network interfaces, addresses, traffic, and connectivity.

ldr_net_interfaces() {
  if ldr_command_exists ip; then
    ip -o link show 2>/dev/null | awk -F': ' '{print $2}' | awk '{print $1}'
    return 0
  fi
  if [[ -d /sys/class/net ]]; then
    ls /sys/class/net
    return 0
  fi
  echo "No network interface source available"
  return 1
}

ldr_net_addresses() {
  if ldr_command_exists ip; then
    ip -o addr show 2>/dev/null | awk '{print $2, $3, $4}'
    return 0
  fi
  if ldr_command_exists ifconfig; then
    ifconfig 2>/dev/null
    return 0
  fi
  echo "ip/ifconfig not available"
  return 1
}

ldr_net_interface_status() {
  local iface="$1" oper
  if [[ -r "/sys/class/net/${iface}/operstate" ]]; then
    oper="$(cat "/sys/class/net/${iface}/operstate")"
    printf '%-16s %s\n' "${iface}" "${oper}"
    return 0
  fi
  printf '%-16s unknown\n' "${iface}"
}

ldr_net_traffic() {
  local iface rx tx
  printf '%-16s %16s %16s\n' "INTERFACE" "RX" "TX"
  if [[ -r /proc/net/dev ]]; then
    awk -F'[: ]+' 'NR>2 {
      iface=$1; gsub(/ /,"",iface)
      rx=$2; tx=$10
      printf "%s %s %s\n", iface, rx, tx
    }' /proc/net/dev | while read -r iface rx tx; do
      printf '%-16s %16s %16s\n' "${iface}" "$(ldr_human_bytes "${rx}")" "$(ldr_human_bytes "${tx}")"
    done
    return 0
  fi
  echo "Traffic counters unavailable"
  return 1
}

ldr_net_connectivity() {
  local target="${PING_TARGET:-8.8.8.8}" count="${PING_COUNT:-2}"
  if ! ldr_command_exists ping; then
    echo "ping is not available; skipping connectivity check"
    return 1
  fi
  if ping -c "${count}" -W 2 "${target}" >/dev/null 2>&1; then
    printf 'Connectivity to %s: OK\n' "${target}"
    return 0
  fi
  printf 'Connectivity to %s: FAILED\n' "${target}"
  return 1
}

ldr_net_listening() {
  if ldr_command_exists ss; then
    ss -tuln 2>/dev/null | awk 'NR==1 || NR<=16'
    return 0
  fi
  if ldr_command_exists netstat; then
    netstat -tuln 2>/dev/null | awk 'NR==1 || NR<=16'
    return 0
  fi
  echo "ss/netstat not available"
}

ldr_network_summary() {
  local iface
  printf 'Hostname        : %s\n' "$(ldr_hostname)"
  printf '\nInterface status:\n'
  while IFS= read -r iface; do
    [[ -n "${iface}" ]] || continue
    ldr_net_interface_status "${iface}"
  done < <(ldr_net_interfaces)
  printf '\nAddresses:\n'
  ldr_net_addresses
  printf '\nTraffic:\n'
  ldr_net_traffic
  printf '\n'
  ldr_net_connectivity || true
}

ldr_network_metrics_kv() {
  local rx_total=0 tx_total=0 status="unknown"
  if [[ -r /proc/net/dev ]]; then
    read -r rx_total tx_total < <(awk -F'[: ]+' 'NR>2 {rx+=$2; tx+=$10} END{print rx+0, tx+0}' /proc/net/dev)
  fi
  if ldr_net_connectivity >/dev/null 2>&1; then
    status="ok"
  else
    status="failed"
  fi
  printf 'net_rx_bytes=%s\n' "${rx_total}"
  printf 'net_tx_bytes=%s\n' "${tx_total}"
  printf 'net_status=%s\n' "${status}"
  printf 'net_ping_target=%s\n' "${PING_TARGET:-8.8.8.8}"
}
