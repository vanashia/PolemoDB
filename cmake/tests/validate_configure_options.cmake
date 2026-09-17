cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED GPDB_SOURCE_DIR)
  message(FATAL_ERROR "GPDB_SOURCE_DIR is required")
endif()

set(_cmake_file "${GPDB_SOURCE_DIR}/CMakeLists.txt")
if(NOT EXISTS "${_cmake_file}")
  message(FATAL_ERROR "missing top-level CMakeLists.txt")
endif()

file(READ "${_cmake_file}" _cmake)
file(READ "${GPDB_SOURCE_DIR}/cmake/GPDBNativeLibraries.cmake" _native_cmake)
file(READ "${GPDB_SOURCE_DIR}/src/bin/pg_upgrade/Makefile" _pg_upgrade_makefile)
string(FIND "${_pg_upgrade_makefile}" "$(LN_S) $(abspath $<) aomd_filehandler.c" _pg_upgrade_vpath_link)
if(_pg_upgrade_vpath_link EQUAL -1)
  message(FATAL_ERROR "pg_upgrade must link aomd_filehandler.c with its absolute prerequisite path")
endif()
file(READ "${GPDB_SOURCE_DIR}/src/test/regress/hooktest/Makefile" _hooktest_makefile)
string(FIND "${_hooktest_makefile}" "subdir = src/test/regress/hooktest" _hooktest_subdir)
if(_hooktest_subdir EQUAL -1)
  message(FATAL_ERROR "hooktest must use its real source directory for VPATH builds")
endif()
file(READ "${GPDB_SOURCE_DIR}/src/test/regress/GNUmakefile" _regress_makefile)
string(FIND "${_regress_makefile}"
  "$(CC) $(CPPFLAGS) -I$(libpq_srcdir) -L$(GPHOME)/lib -L$(top_builddir)/src/interfaces/libpq  -o $@ $< -lpq"
  _regress_libpq_source_include)
if(_regress_libpq_source_include EQUAL -1)
  message(FATAL_ERROR "regress helper clients must include libpq headers from the source tree")
endif()
file(READ "${GPDB_SOURCE_DIR}/gpMgmt/bin/stream/Makefile" _stream_makefile)
string(FIND "${_stream_makefile}" "subdir = gpMgmt/bin/stream" _stream_subdir)
if(_stream_subdir EQUAL -1)
  message(FATAL_ERROR "stream must declare its source directory for VPATH builds")
endif()
file(READ "${GPDB_SOURCE_DIR}/gpcontrib/gp_distribution_policy/Makefile" _distribution_policy_makefile)
string(FIND "${_distribution_policy_makefile}" "subdir = gpcontrib/gp_distribution_policy" _distribution_policy_subdir)
if(_distribution_policy_subdir EQUAL -1)
  message(FATAL_ERROR "gp_distribution_policy must use its real source directory for VPATH builds")
endif()
file(READ "${GPDB_SOURCE_DIR}/gpcontrib/gp_internal_tools/Makefile" _internal_tools_makefile)
string(FIND "${_internal_tools_makefile}" "subdir = gpcontrib/gp_internal_tools" _internal_tools_subdir)
if(_internal_tools_subdir EQUAL -1)
  message(FATAL_ERROR "gp_internal_tools must use its real source directory for VPATH builds")
endif()
foreach(_extension IN ITEMS gp_debug_numsegments gp_inject_fault gp_replica_check)
  file(READ "${GPDB_SOURCE_DIR}/gpcontrib/${_extension}/Makefile" _extension_makefile)
  string(FIND "${_extension_makefile}" "subdir = gpcontrib/${_extension}" _extension_subdir)
  if(_extension_subdir EQUAL -1)
    message(FATAL_ERROR "${_extension} must use its real source directory for VPATH builds")
  endif()
endforeach()
file(READ "${GPDB_SOURCE_DIR}/gpcontrib/pg_hint_plan/Makefile" _hint_plan_makefile)
string(FIND "${_hint_plan_makefile}" "subdir = gpcontrib/pg_hint_plan" _hint_plan_subdir)
if(_hint_plan_subdir EQUAL -1)
  message(FATAL_ERROR "pg_hint_plan must declare its source directory for VPATH builds")
