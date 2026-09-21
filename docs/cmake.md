# Native CMake and Ninja builds

The top-level project is built directly by CMake. It does not invoke
Autoconf `configure`, GNU Make, or a generated legacy installation graph.
Ninja is recommended for parallel builds.

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

On macOS, accept the Xcode license before compiling:

```sh
sudo xcodebuild -license accept
brew install apr apr-util libevent libyaml ninja
```

The build produces the backend, client programs, `gpfdist`, `libpq`, PL/pgSQL,
`dict_snowball`, and `gp_exttable_fdw`. Generated headers, catalog files,
parser sources, timezone data, and extension modules are regular CMake build
dependencies.

Boolean options use `GPDB_ENABLE_*` and `GPDB_WITH_*`. Dependency locations
can be supplied with `GPDB_INCLUDES`, `GPDB_LIBRARIES`, and
`GPDB_APR_CONFIG`; compiler flags use the standard CMake variables or the
`GPDB_CPPFLAGS`, `GPDB_CFLAGS`, `GPDB_CXXFLAGS`, and `GPDB_LDFLAGS` cache
variables. CMake automatically uses `ccache` when the Ninja generator finds it.

The installed `pomelodb.conf` controls the single-host MPP layout. Source it
from the installed root for client and server paths, then use the installed
`initdb` once for each configured data directory. Run `pomelodb init` to write
the separated log configuration, instance identity, and initial
`gp_segment_configuration` rows; then use `pomelodb` to start, stop, reload,
or inspect the local coordinator and segment processes.
