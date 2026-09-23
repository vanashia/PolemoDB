#!/usr/bin/env bash
set -Eeuo pipefail

: "${POMELODB_INSTALL_PREFIX:?POMELODB_INSTALL_PREFIX is required}"
: "${SOURCE_TEST_ROOT:?SOURCE_TEST_ROOT is required}"
: "${SUITE:?SUITE is required}"
: "${RUNNER_TEMP:?RUNNER_TEMP is required}"

export PATH="$POMELODB_INSTALL_PREFIX/bin:$PATH"
export LD_LIBRARY_PATH="$POMELODB_INSTALL_PREFIX/lib:$POMELODB_INSTALL_PREFIX/lib/postgresql:${LD_LIBRARY_PATH:-}"
export DYLD_LIBRARY_PATH="$POMELODB_INSTALL_PREFIX/lib:$POMELODB_INSTALL_PREFIX/lib/postgresql:${DYLD_LIBRARY_PATH:-}"
export PGHOST="${PGHOST:-127.0.0.1}"
export PGPORT="${PGPORT:-15432}"
export PGDATABASE="${PGDATABASE:-postgres}"
export GPHOME="$POMELODB_INSTALL_PREFIX"
export COORDINATOR_DATA_DIRECTORY="${COORDINATOR_DATA_DIRECTORY:?COORDINATOR_DATA_DIRECTORY is required}"
export MASTER_DATA_DIRECTORY="$COORDINATOR_DATA_DIRECTORY"
source "$POMELODB_INSTALL_PREFIX/greenplum_path.sh"
export PYTHONPATH="$POMELODB_INSTALL_PREFIX/lib/python:${PYTHONPATH:-}"

# CMake installs the complete source-test tree, but the repository contains
# this link so isolation2 can reuse regress data.  Recreate it inside the
# self-contained artifact instead of relying on an absolute checkout path.
if [[ -d "$SOURCE_TEST_ROOT/regress/data" ]]; then
  ln -sfn "$SOURCE_TEST_ROOT/regress/data" "$SOURCE_TEST_ROOT/isolation2/data"
fi

log_file="$RUNNER_TEMP/pomelodb-${SUITE}.log"
status_file="$RUNNER_TEMP/pomelodb-${SUITE}.status"
results_root="$RUNNER_TEMP/pomelodb-${SUITE}-results"
mkdir -p "$results_root"
: > "$log_file"
: > "$status_file"

suite_status=0
current_command=""

record_signal_failure() {
  local signal_name="$1"
  local signal_number="$2"
  local signal_status=$((128 + signal_number))
  printf 'suite_signal=%s\n' "$signal_name" >> "$status_file"
  printf 'suite_signal_status=%s\n' "$signal_status" >> "$status_file"
  printf 'suite_status=1\n' >> "$status_file"
  suite_status=1
  if [[ -n "$current_command" ]]; then
    printf '%s=%s\n' "$current_command" "$signal_status" >> "$status_file"
  fi
}

handle_suite_signal() {
  local signal_name="$1"
  local signal_number="$2"
  record_signal_failure "$signal_name" "$signal_number"
  trap - "$signal_name"
  kill -"$signal_name" "$$"
}

trap 'handle_suite_signal TERM 15' TERM
trap 'handle_suite_signal INT 2' INT
trap 'handle_suite_signal HUP 1' HUP

record_status() {
  local name="$1"
  local status="$2"
  printf '%s=%s\n' "$name" "$status" >> "$status_file"
  if [[ "$status" -ne 0 ]]; then
    suite_status=1
  fi
}

run_command() {
  local name="$1"
  local duration="$2"
  shift 2
  echo "===== $name =====" | tee -a "$log_file"
  current_command="$name"
  set +e
  # Do not use --foreground: timeout must create a process group and clean up
  # descendants such as psql and pg_regress helpers when a suite hangs.
  timeout --kill-after=60s "$duration" "$@" \
    2>&1 | tee -a "$log_file"
  local status="${PIPESTATUS[0]}"
  set -e
  record_status "$name" "$status"
  current_command=""
  return 0
}

run_in_directory() {
  local name="$1"
  local duration="$2"
  local directory="$3"
  shift 3
  echo "===== $name (cwd=$directory) =====" | tee -a "$log_file"
  current_command="$name"
  set +e
  (cd "$directory" && timeout --kill-after=60s "$duration" "$@") \
    2>&1 | tee -a "$log_file"
  local status="${PIPESTATUS[0]}"
  set -e
  record_status "$name" "$status"
  current_command=""
  return 0
}

pg_regress() {
  local name="$1"
  local inputdir="$2"
  local outputdir="$3"
  shift 3
  mkdir -p "$outputdir"
  run_command "$name" 45m \
    "$POMELODB_INSTALL_PREFIX/bin/pg_regress" \
    --inputdir="$inputdir" \
    --outputdir="$outputdir" \
    --bindir="$POMELODB_INSTALL_PREFIX/bin" \
    --dlpath="$POMELODB_INSTALL_PREFIX/lib/postgresql" \
    --init-file="$SOURCE_TEST_ROOT/regress/init_file" \
    --load-extension=gp_inject_fault \
    --max-concurrent-tests=20 "$@"
}

