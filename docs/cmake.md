# CMake and Ninja builds

The top-level CMake project exposes the existing Greenplum `configure`
interface through CMake cache variables and can be generated with any CMake
generator, including Ninja. The legacy Autoconf/GNU Make entry point remains
available for existing packaging and CI workflows.

For example:

```sh
command -v ninja >/dev/null || {
  python3 -m venv .gpdb-build-tools
  .gpdb-build-tools/bin/pip install ninja
  export PATH="$PWD/.gpdb-build-tools/bin:$PATH"
}
cmake -S . -B build-ninja -G Ninja \
  -DCMAKE_INSTALL_PREFIX=/usr/local/pomelodb \
  -DGPDB_WITH_PERL=ON -DGPDB_WITH_PYTHON=ON \
  -DGPDB_WITH_LIBXML=ON -DGPDB_WITH_GSSAPI=ON
cmake --build build-ninja --target gpdb
cmake --install build-ninja
```

The default build enables `gpfdist`, which requires APR's `apr-1-config`.
Install the APR development package before configuring, or pass its exact path
when it is outside `PATH`:

```sh
cmake -S . -B build-ninja -G Ninja \
  -DGPDB_APR_CONFIG=/path/to/apr-1-config
```

On macOS, accept the Xcode license before using Homebrew or compiling:

```sh
sudo xcodebuild -license accept
brew install apr ninja
```

The reusable frontend libraries are also native CMake targets and can be
built independently with `cmake --build build-ninja --target
gpdb-native-libraries`; the aliases `gpdb::pgport`, `gpdb::pgcommon`,
`gpdb::pgfeutils`, and `gpdb::libpq` are available to downstream CMake code.
They are an optional frontend subset and are not part of the complete `gpdb`
target by default; set `GPDB_BUILD_NATIVE_TARGETS_WITH_GPDB=ON` only when that
subset's dependency configuration is also wanted.

`cmake --install` delegates to the existing full installation graph, so it
installs the server, procedural languages, contrib modules, and all libraries
selected by `configure`. This avoids replacing files from the authoritative
full installation with the partial native-CMake frontend target set.

Boolean `--enable-*` options use `GPDB_ENABLE_*`; boolean `--with-*` options
use `GPDB_WITH_*` (including `GPDB_WITH_LDAP`). Value options use the
corresponding names such as `GPDB_EXEC_PREFIX`, `GPDB_PGPORT`,
`GPDB_BLOCKSIZE`, `GPDB_INCLUDES`, and `GPDB_LIBRARIES`.
`GPDB_CONFIGURE_EXTRA_ARGS` accepts additional configure arguments as a
semicolon-separated CMake list. `GPDB_CONFIGURE_ENV` accepts `NAME=VALUE`
entries for package-specific flags or tool paths. Standard CMake compiler and
linker flags are forwarded; `GPDB_CFLAGS`, `GPDB_CXXFLAGS`, `GPDB_LDFLAGS`,
and `GPDB_CPPFLAGS` provide GPDB-specific additions. Tool and dependency
overrides from `configure --help` (for example `GPDB_CPP`,
`GPDB_PKG_CONFIG_LIBDIR`, `GPDB_LLVM_CONFIG`, and `GPDB_ZSTD_LIBS`) are
available as cache variables with the same `GPDB_` prefix.

The configure-generated Makefiles are kept in `GPDB_LEGACY_BUILD_DIR`, which
defaults to a directory inside the CMake build tree. This isolates generated
files from the source tree while preserving the exact existing source,
generated-header, platform, and third-party-library rules during this
compatibility phase.
