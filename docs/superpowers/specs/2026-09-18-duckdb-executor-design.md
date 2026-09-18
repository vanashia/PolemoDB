# PomeloDB DuckDB Executor Design

## Goal

Embed the DuckDB execution engine from `git@github.com:duckdb/duckdb.git` into
PomeloDB and provide a native CMake-built SQL entry point that can execute a
normal `SELECT` locally without Docker, Podman, or the historical `configure`
build path.

## Current constraints

- PomeloDB is a Greenplum/PostgreSQL-derived tree whose existing top-level
  CMake entry point still drives the legacy build for the full server.
- There is no existing DuckDB dependency, executor facade, or standalone SQL
  entry point in the tree.
- The DuckDB source is integrated as a pinned git submodule under
  `third_party/duckdb`; builds use DuckDB's native `duckdb_static` CMake target.
- The first runtime boundary is process-local: the PomeloDB wrapper owns one
  DuckDB database and connection per executor instance. It does not pass
  DuckDB C++ objects into PostgreSQL memory contexts.

## Design

### Executor facade

`PomeloDuckDBExecutor` is a small C++ class with RAII ownership of
`duckdb::DuckDB` and `duckdb::Connection`. Its public API returns PomeloDB-owned
values rather than DuckDB types:

```cpp
struct QueryResult {
  std::vector<std::string> column_names;
  std::vector<std::string> column_types;
  std::vector<std::vector<std::string>> rows;
};

class PomeloDuckDBExecutor {
 public:
  explicit PomeloDuckDBExecutor(std::string database_path = ":memory:");
  QueryResult Execute(std::string_view sql);
};
```

`Execute` calls DuckDB's blocking `Connection::Query`, checks
`QueryResult::HasError`, iterates `DataChunk`s, and converts values to stable
text using DuckDB's `Value::ToString`. NULL is represented by the explicit
string `NULL`; this keeps the first external interface deterministic and avoids
an accidental dependency on PostgreSQL's `Datum` representation.

### SQL entry point

`pomelodb-sql` uses the facade and accepts SQL from command-line arguments or
stdin. It prints DuckDB's column names followed by tab-separated rows and
returns non-zero with the DuckDB error text on failure. This is the initial
normal SQL path for verifying that PomeloDB embeds and executes DuckDB; the
existing Greenplum server executor is not silently replaced.

### Build integration

- Add DuckDB as a git submodule and make checkout workflows fetch submodules.
- Add a CMake option `POMELODB_WITH_DUCKDB` defaulting to `ON`.
- Disable DuckDB's shell and unit-test targets when embedded, while retaining
  its static library target.
- Build `pomelodb_duckdb_executor`, `pomelodb-sql`, and a CTest executable only
  through native CMake. No Docker/Podman or `configure` command is introduced.
- Keep the integration opt-out available with
  `-DPOMELODB_WITH_DUCKDB=OFF` for environments that intentionally omit the
  submodule.

### Error and lifecycle rules

- Constructor failures become C++ exceptions with the database path.
- SQL errors become C++ exceptions containing DuckDB's original message.
- Each executor instance owns its connection and is destroyed before its
  database, via member declaration order and RAII.
- The facade is not shared across threads in the first version; callers create
  one instance per execution context.

## Verification

The required checks are:

1. A unit/integration test executes `SELECT 1 + 1 AS answer` and asserts one
   column named `answer` with one row containing `2`.
2. A second test executes `SELECT * FROM (VALUES (1, 'pomelo'))` and verifies
   two columns and row conversion.
3. A failure test executes invalid SQL and verifies that an exception contains
   DuckDB's error text.
4. `pomelodb-sql 'SELECT 42 AS answer'` exits zero and prints `42`.
5. Native CMake configure/build/CTest succeeds with the local submodule and
   with `POMELODB_WITH_DUCKDB=OFF`.

## Non-goals for this integration

- Replacing Greenplum's distributed executor or planner.
- Making DuckDB read PostgreSQL/Greenplum catalog tables automatically.
- Adding Docker, Podman, or a configure-based DuckDB build path.
