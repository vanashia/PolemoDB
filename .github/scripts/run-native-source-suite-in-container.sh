#!/usr/bin/env bash
set -Eeuo pipefail

: "${ARTIFACT_DIR:?ARTIFACT_DIR is required}"
: "${RESULTS_DIR:?RESULTS_DIR is required}"
: "${SUITE:?SUITE is required}"

mkdir -p "$RESULTS_DIR"
entrypoint_log="$RESULTS_DIR/container-entrypoint.log"
exec > >(tee -a "$entrypoint_log") 2>&1
entrypoint_status=0
trap 'entrypoint_status=$?; echo "container entrypoint exited with status $entrypoint_status"; exit "$entrypoint_status"' EXIT

printf 'suite=%s\n' "$SUITE"
printf 'container_user=%s\n' "$(id -un)"
printf 'container_arch=%s\n' "$(uname -m)"
for command_name in cmake tar useradd runuser ssh ssh-keygen; do
  command -v "$command_name"
done

if ! id gpadmin >/dev/null 2>&1; then
  useradd --create-home --home-dir /tmp/runner-home --shell /bin/bash gpadmin
fi
mkdir -p /tmp/runner-home "$RESULTS_DIR"
rm -rf /tmp/pomelodb /tmp/pomelodb-install
tar -C /tmp -xzf "$ARTIFACT_DIR/pomelodb-native.tar.gz"
mv /tmp/pomelodb-install /tmp/pomelodb
chown -R gpadmin:gpadmin /tmp/runner-home /tmp/pomelodb "$RESULTS_DIR"

if ! command -v sshd >/dev/null 2>&1; then
  apt-get update
  DEBIAN_FRONTEND=noninteractive apt-get install -y openssh-server
fi
install -d -m 0755 /run/sshd
if command -v service >/dev/null 2>&1; then
  service ssh start
else
  /usr/sbin/sshd
fi

set +e
runuser -u gpadmin --preserve-environment -- env \
  HOME=/tmp/runner-home \
  POMELODB_INSTALL_PREFIX=/tmp/pomelodb \
  SOURCE_TEST_ROOT=/tmp/pomelodb/share/postgresql/source-tests \
  RUNNER_TEMP="$RESULTS_DIR" \
  SUITE="$SUITE" \
  POMELODB_SKIP_SSH_START=1 \
  bash -euo pipefail -c '
    bash /workspace/.github/scripts/init-native-source-test-cluster.sh
    bash /workspace/.github/scripts/run-native-source-suite.sh
  '
status="$?"
set -e
exit "$status"
