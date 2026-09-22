#!/usr/bin/env bash
set -Eeuo pipefail

: "${ARTIFACT_DIR:?ARTIFACT_DIR is required}"
: "${RESULTS_DIR:?RESULTS_DIR is required}"
: "${SUITE:?SUITE is required}"
: "${RESULTS_UID:?RESULTS_UID is required}"
: "${RESULTS_GID:?RESULTS_GID is required}"

mkdir -p "$RESULTS_DIR"
entrypoint_log="$RESULTS_DIR/container-entrypoint.log"
exec > >(tee -a "$entrypoint_log") 2>&1
entrypoint_status=0
trap '
  entrypoint_status=$?
  # The test user owns the MPP data and gpAdminLogs. Return the bind-mounted
  # result tree to the runner user before upload-artifact scans it, otherwise a
  # failed gpinitsystem can mask its own diagnostics with EACCES.
  if [[ "$RESULTS_UID" =~ ^[0-9]+$ && "$RESULTS_GID" =~ ^[0-9]+$ ]]; then
    chown -R "$RESULTS_UID:$RESULTS_GID" "$RESULTS_DIR" 2>/dev/null || true
  fi
  echo "container entrypoint exited with status $entrypoint_status"
  exit "$entrypoint_status"
' EXIT

printf 'suite=%s\n' "$SUITE"
printf 'container_user=%s\n' "$(id -un)"
printf 'container_arch=%s\n' "$(uname -m)"

missing_runtime=()
for command_name in ssh sshd ip less ping rsync ss; do
  command -v "$command_name" >/dev/null 2>&1 || missing_runtime+=("$command_name")
done
if [[ "${#missing_runtime[@]}" -ne 0 ]]; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y \
    iproute2 less iputils-ping rsync openssh-client openssh-server
fi

for command_name in cmake tar useradd runuser ssh ssh-keygen ssh-keyscan sshd; do
  if ! command_path="$(command -v "$command_name")"; then
    echo "missing required command: $command_name" >&2
    exit 1
  fi
  echo "$command_name=$command_path"
done

if ! id gpadmin >/dev/null 2>&1; then
  useradd --create-home --home-dir /tmp/runner-home --shell /bin/bash gpadmin
fi
mkdir -p /tmp/runner-home "$RESULTS_DIR"
rm -rf /tmp/pomelodb-install
tar -C /tmp -xzf "$ARTIFACT_DIR/pomelodb-native.tar.gz"
chown -R gpadmin:gpadmin /tmp/runner-home /tmp/pomelodb-install "$RESULTS_DIR"

install -d -m 0755 /run/sshd
if command -v service >/dev/null 2>&1; then
  service ssh start
else
  /usr/sbin/sshd
fi

set +e
runuser -u gpadmin --preserve-environment -- env \
  HOME=/tmp/runner-home \
  USER=gpadmin \
  LOGNAME=gpadmin \
  POMELODB_INSTALL_PREFIX=/tmp/pomelodb-install \
  SOURCE_TEST_ROOT=/tmp/pomelodb-install/share/postgresql/source-tests \
  RUNNER_TEMP="$RESULTS_DIR" \
  SUITE="$SUITE" \
  POMELODB_LOCALE=C \
  POMELODB_SKIP_SSH_START=1 \
  bash -euo pipefail -c '
    bash /workspace/.github/scripts/init-native-source-test-cluster.sh
    bash /workspace/.github/scripts/run-native-source-suite.sh
  '
status="$?"
set -e
exit "$status"
