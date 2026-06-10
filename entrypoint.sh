#!/bin/sh
set -eu

if [ -z "${OUTLINE_TRANSPORT:-}" ]; then
  echo "ERROR: OUTLINE_TRANSPORT is required (ss://...)" >&2
  exit 1
fi

# Some distros mount /etc/resolv.conf as a file from the host.
# We want to ensure DNS works reliably inside the VPN network namespace.
umount /etc/resolv.conf 2>/dev/null || true
[ -f /etc/resolv.conf ] || printf 'nameserver 1.1.1.1\n' > /etc/resolv.conf

/usr/local/bin/outline-cli -transport "${OUTLINE_TRANSPORT}" &
OUTLINE_PID=$!

# Allow local Docker and WireGuard subnets to bypass Outline policy routing.
# Without this, reply packets to WG peers can be forced into table 233.
for i in 1 2 3 4 5; do
  if ip rule show | grep -q "table 233"; then
    break
  fi
  sleep 1
done

WG_SUBNET="${INTERNAL_SUBNET}/24"
ip rule add pref 100 to "${WG_SUBNET}" lookup main 2>/dev/null || true

# Docker/custom bridge subnets differ per host (e.g. 172.17.0.0/16, 10.200.0.0/16).
pref=101
for cidr in $(ip -4 route show proto kernel scope link 2>/dev/null | awk '$2 == "dev" { print $1 }'); do
  ip rule add pref "${pref}" to "${cidr}" lookup main 2>/dev/null || true
  pref=$((pref + 1))
done

# Ensure exactly one NAT rule for traffic leaving via Outline interface.
if iptables -t nat -C POSTROUTING -o outline+ -j MASQUERADE 2>/dev/null; then
  while iptables -t nat -C POSTROUTING -o outline+ -j MASQUERADE 2>/dev/null; do
    iptables -t nat -D POSTROUTING -o outline+ -j MASQUERADE || true
  done
fi
iptables -t nat -A POSTROUTING -o outline+ -j MASQUERADE

wait "$OUTLINE_PID"