endif()
file(READ "${GPDB_SOURCE_DIR}/gpcontrib/zstd/Makefile" _zstd_makefile)
string(FIND "${_zstd_makefile}" "subdir = gpcontrib/zstd" _zstd_subdir)
if(_zstd_subdir EQUAL -1)
  message(FATAL_ERROR "gpcontrib zstd must declare its source directory for VPATH builds")
endif()
string(FIND "${_zstd_makefile}" "CFLAGS_SL += $(ZSTD_CFLAGS)" _zstd_cflags)
string(FIND "${_zstd_makefile}" "LDFLAGS_SL += $(ZSTD_LIBS)" _zstd_libs)
if(_zstd_cflags EQUAL -1 OR _zstd_libs EQUAL -1)
  message(FATAL_ERROR "gpcontrib zstd must consume configure-discovered zstd flags")
endif()
string(FIND "${_cmake}" "GPDBInstall.cmake" _full_install_hook)
if(_full_install_hook EQUAL -1)
  message(FATAL_ERROR "cmake --install must invoke the complete GPDB install")
endif()
string(FIND "${_cmake}" "set(GPDB_LEGACY_BUILD_DIR" _legacy_dir_pos)
string(FIND "${_cmake}" "GPDBNativeLibraries.cmake" _native_include_pos)
if(_legacy_dir_pos EQUAL -1 OR _native_include_pos EQUAL -1 OR _legacy_dir_pos GREATER _native_include_pos)
  message(FATAL_ERROR "GPDB_LEGACY_BUILD_DIR must be initialized before native targets")
endif()
string(FIND "${_cmake}" "prep_buildtree scans every source subdirectory" _source_local_legacy_guard)
string(FIND "${_cmake}" "must be outside the source tree" _source_local_legacy_error)
if(_source_local_legacy_guard EQUAL -1 OR _source_local_legacy_error EQUAL -1)
  message(FATAL_ERROR "source-local CMake build trees must use an external legacy build directory")
endif()
string(FIND "${_cmake}" "Makefile.mock" _mock_makefile_prepare)
if(_mock_makefile_prepare EQUAL -1)
  message(FATAL_ERROR "legacy build trees must prepare src/Makefile.mock")
endif()
foreach(_option IN ITEMS
    RPATH SPINLOCKS ATOMICS STRONG_RANDOM GPFDIST DEBUG_EXTENSIONS ORAFCE DEBUG
    PROFILING COVERAGE DTRACE TAP_TESTS DEPEND CASSERT ORCA GPCLOUD IC_PROXY
    THREAD_SAFETY)
  string(FIND "${_cmake}" "GPDB_SUPPORTED_ENABLE_OPTIONS" _list_found)
  string(FIND "${_cmake}" "${_option}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing CMake option ${_option}")
  endif()
endforeach()
foreach(_option IN ITEMS INTEGER_DATETIMES LARGEFILE)
  string(FIND "${_cmake}" "GPDB_ENABLE_${_option}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing CMake option ${_option}")
  endif()
endforeach()

foreach(_option IN ITEMS LLVM ICU TCL PERL PYTHON GSSAPI PAM BSD_AUTH LDAP BONJOUR OPENSSL SELINUX SYSTEMD READLINE LIBEDIT_PREFERRED LIBXML LIBXSLT ZLIB LIBBZ2 ZSTD RT LIBCURL OSSP_UUID GNU_LD)
  string(FIND "${_cmake}" "GPDB_WITH_${_option}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing CMake with option ${_option}")
  endif()
endforeach()
string(FIND "${_cmake}" "\"LDAP;ldap\"" _ldap_mapping)
if(_ldap_mapping EQUAL -1)
  message(FATAL_ERROR "GPDB_WITH_LDAP must map to --with-ldap")
endif()
string(FIND "${_cmake}" "--exec-prefix=${GPDB_EXEC_PREFIX}" _exec_prefix_mapping)
if(_exec_prefix_mapping EQUAL -1)
  message(FATAL_ERROR "GPDB_EXEC_PREFIX must map to --exec-prefix")
