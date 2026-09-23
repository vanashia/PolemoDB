#!/usr/bin/env bash
set -Eeuo pipefail

: "${BUILD_ARTIFACT_DIR:?BUILD_ARTIFACT_DIR is required}"

mkdir -p /tmp/pomelodb-build /tmp/pomelodb-install "$BUILD_ARTIFACT_DIR"
cmake -S /workspace -B /tmp/pomelodb-build -G Ninja \
  -DCMAKE_BUILD_TYPE=Debug \
  -DCMAKE_INSTALL_PREFIX=/tmp/pomelodb-install \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  -DGPDB_ENABLE_DEBUG_EXTENSIONS=ON \
  -DGPDB_ENABLE_ORCA=ON \
  -DGPDB_WITH_PERL=ON \
  -DGPDB_WITH_PYTHON=ON \
  -DGPDB_WITH_OPENSSL=ON \
  -DGPDB_WITH_GSSAPI=ON \
  -DGPDB_WITH_LDAP=ON \
  -DGPDB_WITH_LIBXML=ON \
  -DGPDB_WITH_ZLIB=ON \
  -DGPDB_WITH_LIBBZ2=ON \
  -DGPDB_WITH_LIBCURL=ON \
  -DGPDB_WITH_ZSTD=ON \
  -DGPDB_APR_CONFIG=/usr/bin/apr-1-config

cmake --build /tmp/pomelodb-build --target gpdb gpdb-source-test-tools --parallel 2
cmake --install /tmp/pomelodb-build --prefix /tmp/pomelodb-install

test -x /tmp/pomelodb-install/bin/pg_regress
test -x /tmp/pomelodb-install/bin/pg_isolation_regress
test -r /tmp/pomelodb-install/lib/postgresql/citext.so
test -r /tmp/pomelodb-install/lib/postgresql/gpextprotocol.so
test -d /tmp/pomelodb-install/share/postgresql/source-tests
tar -C /tmp -czf "$BUILD_ARTIFACT_DIR/pomelodb-native.tar.gz" pomelodb-install
