#!/usr/bin/env bash
set -Eeuo pipefail

: "${POMELODB_INSTALL_PREFIX:?POMELODB_INSTALL_PREFIX is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

export PATH="$POMELODB_INSTALL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-}"
source "$POMELODB_INSTALL_PREFIX/greenplum_path.sh"
export LC_ALL=en_US.UTF-8

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

coordinator_host="$(hostname -s)"
ssh-keyscan -H "$coordinator_host" >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
cluster_root="$RUNNER_TEMP/pomelodb-native-mpp"
mkdir -p \
  "$cluster_root/coordinator" \
  "$cluster_root/segment0" \
  "$cluster_root/segment1" \
  "$cluster_root/segment2" \
  "$cluster_root/mirror0" \
  "$cluster_root/mirror1" \
  "$cluster_root/mirror2"

cat > "$RUNNER_TEMP/native-hostfile" <<EOF
$coordinator_host
EOF
cat > "$RUNNER_TEMP/native-gpinitsystem.conf" <<EOF
MACHINE_LIST_FILE=$RUNNER_TEMP/native-hostfile
SEG_PREFIX=gpseg
PORT_BASE=16000
declare -a DATA_DIRECTORY=(
  $cluster_root/segment0
  $cluster_root/segment1
  $cluster_root/segment2
)
MIRROR_PORT_BASE=17000
declare -a MIRROR_DATA_DIRECTORY=(
  $cluster_root/mirror0
  $cluster_root/mirror1
  $cluster_root/mirror2
)
COORDINATOR_HOSTNAME=$coordinator_host
COORDINATOR_DIRECTORY=$cluster_root/coordinator
COORDINATOR_PORT=15432
ENCODING=UNICODE
TRUSTED_SHELL=ssh
EOF

gpinitsystem -c "$RUNNER_TEMP/native-gpinitsystem.conf" -a
coordinator_data_directory="$cluster_root/coordinator/gpseg-1"
export COORDINATOR_DATA_DIRECTORY="$coordinator_data_directory"
export MASTER_DATA_DIRECTORY="$coordinator_data_directory"
export PGHOST=127.0.0.1 PGPORT=15432 PGDATABASE=postgres

grep -qxF 'local all gpadmin trust' "$coordinator_data_directory/pg_hba.conf" || \
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
psql -v ON_ERROR_STOP=1 -Atqc \
  "select count(*) from gp_segment_configuration where status='u' and role='p'"
psql -v ON_ERROR_STOP=1 -Atqc \
  "select count(*) from gp_segment_configuration where status='u' and role='m'"

if [[ -n "${GITHUB_ENV:-}" ]]; then
  {
    echo "POMELODB_CLUSTER_ROOT=$cluster_root"
    echo "COORDINATOR_DATA_DIRECTORY=$coordinator_data_directory"
    echo "MASTER_DATA_DIRECTORY=$coordinator_data_directory"
    echo "PGHOST=$PGHOST"
    echo "PGPORT=$PGPORT"
    echo "PGDATABASE=$PGDATABASE"
    echo "PATH=$POMELODB_INSTALL_PREFIX/bin:$PATH"
    echo "LD_LIBRARY_PATH=$POMELODB_INSTALL_PREFIX/lib:$POMELODB_INSTALL_PREFIX/lib/postgresql:${LD_LIBRARY_PATH:-}"
  } >> "$GITHUB_ENV"
fi