endif()

# Exercise the mapping instead of only inspecting its implementation.  Native
# targets are disabled because this interface test deliberately has no C/C++
# compiler dependency.
set(_mapped_build_dir "${CMAKE_CURRENT_BINARY_DIR}/configure-option-mapping")
file(REMOVE_RECURSE "${_mapped_build_dir}")
set(_fake_make "${CMAKE_CURRENT_BINARY_DIR}/gpdb-test-make.sh")
file(WRITE "${_fake_make}" [=[#!/bin/sh
set -eu
build_dir=
prefix=
while [ "$#" -gt 0 ]; do
  case "$1" in
    -C) build_dir="$2"; shift 2 ;;
    prefix=*) prefix="${1#prefix=}"; shift ;;
    *) shift ;;
  esac
done
printf '%s\n' "$prefix" > "$build_dir/install-prefix.txt"
]=])
file(CHMOD "${_fake_make}"
     PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE WORLD_READ WORLD_EXECUTE)
execute_process(
  COMMAND "${CMAKE_COMMAND}" -S "${GPDB_SOURCE_DIR}" -B "${_mapped_build_dir}"
          -G "Unix Makefiles"
          -DGPDB_SKIP_CONFIGURE=ON
          -DGPDB_ENABLE_NATIVE_TARGETS=OFF
          -DGPDB_MAKE_PROGRAM=${_fake_make}
          -DCMAKE_INSTALL_PREFIX=/opt/gpdb
          -DCMAKE_INSTALL_BINDIR=/opt/gpdb-bin
          -DCMAKE_INSTALL_LIBDIR=/opt/gpdb-lib
          -DCMAKE_INSTALL_DOCDIR=/opt/gpdb-doc
          -DGPDB_EXEC_PREFIX=/opt/gpdb-exec
          -DGPDB_BUILD=x86_64-unknown-linux-gnu
          -DGPDB_HOST=aarch64-unknown-linux-gnu
          -DGPDB_WITH_LDAP=ON
          -DGPDB_ENABLE_CASSERT=ON
          -DGPDB_EXTRA_VERSION=-cmake
          -DGPDB_TEMPLATE=linux
          -DGPDB_INCLUDES=/opt/include
          -DGPDB_LIBRARIES=/opt/lib
          -DGPDB_LIBS_DIR=/opt/legacy-lib
          -DGPDB_PGPORT=15432
          -DGPDB_BLOCKSIZE=16
          -DGPDB_SEGSIZE=2
          -DGPDB_WAL_BLOCKSIZE=16
          -DGPDB_TCLCONFIG=/opt/tcl
          -DGPDB_KRB_SRVNAM=gpdb
          -DGPDB_UUID=e2fs
          -DGPDB_SYSTEM_TZDATA=/opt/zoneinfo
          -DGPDB_APR_CONFIG=/opt/bin/apr-1-config
          -DGPDB_CPP=/opt/bin/cpp
          -DGPDB_PKG_CONFIG_LIBDIR=/opt/pkgconfig
          -DGPDB_CFLAGS=-O3
          -DGPDB_CXXFLAGS=-O3
          -DGPDB_LDFLAGS=-Wl,-rpath,/opt/gpdb-lib
          -DGPDB_CONFIGURE_EXTRA_ARGS=--cache-file=/tmp/gpdb-config.cache
  RESULT_VARIABLE _mapping_result
  OUTPUT_VARIABLE _mapping_output
  ERROR_VARIABLE _mapping_error)
if(NOT _mapping_result EQUAL 0)
  message(FATAL_ERROR "CMake option mapping configure failed:\n${_mapping_output}\n${_mapping_error}")
