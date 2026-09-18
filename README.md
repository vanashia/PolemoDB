# PomeloDB

<p align="center">
  <img src="logo-pomelodb.png" alt="PomeloDB" width="180">
</p>

<p align="center">
  A PostgreSQL-based distributed analytical database.
</p>

[![PomeloDB CI](https://github.com/vanashia/PolemoDB/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/vanashia/PolemoDB/actions/workflows/ci.yml)
[![ABI tests](https://github.com/vanashia/PolemoDB/actions/workflows/greenplum-abi-tests.yml/badge.svg?branch=main)](https://github.com/vanashia/PolemoDB/actions/workflows/greenplum-abi-tests.yml)

PomeloDB is a distributed analytical database derived from the PostgreSQL and
Greenplum codebases. A cluster has a coordinator and multiple segment servers:
the coordinator accepts client connections and dispatches query work to the
segments, where user data is stored.

The project is released under the [Apache License 2.0](http://www.apache.org/licenses/LICENSE-2.0).

## Build with CMake and Ninja

CMake with Ninja is the supported build entry point for PomeloDB. The normal
installation prefix is `/usr/local/pomelodb`; the build does not use the legacy
`configure`/GNU Make workflow.

Install the platform dependencies described in [README.macOS.md](README.macOS.md)
or [README.Linux.md](README.Linux.md). `gpfdist` also requires `apr-1-config`
from APR. More CMake-specific notes are in [docs/cmake.md](docs/cmake.md).

```sh
git submodule update --init --recursive

cmake -S . -B build-ninja -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr/local/pomelodb \
  -DGPDB_WITH_PERL=ON \
  -DGPDB_WITH_PYTHON=ON \
  -DGPDB_WITH_LIBXML=ON \
  -DGPDB_WITH_GSSAPI=ON

cmake --build build-ninja --target gpdb --parallel
cmake --install build-ninja
```

Ninja can be installed with Homebrew on macOS (`brew install ninja apr`) or
with the distribution package manager on Linux. If it is not available as a
system package, the CMake guide shows how to install it into a local virtual
environment.

## Local instance layout

The installation includes `bin/pomelodb` and the configuration file
`/usr/local/pomelodb/pomelodb.conf`. By default, database files and logs are
kept in separate directories under the installation prefix:

```conf
data_directory=data
log_directory=log
```

Relative paths are resolved from `/usr/local/pomelodb`; absolute paths are also
supported. `data_directory` and `log_directory` must not be the same directory
or nested below one another. See [docs/pomelodb.md](docs/pomelodb.md) for all
available settings and lifecycle commands.

```sh
export PATH="/usr/local/pomelodb/bin:$PATH"

pomelodb init
pomelodb start
pomelodb status
pomelodb reload
pomelodb stop
```

`pomelodb` reads `pomelodb.conf` as configuration data; it is not executed as
a shell script. The manager configures PostgreSQL logging so that runtime logs
go to the configured log directory, separately from the data directory.

## Embedded DuckDB SQL executor

PomeloDB also embeds DuckDB as a native CMake dependency for local SQL
execution. The DuckDB source is tracked as a git submodule, so clone the
repository recursively or run `git submodule update --init --recursive` before
configuring. The integration is enabled by default and can be disabled with
`-DPOMELODB_WITH_DUCKDB=OFF`.

```sh
cmake -S . -B build-duckdb -G Ninja \
  -DGPDB_SKIP_CONFIGURE=ON \
  -DGPDB_ENABLE_NATIVE_TARGETS=ON \
  -DPOMELODB_WITH_DUCKDB=ON
cmake --build build-duckdb --target pomelodb-sql --parallel

build-duckdb/pomelodb-sql 'SELECT 1 + 1 AS answer'
printf 'SELECT 42 AS answer\n' | build-duckdb/pomelodb-sql
```

This is an embedded/local SQL entry point backed by DuckDB; it does not replace
the existing distributed PomeloDB coordinator and segment execution path.

## Tests

After configuring the build, run the CMake tests and the PomeloDB manager tests:

```sh
ctest --test-dir build-ninja --output-on-failure
python3 -m py_compile gpMgmt/bin/pomelodb
python3 gpMgmt/bin/test/pomelodb_test.py
```

GitHub Actions runs the supported build and test matrix on Linux and macOS.
The workflow uses Ninja and ccache; see [.github/workflows/ci.yml](.github/workflows/ci.yml).
The separate [source-test workflow](.github/workflows/src-tests.yml) runs the
`src/test` check suites, optional SSL/Kerberos/LDAP tests, and locale suites on
Ubuntu.

## Repository layout

- `src/` — PostgreSQL-derived database engine and extensions.
- `gpMgmt/` — cluster and local-instance management tools.
- `gpAux/` — Greenplum/PomeloDB support scripts and dependencies.
- `gpcontrib/` — database extensions and `gpfdist`.
- `docs/` — PomeloDB build and runtime documentation.

## Contributing

Please open an issue or pull request in the
[PomeloDB repository](https://github.com/vanashia/PolemoDB). Include the
relevant test command and result when submitting a change.
