#!/usr/bin/env bash
set -Eeuo pipefail

: "${POMELODB_INSTALL_PREFIX:?POMELODB_INSTALL_PREFIX is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

export PATH="$POMELODB_INSTALL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"
export DYLD_LIBRARY_PATH="${DYLD_LIBRARY_PATH:-}"
source "$POMELODB_INSTALL_PREFIX/greenplum_path.sh"
export LC_ALL="${POMELODB_LOCALE:-en_US.UTF-8}"

if [[ "${POMELODB_SKIP_SSH_START:-0}" != 1 ]]; then
  if [[ "${EUID}" -eq 0 ]]; then
    service ssh start
  elif command -v sudo >/dev/null 2>&1; then
    sudo service ssh start
  else
    echo 'ssh service must be started by the container entrypoint' >&2
    exit 1
  fi
fi
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

# All database instances run in one CI container.  Keep the real container
# hostname in the catalog: isolation2's recoverseg_from_file test constructs
# recovery entries from os.uname(), and therefore requires the catalog and the
# kernel hostname to agree.
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
STANDBY_HOSTNAME=$coordinator_host
STANDBY_PORT=15433
STANDBY_DATADIR=$cluster_root/coordinator-mirror
LOCALE_SETTING=en_US.UTF-8
ENCODING=UNICODE
TRUSTED_SHELL=ssh
EOF

init_log="$cluster_root/gpinitsystem.log"
set +e
# Let timeout own a process group so a timed-out gpinitsystem cannot leave
# gpstart/ssh/segment children holding the pipeline open.
timeout --kill-after=30s 15m \
  gpinitsystem -c "$RUNNER_TEMP/native-gpinitsystem.conf" -a \
  2>&1 | tee "$init_log"
init_status="${PIPESTATUS[0]}"
set -e
if [[ "$init_status" -ne 0 ]]; then
  if [[ -d "$HOME/gpAdminLogs" ]]; then
    cp -a "$HOME/gpAdminLogs" "$cluster_root/" || true
  fi
  echo "gpinitsystem failed or timed out with status $init_status" >&2
  exit "$init_status"
fi
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
    echo "PYTHONPATH=$POMELODB_INSTALL_PREFIX/lib/python:${PYTHONPATH:-}"
    echo "LD_LIBRARY_PATH=$POMELODB_INSTALL_PREFIX/lib:$POMELODB_INSTALL_PREFIX/lib/postgresql:${LD_LIBRARY_PATH:-}"
  } >> "$GITHUB_ENV"
fi