endif()
file(READ "${_mapped_build_dir}/CMakeCache.txt" _mapping_cache)
foreach(_argument IN ITEMS
    --prefix=/opt/gpdb --bindir=/opt/gpdb-bin --libdir=/opt/gpdb-lib
    --docdir=/opt/gpdb-doc --exec-prefix=/opt/gpdb-exec
    --build=x86_64-unknown-linux-gnu --host=aarch64-unknown-linux-gnu
    --enable-cassert --with-ldap --with-extra-version=-cmake --with-template=linux
    --with-includes=/opt/include --with-libraries=/opt/lib --with-libs=/opt/legacy-lib
    --with-pgport=15432 --with-blocksize=16 --with-segsize=2 --with-wal-blocksize=16
    --with-tclconfig=/opt/tcl --with-krb-srvnam=gpdb --with-uuid=e2fs
    --with-system-tzdata=/opt/zoneinfo --with-apr-config=/opt/bin/apr-1-config
    --cache-file=/tmp/gpdb-config.cache)
  string(FIND "${_mapping_cache}" "${_argument}" _argument_pos)
  if(_argument_pos EQUAL -1)
    message(FATAL_ERROR "missing mapped configure argument ${_argument}")
  endif()
endforeach()
foreach(_environment IN ITEMS
    CPP=/opt/bin/cpp PKG_CONFIG_LIBDIR=/opt/pkgconfig CFLAGS=-O3 CXXFLAGS=-O3
    LDFLAGS=-Wl,-rpath,/opt/gpdb-lib)
  string(FIND "${_mapping_cache}" "${_environment}" _environment_pos)
  if(_environment_pos EQUAL -1)
    message(FATAL_ERROR "missing mapped configure environment ${_environment}")
  endif()
endforeach()

file(READ "${_mapped_build_dir}/CMakeFiles/gpdb.dir/build.make" _gpdb_build_rule)
string(REGEX MATCH "GPDB_LEGACY_BUILD_DIR:PATH=([^\n]+)" _legacy_cache_line "${_mapping_cache}")
if(NOT _legacy_cache_line)
  message(FATAL_ERROR "missing mapped legacy build directory")
endif()
set(_mapped_legacy_dir "${CMAKE_MATCH_1}")
string(FIND "${_gpdb_build_rule}" "${_fake_make} -C ${_mapped_legacy_dir} all" _build_rule_pos)
if(_build_rule_pos EQUAL -1)
  message(FATAL_ERROR "cmake --build gpdb does not invoke the complete legacy build")
endif()

# Exercise the generated install script with a harmless stand-in make command.
# It proves that `cmake --install` delegates to the complete legacy install
# graph and preserves CMake's --prefix override without compiling the database.
execute_process(
  COMMAND "${CMAKE_COMMAND}" --install "${_mapped_build_dir}"
          --prefix /opt/gpdb-cmake-install
  RESULT_VARIABLE _install_result
  OUTPUT_VARIABLE _install_output
  ERROR_VARIABLE _install_error)
if(NOT _install_result EQUAL 0)
  message(FATAL_ERROR "cmake --install delegation failed:\n${_install_output}\n${_install_error}")
endif()
file(READ "${_mapped_legacy_dir}/install-prefix.txt" _install_prefix)
string(STRIP "${_install_prefix}" _install_prefix)
if(NOT _install_prefix STREQUAL "/opt/gpdb-cmake-install")
  message(FATAL_ERROR "cmake --install did not pass its prefix to legacy install: ${_install_prefix}")
endif()

foreach(_value IN ITEMS
    GPDB_EXTRA_VERSION GPDB_EXEC_PREFIX GPDB_TEMPLATE GPDB_INCLUDES GPDB_LIBRARIES GPDB_PGPORT
    GPDB_BLOCKSIZE GPDB_SEGSIZE GPDB_WAL_BLOCKSIZE GPDB_CC GPDB_TCLCONFIG
    GPDB_KRB_SRVNAM GPDB_UUID GPDB_SYSTEM_TZDATA GPDB_APR_CONFIG
    GPDB_CFLAGS GPDB_CXXFLAGS GPDB_LDFLAGS GPDB_LDFLAGS_EX GPDB_LDFLAGS_SL)
  string(FIND "${_cmake}" "CACHE" _cache)
  string(FIND "${_cmake}" "${_value}" _found)
  if(_found EQUAL -1 OR _cache EQUAL -1)
    message(FATAL_ERROR "missing CMake cache variable ${_value}")
  endif()
endforeach()

