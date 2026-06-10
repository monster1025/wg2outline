#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   ./test-wg-client.sh [path-to-peer-conf]
#
# Example:
#   ./test-wg-client.sh ./wireguard-config/peer1/peer1.conf

PEER_CONF="${1:-./wireguard-config/peer2/peer2.conf}"
CLIENT_NAME="${WG_TEST_CONTAINER_NAME:-wg-test-client}"
WAIT_SECONDS="${WG_TEST_WAIT_SECONDS:-15}"

if [[ ! -f "${PEER_CONF}" ]]; then
  echo "ERROR: peer config not found: ${PEER_CONF}" >&2
  exit 1
fi

cleanup() {
  docker rm -f "${CLIENT_NAME}" >/dev/null 2>&1 || true
}
trap cleanup EXIT

echo "==> Preparing clean test container: ${CLIENT_NAME}"
cleanup

echo "==> Starting temporary WireGuard client"
docker run -d \
  --name "${CLIENT_NAME}" \
  --privileged \
  --cap-add NET_ADMIN \
  --cap-add SYS_MODULE \
  --device /dev/net/tun:/dev/net/tun \
  -v "$(realpath "${PEER_CONF}"):/etc/wireguard/wg0.conf:ro" \
  --entrypoint sh \
  alpine:3.20 \
  -c "apk add --no-cache wireguard-tools iproute2 iptables ip6tables openresolv curl >/dev/null && wg-quick up wg0 && tail -f /dev/null" \
  >/dev/null

echo "==> Waiting ${WAIT_SECONDS}s for tunnel to initialize"
sleep "${WAIT_SECONDS}"

if [[ "$(docker inspect -f '{{.State.Running}}' "${CLIENT_NAME}")" != "true" ]]; then
  echo "ERROR: test client container exited before tunnel check" >&2
  echo "==> Last container logs:" >&2
  docker logs "${CLIENT_NAME}" >&2 || true
  exit 1
fi

echo "==> WireGuard status inside client"
docker exec "${CLIENT_NAME}" wg show || true

echo "==> Test request through client namespace: https://web.telegram.org/"
docker run --rm \
  --network=container:"${CLIENT_NAME}" \
  curlimages/curl:8.7.1 \
  -sS -I --max-time 20 https://web.telegram.org/

echo "==> External IP seen via WG client namespace"
docker run --rm \
  --network=container:"${CLIENT_NAME}" \
  curlimages/curl:8.7.1 \
  -sS --max-time 20 https://ifconfig.me
echo

echo "==> Test completed successfully"
