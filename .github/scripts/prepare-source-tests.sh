#!/usr/bin/env bash
set -euo pipefail

: "${GITHUB_WORKSPACE:?GITHUB_WORKSPACE is required}"
: "${GPDB_LEGACY_BUILD_DIR:?GPDB_LEGACY_BUILD_DIR is required}"

for helper in atmsort.pm explain.pm; do
  ln -sf "$GITHUB_WORKSPACE/src/test/regress/$helper" \
    "$GPDB_LEGACY_BUILD_DIR/src/test/regress/$helper"
done
for test_dir in isolation isolation2; do
  for helper in gpdiff.pl gpstringsubs.pl atmsort.pm explain.pm GPTest.pm; do
    ln -sf "$GPDB_LEGACY_BUILD_DIR/src/test/regress/$helper" \
      "$GPDB_LEGACY_BUILD_DIR/src/test/$test_dir/$helper"
  done
done
ln -sfn "$GITHUB_WORKSPACE/src/test/regress/init_file" \
  "$GPDB_LEGACY_BUILD_DIR/src/test/regress/init_file"
for init_file in \
  init_file_isolation2 \
  init_file_parallel_retrieve_cursor \
  init_file_resgroup; do
  ln -sfn "$GITHUB_WORKSPACE/src/test/isolation2/$init_file" \
    "$GPDB_LEGACY_BUILD_DIR/src/test/isolation2/$init_file"
done
for helper in sql_isolation_testcase.py global_sh_executor.sh; do
  ln -sfn "$GITHUB_WORKSPACE/src/test/isolation2/$helper" \
    "$GPDB_LEGACY_BUILD_DIR/src/test/isolation2/$helper"
done
ln -sfn "$GITHUB_WORKSPACE/src/test/isolation2/script" \
  "$GPDB_LEGACY_BUILD_DIR/src/test/isolation2/script"

sync_tree() {
  local source_root="$1"
  local destination_root="$2"
  mkdir -p "$destination_root"
  while IFS= read -r -d '' source_path; do
    local relative_path="${source_path#"$source_root/"}"
    mkdir -p "$destination_root/$(dirname "$relative_path")"
    ln -sfn "$source_path" "$destination_root/$relative_path"
  done < <(find "$source_root" \( -type f -o -type l \) -print0)
}

# Regression SQL and locale tests run from the external legacy build directory,
# while pg_regress reads schedules from the source checkout.
sync_tree "$GITHUB_WORKSPACE/src/test/regress/sql" \
  "$GPDB_LEGACY_BUILD_DIR/src/test/regress/sql"
sync_tree "$GITHUB_WORKSPACE/src/test/regress/data" \
  "$GPDB_LEGACY_BUILD_DIR/src/test/regress/data"
sync_tree "$GITHUB_WORKSPACE/src/test/locale" \
  "$GPDB_LEGACY_BUILD_DIR/src/test/locale"
ln -sfn "$GITHUB_WORKSPACE/src/test/regress/test_dbconn.py" \
  "$GPDB_LEGACY_BUILD_DIR/src/test/regress/test_dbconn.py"
ln -sfn "$GITHUB_WORKSPACE/src/test/regress/data" \
  "$GITHUB_WORKSPACE/src/test/isolation2/data"
test -r "$GITHUB_WORKSPACE/src/test/isolation2/data/exttab_few_errors.data"

test -r "$GPDB_LEGACY_BUILD_DIR/src/test/regress/GPTest.pm"
"$GPDB_LEGACY_BUILD_DIR/src/test/regress/gpdiff.pl" -V