stage_source_test_module() {
  local module_name="$1"
  local outputdir="$2"
  local module_path="$POMELODB_INSTALL_PREFIX/lib/postgresql/${module_name}.so"
  test -r "$module_path"
  ln -sfn "$module_path" "$outputdir/${module_name}.so"
}

pg_isolation_regress() {
  local name="$1"
  local inputdir="$2"
  local outputdir="$3"
  shift 3
  mkdir -p "$outputdir"
  run_command "$name" 45m \
    "$POMELODB_INSTALL_PREFIX/bin/pg_isolation_regress" \
    --inputdir="$inputdir" \
    --outputdir="$outputdir" \
    --bindir="$POMELODB_INSTALL_PREFIX/bin" \
    --dlpath="$POMELODB_INSTALL_PREFIX/lib/postgresql" \
    --init-file="$SOURCE_TEST_ROOT/regress/init_file" \
    --load-extension=pageinspect \
    --load-extension=gp_inject_fault \
    --max-concurrent-tests=10 "$@"
}

run_tap_suite() {
  local name="$1"
  local directory="$2"
  local tap_files=("$directory"/t/*.pl)
  mkdir -p "$RUNNER_TEMP/pomelodb-${SUITE}-tap"
  run_in_directory "$name" 45m "$directory" \
    env \
    TESTLOGDIR="$RUNNER_TEMP/pomelodb-${SUITE}-tap/log" \
    TESTDATADIR="$RUNNER_TEMP/pomelodb-${SUITE}-tap/data" \
    PG_REGRESS="$POMELODB_INSTALL_PREFIX/bin/pg_regress" \
    REGRESS_SHLIB="$POMELODB_INSTALL_PREFIX/lib/postgresql/regress.so" \
    top_builddir="$POMELODB_INSTALL_PREFIX" \
    PGPORT="$PGPORT" \
    with_gssapi=yes with_krb_srvnam=postgres with_ldap=yes with_openssl=yes \
    prove -v -I "$SOURCE_TEST_ROOT/perl" -I "$directory" "${tap_files[@]}"
}

case "$SUITE" in
  regress)
    export PGOPTIONS='-c optimizer=off'
    pg_regress parallel_schedule "$SOURCE_TEST_ROOT/regress" \
      "$results_root/parallel" \
      --schedule="$SOURCE_TEST_ROOT/regress/parallel_schedule" \
      --load-extension=gp_inject_fault
    pg_regress greenplum_schedule "$SOURCE_TEST_ROOT/regress" \
      "$results_root/greenplum" \
      --schedule="$SOURCE_TEST_ROOT/regress/greenplum_schedule" \
      --load-extension=gp_inject_fault
    ;;
  isolation)
    pg_isolation_regress isolation_schedule "$SOURCE_TEST_ROOT/isolation" \
      "$results_root/isolation" \
      --schedule="$SOURCE_TEST_ROOT/isolation/isolation_schedule"
    ;;
  isolation2)
    run_in_directory isolation2 60m "$SOURCE_TEST_ROOT/isolation2" \
      "$POMELODB_INSTALL_PREFIX/bin/pg_isolation2_regress" \
      --inputdir="$SOURCE_TEST_ROOT/isolation2" \
      --outputdir="$results_root/isolation2" \
      --bindir="$POMELODB_INSTALL_PREFIX/bin" \
      --dlpath="$POMELODB_INSTALL_PREFIX/lib/postgresql" \
      --init-file="$SOURCE_TEST_ROOT/regress/init_file" \
      --init-file="$SOURCE_TEST_ROOT/isolation2/init_file_isolation2" \
      --load-extension=gp_inject_fault \
      --max-concurrent-tests=10 \
      --schedule="$SOURCE_TEST_ROOT/isolation2/isolation2_schedule"
    ;;
  fsync)
    mkdir -p "$results_root/fsync"
    stage_source_test_module fsync_helper "$results_root/fsync"
    pg_regress fsync "$SOURCE_TEST_ROOT/fsync" "$results_root/fsync" \
      setup bgwriter_checkpoint
    ;;
  walrep)
    mkdir -p "$results_root/walrep"
    stage_source_test_module gplibpq "$results_root/walrep"
    pg_regress walrep "$SOURCE_TEST_ROOT/walrep" "$results_root/walrep" \
      setup replication_views_mirrored missing_xlog \
      walreceiver generate_ao_xlog generate_aoco_xlog
    ;;
  heap_checksum)
    mkdir -p "$results_root/heap_checksum"
    stage_source_test_module heap_checksum_helper "$results_root/heap_checksum"
    pg_regress heap_checksum "$SOURCE_TEST_ROOT/heap_checksum" \
      "$results_root/heap_checksum" \
      --init-file="$SOURCE_TEST_ROOT/regress/init_file" \
      setup heap_checksum_corruption
    ;;
  fdw)
    fdw_outputdir="$results_root/fdw"
    mkdir -p "$fdw_outputdir"
    ln -sfn "$POMELODB_INSTALL_PREFIX/bin/extended_protocol_commit_test" \
      "$fdw_outputdir/extended_protocol_commit_test"
    pg_regress fdw "$SOURCE_TEST_ROOT/fdw" "$fdw_outputdir" \
      --load-extension=extended_protocol_commit_test_fdw \
      extended_protocol_commit_test
    run_command fdw-client 15m \
      "$POMELODB_INSTALL_PREFIX/bin/extended_protocol_commit_test"
    ;;
  locale)
    for locale_dir in \
      de_DE.ISO8859-1 gr_GR.ISO8859-7 koi8-r koi8-to-win1251; do
      run_in_directory "locale-$locale_dir" 15m \
        "$SOURCE_TEST_ROOT/locale/$locale_dir" ./runall
    done
    ;;
  authentication|recovery|kerberos|ldap)
    run_tap_suite "$SUITE-tap" "$SOURCE_TEST_ROOT/$SUITE"
    ;;
  ssl)
    run_in_directory ssl-certificates 15m "$SOURCE_TEST_ROOT/ssl" \
      ./configure_ssl.sh
    run_tap_suite ssl-tap "$SOURCE_TEST_ROOT/ssl" t/*.pl
    pg_regress ssl-regression "$SOURCE_TEST_ROOT/ssl" "$results_root/ssl" \
      --init-file="$SOURCE_TEST_ROOT/ssl/init_file_ssl_connection" \
      --dbname=test_sslconnection --schedule="$SOURCE_TEST_ROOT/ssl/ssl_connection_schedule" \
      --user=ssltestuser --host=127.0.0.1 --sslmode=verify-full
    run_in_directory ssl-cleanup 15m "$SOURCE_TEST_ROOT/ssl" ./clear_ssl.sh
    ;;
  modules)
    module_root="$SOURCE_TEST_ROOT/modules"
    for module_dir in "$module_root"/*; do
      [[ -d "$module_dir" ]] || continue
      module_name="$(basename "$module_dir")"
      if compgen -G "$module_dir/sql/*.sql" > /dev/null; then
        tests=()
        for sql_file in "$module_dir"/sql/*.sql; do
          tests+=("$(basename "$sql_file" .sql)")
        done
        # pgxs.mk adds --dbname=$(CONTRIB_TESTDB) for every module's
        # regression tests.  Keep the native runner on the same database;
        # several modules create extension objects there and their expected
        # dumps depend on that database name.
        module_regress_args=("--dbname=contrib_regression")
        case "$module_name" in
          test_extensions)
            # test_extdepend is intentionally excluded by the module's
            # Makefile until GPDB issue 14532 is resolved.
            tests=(test_extensions)
            ;;
          test_rls_hooks)
            module_regress_args+=("--temp-config=$module_dir/rls_hooks.conf")
            ;;
          commit_ts)
            module_regress_args+=("--temp-config=$module_dir/commit_ts.conf")
            ;;
          worker_spi)
            module_regress_args+=("--temp-config=$module_dir/dynamic.conf")
            ;;
        esac
        pg_regress "module-$module_name" "$module_dir" \
          "$results_root/$module_name" "${module_regress_args[@]}" "${tests[@]}"
      fi
      if compgen -G "$module_dir/specs/*.spec" > /dev/null; then
        tests=()
        for spec_file in "$module_dir"/specs/*.spec; do
          tests+=("$(basename "$spec_file" .spec)")
        done
        module_isolation_args=()
        case "$module_name" in
          snapshot_too_old)
            module_isolation_args+=("--temp-config=$module_dir/sto.conf")
            ;;
        esac
        pg_isolation_regress "module-$module_name-isolation" "$module_dir" \
          "$results_root/$module_name-isolation" \
          "${module_isolation_args[@]}" "${tests[@]}"
      fi
      if compgen -G "$module_dir/t/*.pl" > /dev/null; then
        run_tap_suite "module-$module_name-tap" "$module_dir"
      fi
    done
    ;;
  vacuum_progress_row|vacuum_progress_column)
    schedule_file="$RUNNER_TEMP/${SUITE}.schedule"
    printf 'test: %s\n' "$SUITE" > "$schedule_file"
    run_in_directory "$SUITE" 20m "$SOURCE_TEST_ROOT/isolation2" \
      "$POMELODB_INSTALL_PREFIX/bin/pg_isolation2_regress" \
      --inputdir="$SOURCE_TEST_ROOT/isolation2" \
      --outputdir="$results_root" \
      --bindir="$POMELODB_INSTALL_PREFIX/bin" \
      --dlpath="$POMELODB_INSTALL_PREFIX/lib/postgresql" \
      --init-file="$SOURCE_TEST_ROOT/regress/init_file" \
      --init-file="$SOURCE_TEST_ROOT/isolation2/init_file_isolation2" \
      --schedule="$schedule_file" --load-extension=gp_inject_fault \
      --max-concurrent-tests=1
    ;;
  *)
    echo "unknown source-test suite: $SUITE" >&2
    record_status invalid-suite 2
    ;;
  esac

printf 'suite_status=%s\n' "$suite_status" >> "$status_file"
exit "$suite_status"
