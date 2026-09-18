# DuckDB Executor Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Embed the pinned DuckDB source in PomeloDB and expose a native CMake-built executor and SQL command that execute `SELECT` locally.

**Architecture:** DuckDB is built as a static subdirectory target. A focused C++ facade owns DuckDB's database and connection, converts query chunks to PomeloDB-owned strings, and is consumed by a small `pomelodb-sql` command and CTest executable. The existing Greenplum server executor remains unchanged.

**Tech Stack:** CMake 3.20+, C++17, DuckDB `duckdb_static`, CTest, git submodule.

**Spec:** `docs/superpowers/specs/2026-09-18-duckdb-executor-design.md`

## Global Constraints

- Build and test with native CMake only; do not invoke `configure`, Docker, or Podman.
- Use the pinned git submodule at `third_party/duckdb` and DuckDB's `duckdb_static` target.
- Keep DuckDB C++ types inside the facade; the public result uses PomeloDB-owned strings.
- Preserve an opt-out `POMELODB_WITH_DUCKDB=OFF` configuration.
- Every behavior change follows a red-green test cycle.

### Task 1: Add the pinned DuckDB source dependency

**Files:**
- Create: `.gitmodules`
- Create: `third_party/duckdb` gitlink at the selected DuckDB commit
- Modify: `.github/workflows/ci.yml`
- Test: repository submodule and workflow configuration checks

**Interfaces:**
- Produces a checkoutable `third_party/duckdb` source tree containing DuckDB's CMake targets.

- [x] **Step 1: Add the submodule declaration and update CI checkout.**

Use HTTPS in `.gitmodules` so GitHub-hosted runners can fetch the public source,
while retaining the requested DuckDB repository as the source of truth:

```ini
[submodule "third_party/duckdb"]
    path = third_party/duckdb
    url = https://github.com/duckdb/duckdb.git
```

Set `submodules: recursive` on the existing `actions/checkout` step.

- [x] **Step 2: Verify the dependency is present and pinned.**

Run:

```bash
git submodule status -- third_party/duckdb
git -C third_party/duckdb rev-parse HEAD
```

Expected: the path is checked out at the commit recorded by the gitlink.

- [x] **Step 3: Commit the dependency metadata.**

```bash
git add .gitmodules third_party/duckdb .github/workflows/ci.yml
git commit -m "build: add DuckDB source submodule"
```

### Task 2: Add CMake target wiring

**Files:**
- Modify: `CMakeLists.txt`
- Create: `cmake/PomeloDuckDB.cmake`
- Test: CMake configure with DuckDB ON and OFF

**Interfaces:**
- Produces target `pomelodb_duckdb_executor` and cache option `POMELODB_WITH_DUCKDB`.

- [x] **Step 1: Write a failing CMake validation test.**

Extend the existing CMake interface test to assert that the ON configuration
declares the executor target and that the OFF configuration does not require the
submodule.

- [x] **Step 2: Run the validation test and verify it fails.**

Run:

```bash
cmake -S . -B /tmp/pomelodb-duckdb-cmake-test -G Ninja -DGPDB_SKIP_CONFIGURE=ON
ctest --test-dir /tmp/pomelodb-duckdb-cmake-test -R gpdb-cmake-interface --output-on-failure
```

Expected: FAIL because the DuckDB option and target do not exist.

- [x] **Step 3: Add the minimal DuckDB CMake integration.**

Before `add_subdirectory(third_party/duckdb ...)`, set `BUILD_SHELL=OFF`,
`BUILD_UNITTESTS=OFF`, and the embedded build options. Add the wrapper source
through `add_library(pomelodb_duckdb_executor ...)` and link it publicly to
`duckdb_static`.

- [x] **Step 4: Run ON and OFF configure tests.**

```bash
cmake -S . -B /tmp/pomelodb-duckdb-on -G Ninja -DGPDB_SKIP_CONFIGURE=ON -DPOMELODB_WITH_DUCKDB=ON
cmake -S . -B /tmp/pomelodb-duckdb-off -G Ninja -DGPDB_SKIP_CONFIGURE=ON -DPOMELODB_WITH_DUCKDB=OFF
```

Expected: both configure successfully; ON exposes the DuckDB target and OFF
does not touch the submodule.

- [x] **Step 5: Commit the build wiring.**

```bash
git add CMakeLists.txt cmake/PomeloDuckDB.cmake cmake/tests
git commit -m "build: wire DuckDB into native CMake"
```

### Task 3: Implement the executor facade using TDD

**Files:**
- Create: `src/duckdb/pomelodb_duckdb_executor.h`
- Create: `src/duckdb/pomelodb_duckdb_executor.cpp`
- Create: `src/duckdb/test/pomelodb_duckdb_executor_test.cpp`
- Modify: `CMakeLists.txt` or `cmake/PomeloDuckDB.cmake`

