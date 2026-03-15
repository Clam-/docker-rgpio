#!/bin/sh
set -eu

if [ "${RGPIOD_SKIP_DEVICE_CHECK:-0}" != "1" ] && ! find /dev -maxdepth 1 -type c -name 'gpiochip*' | grep -q .; then
  cat >&2 <<'EOF'
rgpiod needs Linux gpiochip device nodes from the host.

Pass at least one gpiochip device into the container, for example:
  --device /dev/gpiochip0:/dev/gpiochip0

If your board exposes multiple gpiochips, pass each required device.
If you only want to smoke-test container startup logic, set RGPIOD_SKIP_DEVICE_CHECK=1.
EOF
  exit 78
fi

set -- rgpiod -p "${RGPIOD_PORT:-8889}" "$@"

if [ "${RGPIOD_LOCAL_ONLY:-0}" = "1" ]; then
  set -- "$@" -l
fi

if [ -n "${RGPIOD_ALLOWED_IPS:-}" ]; then
  old_ifs=$IFS
  IFS=','
  for allowed_ip in ${RGPIOD_ALLOWED_IPS}; do
    set -- "$@" -n "${allowed_ip}"
  done
  IFS=$old_ifs
fi

if [ "${RGPIOD_ACCESS_CONTROL:-0}" = "1" ]; then
  set -- "$@" -x
fi

if [ -n "${RGPIOD_CONFIG_DIR:-}" ]; then
  set -- "$@" -c "${RGPIOD_CONFIG_DIR}"
fi

if [ -n "${RGPIOD_WORK_DIR:-}" ]; then
  set -- "$@" -w "${RGPIOD_WORK_DIR}"
fi

"$@"

daemon_pid=""
attempt=0
while [ -z "${daemon_pid}" ] && [ "${attempt}" -lt 50 ]; do
  daemon_pid="$(pgrep -xo rgpiod || true)"
  attempt=$((attempt + 1))
  if [ -z "${daemon_pid}" ]; then
    sleep 0.1
  fi
done

if [ -z "${daemon_pid}" ]; then
  echo "rgpiod did not start successfully" >&2
  exit 1
fi

stop_daemon() {
  kill "${daemon_pid}" 2>/dev/null || true
  while kill -0 "${daemon_pid}" 2>/dev/null; do
    sleep 0.1
  done
}

trap 'stop_daemon; exit 0' INT TERM HUP

tail --pid="${daemon_pid}" -f /dev/null