foreach(_env_name IN ITEMS LLVM_CONFIG CLANG CPP PKG_CONFIG PKG_CONFIG_PATH PKG_CONFIG_LIBDIR ICU_CFLAGS ICU_LIBS XML2_CONFIG XML2_CFLAGS XML2_LIBS ZSTD_CFLAGS ZSTD_LIBS PERL PYTHON MSGFMT TCLSH)
  string(FIND "${_cmake}" "${_env_name}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing configure environment variable ${_env_name}")
  endif()
endforeach()

string(FIND "${_cmake}" "CMAKE_BUILD_TYPE" _build_type)
if(_build_type EQUAL -1)
  message(FATAL_ERROR "CMake build type is not forwarded to configure")
endif()

string(FIND "${_cmake}" "CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT" _prefix_default)
if(_prefix_default EQUAL -1)
  message(FATAL_ERROR "CMake default install prefix does not preserve configure semantics")
endif()

foreach(_library IN ITEMS Threads::Threads m ZLIB::ZLIB BZip2::BZip2 OpenSSL::SSL OpenSSL::Crypto LibXml2::LibXml2 CURL::libcurl ICU::uc ICU::i18n)
  string(FIND "${_cmake}" "${_library}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing library integration ${_library}")
  endif()
endforeach()

foreach(_target IN ITEMS pgport pgport_shlib pgport_srv pgcommon pgcommon_shlib pgcommon_srv pgfeutils libpq libpq_shared)
  string(FIND "${_native_cmake}" "add_library(${_target}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing native CMake library target ${_target}")
  endif()
endforeach()

foreach(_required IN ITEMS "POSITION_INDEPENDENT_CODE ON" "pgcommon_shlib pgport_shlib")
  string(FIND "${_native_cmake}" "${_required}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing shared-library CMake linkage detail: ${_required}")
  endif()
endforeach()
foreach(_required IN ITEMS "pg_config_paths.h" "utils/errcodes.h" "gpdb-generated-paths" "add_dependencies(pgport gpdb-generated-paths)")
  string(FIND "${_native_cmake}" "${_required}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing generated-path CMake dependency: ${_required}")
  endif()
endforeach()
foreach(_target IN ITEMS pg_config psql pg_waldump)
  string(FIND "${_native_cmake}" "add_executable(${_target}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing native CMake executable target ${_target}")
  endif()
endforeach()
string(FIND "${_cmake}" "GPDB_BUILD_NATIVE_TARGETS_WITH_GPDB" _native_all_option)
if(_native_all_option EQUAL -1)
  message(FATAL_ERROR "missing opt-in control for the optional native frontend subset")
endif()
foreach(_target IN ITEMS pg_basebackup pg_receivewal pg_recvlogical)
  string(FIND "${_native_cmake}" "gpdb_add_basebackup_client(${_target})" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing native CMake executable target ${_target}")
  endif()
endforeach()
foreach(_target IN ITEMS pg_archivecleanup pg_checksums pg_controldata pg_ctl pg_resetwal pg_test_fsync pg_test_timing)
  string(FIND "${_native_cmake}" "gpdb_add_simple_client(${_target})" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing native CMake executable target ${_target}")
  endif()
endforeach()
file(READ "${GPDB_SOURCE_DIR}/cmake/GPDBInstall.cmake.in" _install_cmake)
foreach(_required IN ITEMS "@GPDB_MAKE_PROGRAM@" "@GPDB_LEGACY_BUILD_DIR@" "install" "prefix=${CMAKE_INSTALL_PREFIX}")
  string(FIND "${_install_cmake}" "${_required}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing complete CMake install detail: ${_required}")
  endif()
endforeach()

string(FIND "${_cmake}" "GPDB_SKIP_CONFIGURE" _skip)
if(_skip EQUAL -1)
  message(FATAL_ERROR "missing configure-only validation mode")
endif()
foreach(_required IN ITEMS "gpdb-configure-signature" "file(SHA256" "config.status")
  string(FIND "${_cmake}" "${_required}" _found)
  if(_found EQUAL -1)
    message(FATAL_ERROR "missing configure signature cache detail: ${_required}")
  endif()
endforeach()

message(STATUS "CMake configure option/library coverage is present")
