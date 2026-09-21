#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${POMELODB_INSTALL_PREFIX:?POMELODB_INSTALL_PREFIX is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

sudo service ssh start
install -d -m 700 "$HOME/.ssh"
if [[ ! -f "$HOME/.ssh/id_ed25519" ]]; then
  ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/id_ed25519"
fi
touch "$HOME/.ssh/authorized_keys"
grep -qxF "$(cat "$HOME/.ssh/id_ed25519.pub")" \
  "$HOME/.ssh/authorized_keys" || \
  cat "$HOME/.ssh/id_ed25519.pub" >> "$HOME/.ssh/authorized_keys"
chmod 600 "$HOME/.ssh/authorized_keys"
ssh-keyscan -H "$(hostname -s)" localhost >> "$HOME/.ssh/known_hosts" 2>/dev/null || true

export PATH="$POMELODB_INSTALL_PREFIX/bin:$PATH"
source "$POMELODB_INSTALL_PREFIX/greenplum_path.sh"
export PGHOST=127.0.0.1 PGPORT=5432 PGDATABASE=postgres
export LC_ALL=en_US.UTF-8

coordinator_host="$(hostname -s)"
ssh-keyscan -H "$coordinator_host" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
mkdir -p "$RUNNER_TEMP/pomelodb-coordinator" \
  "$RUNNER_TEMP/pomelodb-segment0" \
  "$RUNNER_TEMP/pomelodb-segment1" \
  "$RUNNER_TEMP/pomelodb-segment2" \
  "$RUNNER_TEMP/pomelodb-mirror0" \
  "$RUNNER_TEMP/pomelodb-mirror1" \
  "$RUNNER_TEMP/pomelodb-mirror2"
test -r "$POMELODB_INSTALL_PREFIX/bin/lib/gp_bash_version.sh"
cat > "$RUNNER_TEMP/hostfile_gpinitsystem" <<EOF
$coordinator_host
EOF
cat > "$RUNNER_TEMP/gpinitsystem_config" <<EOF
MACHINE_LIST_FILE=$RUNNER_TEMP/hostfile_gpinitsystem
SEG_PREFIX=gpseg
PORT_BASE=6000
declare -a DATA_DIRECTORY=(
  $RUNNER_TEMP/pomelodb-segment0
  $RUNNER_TEMP/pomelodb-segment1
  $RUNNER_TEMP/pomelodb-segment2
)
MIRROR_PORT_BASE=7000
declare -a MIRROR_DATA_DIRECTORY=(
  $RUNNER_TEMP/pomelodb-mirror0
  $RUNNER_TEMP/pomelodb-mirror1
  $RUNNER_TEMP/pomelodb-mirror2
)
COORDINATOR_HOSTNAME=$coordinator_host
COORDINATOR_DIRECTORY=$RUNNER_TEMP/pomelodb-coordinator
COORDINATOR_PORT=5432
STANDBY_HOSTNAME=$coordinator_host
STANDBY_PORT=5433
STANDBY_DATADIR=$RUNNER_TEMP/pomelodb-standby
TRUSTED_SHELL=ssh
ENCODING=UNICODE
EOF

gpinitsystem -c "$RUNNER_TEMP/gpinitsystem_config" -a
coordinator_data_directory="$RUNNER_TEMP/pomelodb-coordinator/gpseg-1"
export COORDINATOR_DATA_DIRECTORY="$coordinator_data_directory"
grep -qxF 'local all gpadmin trust' \
  "$coordinator_data_directory/pg_hba.conf" || \
  echo 'local all gpadmin trust' >> "$coordinator_data_directory/pg_hba.conf"
grep -qxF 'host all all 127.0.0.1/32 trust' \
  "$coordinator_data_directory/pg_hba.conf" || \
  echo 'host all all 127.0.0.1/32 trust' >> \
    "$coordinator_data_directory/pg_hba.conf"
pg_ctl -D "$coordinator_data_directory" reload
if ! psql -Atqc "select 1 from pg_roles where rolname = 'gpadmin'" | grep -qx 1; then
  psql -v ON_ERROR_STOP=1 -c "create role gpadmin superuser login"
fi
gpconfig -c fsync -v off --skipvalidation
gpstop -u
gpstate -Q
psql -v ON_ERROR_STOP=1 -c \
  "select count(*) from gp_segment_configuration where status='u' and role='p'"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "COORDINATOR_DATA_DIRECTORY=$coordinator_data_directory"
    echo "MASTER_DATA_DIRECTORY=$coordinator_data_directory"
    echo "PGHOST=127.0.0.1"
    echo "PGPORT=5432"
    echo "PGDATABASE=postgres"
  } >> "$GITHUB_ENV"
fi
