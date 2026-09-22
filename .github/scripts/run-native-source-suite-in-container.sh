#!/usr/bin/env bash
set -Eeuo pipefail

: "${ARTIFACT_DIR:?ARTIFACT_DIR is required}"
: "${RESULTS_DIR:?RESULTS_DIR is required}"
: "${SUITE:?SUITE is required}"

if ! id gpadmin >/dev/null 2>&1; then
  useradd --create-home --home-dir /tmp/runner-home --shell /bin/bash gpadmin
fi
mkdir -p /tmp/runner-home "$RESULTS_DIR"
rm -rf /tmp/pomelodb /tmp/pomelodb-install
tar -C /tmp -xzf "$ARTIFACT_DIR/pomelodb-native.tar.gz"
mv /tmp/pomelodb-install /tmp/pomelodb
chown -R gpadmin:gpadmin /tmp/runner-home /tmp/pomelodb "$RESULTS_DIR"

service ssh start

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