**Interfaces:**
- Produces `pomelodb::duckdb::QueryResult` and `PomeloDuckDBExecutor::Execute(std::string_view)`.

- [x] **Step 1: Write the failing SELECT test.**

```cpp
TEST(PomeloDuckDBExecutor, ExecutesArithmeticSelect) {
  PomeloDuckDBExecutor executor;
  auto result = executor.Execute("SELECT 1 + 1 AS answer");
  ASSERT_EQ(result.column_names, std::vector<std::string>{"answer"});
  ASSERT_EQ(result.rows, std::vector<std::vector<std::string>>{{"2"}});
}
```

- [x] **Step 2: Run the test and verify the expected missing-symbol failure.**

Run the focused CTest target and confirm failure because the facade is not yet implemented.

- [x] **Step 3: Implement the minimal RAII facade.**

Construct `duckdb::DuckDB` and `duckdb::Connection`, call `Query`, throw on
`HasError`, fetch `DataChunk`s, and convert every value through `Value::IsNull`
and `Value::ToString`.

- [x] **Step 4: Run the focused test and verify it passes.**

Run the same CTest target; expected: PASS.

- [x] **Step 5: Add row conversion and error tests, then repeat red-green.**

Cover a two-column `VALUES` query and invalid SQL. Assert the public result and
error message, not DuckDB internal object state.

- [x] **Step 6: Commit the facade and tests.**

```bash
git add src/duckdb cmake CMakeLists.txt
git commit -m "feat: add embedded DuckDB executor facade"
```

### Task 4: Add the `pomelodb-sql` executable

**Files:**
- Create: `src/bin/pomelodb-sql/main.cpp`
- Modify: `cmake/PomeloDuckDB.cmake`
- Create: `src/bin/pomelodb-sql/README.md`
- Test: CTest command-line smoke test

**Interfaces:**
- Produces executable `pomelodb-sql`.
- Accepts one SQL argument or reads SQL from stdin.
- Exit 0 for successful SQL and non-zero with the DuckDB error on failure.

- [x] **Step 1: Write a failing executable smoke test.**

Register a CTest test that invokes:

```text
pomelodb-sql "SELECT 42 AS answer"
```

and checks the output contains `answer` and `42`.

- [x] **Step 2: Run CTest and verify the executable is missing.**

Expected: FAIL because the target has not been created.

- [x] **Step 3: Implement the command with the facade.**

Join command-line SQL arguments with spaces, otherwise read all stdin, execute
once, print the header and rows as tab-separated text, and catch `std::exception`
to report errors and return `1`.

- [x] **Step 4: Run the smoke test and direct command.**

```bash
ctest --test-dir build-duckdb --output-on-failure -R pomelodb-sql
build-duckdb/pomelodb-sql 'SELECT 42 AS answer'
```

Expected: CTest passes and the command prints `answer` and `42`.

- [x] **Step 5: Commit the executable.**

```bash
git add src/bin/pomelodb-sql cmake/PomeloDuckDB.cmake
git commit -m "feat: add PomeloDB DuckDB SQL entry point"
```

### Task 5: Documentation and full verification

**Files:**
- Modify: `README.md`
- Modify: `docs/pomelodb.md` or create `docs/duckdb.md`
- Test: complete native CMake build and CTest suite

- [x] **Step 1: Document local setup and no-container build.**

Document `git clone --recurse-submodules`, native Ninja configure/build, the
SQL command, stdin usage, and the `POMELODB_WITH_DUCKDB=OFF` fallback.

- [x] **Step 2: Build all DuckDB integration targets and run the complete CTest suite.**

```bash
cmake -S . -B build-duckdb -G Ninja -DGPDB_SKIP_CONFIGURE=ON -DPOMELODB_WITH_DUCKDB=ON
cmake --build build-duckdb --parallel 4
ctest --test-dir build-duckdb --output-on-failure
```

- [x] **Step 3: Run the direct SELECT smoke test.**

```bash
build-duckdb/pomelodb-sql 'SELECT 1 + 1 AS answer'
```

Expected: exit code 0, header `answer`, and value `2`.

- [x] **Step 4: Verify the opt-out configure.**

```bash
cmake -S . -B /tmp/pomelodb-duckdb-off-final -G Ninja \
  -DGPDB_SKIP_CONFIGURE=ON -DPOMELODB_WITH_DUCKDB=OFF
```

- [x] **Step 5: Review the final diff and commit.**

```bash
git diff --check
git status --short
git log --oneline -5
```

Only after all commands exit zero, commit the final documentation and verified
integration changes.
