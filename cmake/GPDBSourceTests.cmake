# Native CMake targets for the source-test programs and loadable test modules.
#
# This file intentionally contains no calls into the legacy configure/Make
# build.  The source-test binaries are built against the same native CMake
# libraries as the installed server and are consumed by the CI source-test
# artifact.

set(GPDB_SOURCE_TEST_BUILD_DIR "${CMAKE_BINARY_DIR}/source-tests")
set(GPDB_SOURCE_TEST_MODULE_DIR "${GPDB_SOURCE_TEST_BUILD_DIR}/modules")

function(gpdb_add_source_test_executable _target)
  add_executable(${_target} ${ARGN})
  gpdb_apply_common_options(${_target})
  add_dependencies(${_target} gpdb-generated)
  target_compile_definitions(${_target} PRIVATE FRONTEND)
  target_include_directories(${_target} PRIVATE
    ${_gpdb_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/backend"
    "${CMAKE_SOURCE_DIR}/src/port"
    "${GPDB_GENERATED_DIR}/src/port")
  target_link_libraries(${_target} PRIVATE pgcommon pgport gpdb-platform)
endfunction()

function(gpdb_add_source_test_module _target)
  add_library(${_target} MODULE ${ARGN})
  gpdb_apply_common_options(${_target})
  add_dependencies(${_target} gpdb-generated)
  target_include_directories(${_target} PRIVATE
    ${_gpdb_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/backend"
    "${GPDB_GENERATED_BACKEND_DIR}")
  set_target_properties(${_target} PROPERTIES
    PREFIX ""
    SUFFIX ".so"
    LIBRARY_OUTPUT_DIRECTORY "${GPDB_SOURCE_TEST_MODULE_DIR}")
  gpdb_apply_module_link_options(${_target})
endfunction()

# isolation uses bison's generated parser, which includes the flex scanner in
# the parser translation unit, matching src/test/isolation/Makefile.
set(_gpdb_isolation_build_dir "${GPDB_SOURCE_TEST_BUILD_DIR}/isolation")
set(_gpdb_isolation_parser "${_gpdb_isolation_build_dir}/specparse.c")
set(_gpdb_isolation_scanner "${_gpdb_isolation_build_dir}/specscanner.c")
add_custom_command(
  OUTPUT "${_gpdb_isolation_parser}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${_gpdb_isolation_build_dir}"
  COMMAND "${GPDB_BISON_EXECUTABLE}" -o "${_gpdb_isolation_parser}"
          "${CMAKE_SOURCE_DIR}/src/test/isolation/specparse.y"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/test/isolation/specparse.y"
          "${_gpdb_isolation_scanner}"
          "${CMAKE_SOURCE_DIR}/src/test/isolation/isolationtester.h"
  VERBATIM)
add_custom_command(
  OUTPUT "${_gpdb_isolation_scanner}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${_gpdb_isolation_build_dir}"
  COMMAND "${GPDB_FLEX_EXECUTABLE}" -o "${_gpdb_isolation_scanner}"
          "${CMAKE_SOURCE_DIR}/src/test/isolation/specscanner.l"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/test/isolation/specscanner.l"
  VERBATIM)

add_executable(isolationtester
  "${_gpdb_isolation_parser}"
  src/test/isolation/isolationtester.c)
gpdb_apply_common_options(isolationtester)
add_dependencies(isolationtester gpdb-generated)
target_compile_definitions(isolationtester PRIVATE FRONTEND)
target_include_directories(isolationtester PRIVATE
  ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend"
  "${CMAKE_SOURCE_DIR}/src/test/isolation"
  "${CMAKE_SOURCE_DIR}/src/port"
  "${GPDB_GENERATED_DIR}/src/port")
target_link_libraries(isolationtester PRIVATE libpq pgcommon pgport gpdb-platform)

add_executable(pg_isolation_regress
  src/test/regress/pg_regress.c
  src/test/isolation/isolation_main.c)
gpdb_apply_common_options(pg_isolation_regress)
add_dependencies(pg_isolation_regress gpdb-generated)
target_compile_definitions(pg_isolation_regress PRIVATE
  FRONTEND
  HOST_TUPLE="${CMAKE_SYSTEM_PROCESSOR}-${CMAKE_SYSTEM_NAME}"
  SHELLPROG="/bin/sh"
  DLSUFFIX=".so")
target_include_directories(pg_isolation_regress PRIVATE
  ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend"
  "${CMAKE_SOURCE_DIR}/src/test/regress"
  "${CMAKE_SOURCE_DIR}/src/test/isolation"
  "${CMAKE_SOURCE_DIR}/src/port"
  "${GPDB_GENERATED_DIR}/src/port")
target_link_libraries(pg_isolation_regress PRIVATE pgcommon pgport gpdb-platform)

add_executable(pg_isolation2_regress
  src/test/regress/pg_regress.c
  src/test/isolation2/isolation2_main.c)
gpdb_apply_common_options(pg_isolation2_regress)
add_dependencies(pg_isolation2_regress gpdb-generated)
target_compile_definitions(pg_isolation2_regress PRIVATE
  FRONTEND
  HOST_TUPLE="${CMAKE_SYSTEM_PROCESSOR}-${CMAKE_SYSTEM_NAME}"
  SHELLPROG="/bin/sh"
  DLSUFFIX=".so")
target_include_directories(pg_isolation2_regress PRIVATE
  ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend"
  "${CMAKE_SOURCE_DIR}/src/test/regress"
  "${CMAKE_SOURCE_DIR}/src/test/isolation2"
  "${CMAKE_SOURCE_DIR}/src/port"
  "${GPDB_GENERATED_DIR}/src/port")
target_link_libraries(pg_isolation2_regress PRIVATE pgcommon pgport gpdb-platform)

gpdb_add_source_test_module(isolation2_regress_module
  src/test/isolation2/isolation2_regress.c)
set_target_properties(isolation2_regress_module PROPERTIES OUTPUT_NAME isolation2_regress)

foreach(_program IN ITEMS
    extended_protocol_test
    test_parallel_retrieve_cursor_extended_query
    test_parallel_retrieve_cursor_extended_query_error)
  gpdb_add_source_test_executable(${_program}
    "${CMAKE_SOURCE_DIR}/src/test/isolation2/${_program}.c")
  target_link_libraries(${_program} PRIVATE libpq)
endforeach()

# Source-test loadable helpers.
gpdb_add_source_test_module(fsync_helper src/test/fsync/fsync_helper.c)
gpdb_add_source_test_module(gplibpq src/test/walrep/gplibpq.c)
gpdb_add_source_test_module(heap_checksum_helper
  src/test/heap_checksum/heap_checksum_helper.c)

# PL/Python is part of the native server installation, not just a configure
# option.  Isolation and checksum tests create plpython3u functions at
# runtime, so build the extension with the same CMake toolchain as the
# backend.
if(GPDB_WITH_PYTHON)
  set(_gpdb_plpython_generated_dir "${CMAKE_BINARY_DIR}/plpython")
  file(MAKE_DIRECTORY "${_gpdb_plpython_generated_dir}")
  set(_gpdb_plpython_spiexceptions
      "${_gpdb_plpython_generated_dir}/spiexceptions.h")
  execute_process(
    COMMAND "${PERL_EXECUTABLE}"
            "${CMAKE_SOURCE_DIR}/src/pl/plpython/generate-spiexceptions.pl"
            "${CMAKE_SOURCE_DIR}/src/backend/utils/errcodes.txt"
    OUTPUT_FILE "${_gpdb_plpython_spiexceptions}"
    RESULT_VARIABLE _gpdb_plpython_spiexceptions_status)
  if(NOT _gpdb_plpython_spiexceptions_status EQUAL 0)
    message(FATAL_ERROR "Could not generate PL/Python SPI exceptions header")
  endif()

  file(GLOB _gpdb_plpython_sources CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/src/pl/plpython/*.c")
  add_library(plpython3 MODULE ${_gpdb_plpython_sources})
  gpdb_apply_common_options(plpython3)
  add_dependencies(plpython3 gpdb-generated)
  target_compile_options(plpython3 PRIVATE -Wno-error)
  target_include_directories(plpython3 PRIVATE
    ${_gpdb_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/pl/plpython"
    "${_gpdb_plpython_generated_dir}"
    "${GPDB_GENERATED_BACKEND_DIR}"
    ${Python3_INCLUDE_DIRS})
  target_link_libraries(plpython3 PRIVATE Python3::Python)
  set_target_properties(plpython3 PROPERTIES PREFIX "" OUTPUT_NAME plpython3)
  gpdb_apply_module_link_options(plpython3)
endif()

# Logical decoding TAP tests load this output plugin by name.  It must be
# installed into the production-style pkglibdir just like the legacy build.
gpdb_add_source_test_module(test_decoding
  "${CMAKE_SOURCE_DIR}/contrib/test_decoding/test_decoding.c")

gpdb_add_source_test_executable(extended_protocol_commit_test
  src/test/fdw/extended_protocol_commit_test.c)
target_link_libraries(extended_protocol_commit_test PRIVATE libpq)
gpdb_add_source_test_module(extended_protocol_commit_test_fdw
  src/test/fdw/extension/extended_protocol_commit_test_fdw.c)

# The examples are part of the source-test build contract.  They are not all
# run by the installcheck suites, but compiling every one catches ABI drift in
# libpq and the client headers.
foreach(_program IN ITEMS
    test_parallel_retrieve_cursor_wait
    test_parallel_retrieve_cursor_nowait
    testlibpq testlibpq2 testlibpq3 testlibpq4 testlo testlo64)
  gpdb_add_source_test_executable(${_program}
    "${CMAKE_SOURCE_DIR}/src/test/examples/${_program}.c")
  target_link_libraries(${_program} PRIVATE libpq)
endforeach()

add_executable(test-ctype src/test/locale/test-ctype.c)
gpdb_apply_common_options(test-ctype)

# Native CMake builds for the C extensions used by src/test/modules.  The
# SQL/control files remain source data and are installed below with the full
# source-test tree.
set(_gpdb_source_module_targets)
function(gpdb_add_source_module_target _module_name)
  gpdb_add_source_test_module("source_module_${_module_name}" ${ARGN})
  set_target_properties("source_module_${_module_name}" PROPERTIES
    OUTPUT_NAME "${_module_name}")
  set(_gpdb_source_module_targets "${_gpdb_source_module_targets};source_module_${_module_name}"
    PARENT_SCOPE)
endfunction()
gpdb_add_source_module_target(dummy_seclabel
  src/test/modules/dummy_seclabel/dummy_seclabel.c)
gpdb_add_source_module_target(test_bloomfilter
  src/test/modules/test_bloomfilter/test_bloomfilter.c)
gpdb_add_source_module_target(test_ddl_deparse
  src/test/modules/test_ddl_deparse/test_ddl_deparse.c)
gpdb_add_source_module_target(test_integerset
  src/test/modules/test_integerset/test_integerset.c)
gpdb_add_source_module_target(test_parser
  src/test/modules/test_parser/test_parser.c)
gpdb_add_source_module_target(test_planner
  src/test/modules/test_planner/test_planner.c
  src/test/modules/test_planner/src/assertions.c
  src/test/modules/test_planner/src/planner_test_helpers.c
  src/test/modules/test_planner/integration_tests/planner_integration_tests.c)
target_include_directories(source_module_test_planner PRIVATE
  "${CMAKE_SOURCE_DIR}/src/test/modules/test_planner")
# The legacy make build emits source paths relative to the module directory in
# __FILE__.  CMake/Ninja emits paths relative to the build directory instead;
# normalize both forms so planner expected output stays build-system neutral.
target_compile_options(source_module_test_planner PRIVATE
  "-fmacro-prefix-map=${CMAKE_SOURCE_DIR}/src/test/modules/test_planner/="
  "-fmacro-prefix-map=../src/test/modules/test_planner/=")
gpdb_add_source_module_target(test_predtest
  src/test/modules/test_predtest/test_predtest.c)
gpdb_add_source_module_target(test_rbtree
  src/test/modules/test_rbtree/test_rbtree.c)
gpdb_add_source_module_target(test_rls_hooks
  src/test/modules/test_rls_hooks/test_rls_hooks.c)
gpdb_add_source_module_target(test_shm_mq
  src/test/modules/test_shm_mq/test.c
  src/test/modules/test_shm_mq/setup.c
  src/test/modules/test_shm_mq/worker.c)
gpdb_add_source_module_target(worker_spi
  src/test/modules/worker_spi/worker_spi.c)

set(_gpdb_source_test_targets
  isolationtester pg_isolation_regress pg_isolation2_regress
  isolation2_regress_module
  extended_protocol_test
  test_parallel_retrieve_cursor_extended_query
  test_parallel_retrieve_cursor_extended_query_error
  fsync_helper gplibpq heap_checksum_helper
  extended_protocol_commit_test extended_protocol_commit_test_fdw test_decoding
  test-ctype
  test_parallel_retrieve_cursor_wait test_parallel_retrieve_cursor_nowait
  testlibpq testlibpq2 testlibpq3 testlibpq4 testlo testlo64
  ${_gpdb_source_module_targets})

if(TARGET plpython3)
  list(APPEND _gpdb_source_test_targets plpython3)
endif()

add_custom_target(gpdb-source-test-tools DEPENDS ${_gpdb_source_test_targets}
  gpdb-regression-tools gpextprotocol citext)

install(TARGETS
  isolationtester pg_isolation_regress pg_isolation2_regress
  extended_protocol_test
  test_parallel_retrieve_cursor_extended_query
  test_parallel_retrieve_cursor_extended_query_error
  extended_protocol_commit_test
  test-ctype
  test_parallel_retrieve_cursor_wait test_parallel_retrieve_cursor_nowait
  testlibpq testlibpq2 testlibpq3 testlibpq4 testlo testlo64
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(TARGETS isolation2_regress_module fsync_helper gplibpq
  heap_checksum_helper extended_protocol_commit_test_fdw
  ${_gpdb_source_module_targets}
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
if(TARGET plpython3)
  install(TARGETS plpython3
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
endif()
install(TARGETS test_decoding
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")

# gpconfig reads this metadata at runtime.  The legacy install invokes the
# parser as part of gpMgmt/bin installation; generate the same file for the
# native install artifact.
if(NOT Python3_EXECUTABLE)
  find_package(Python3 REQUIRED COMPONENTS Interpreter)
endif()
set(_gpdb_guc_metadata_file
  "${GPDB_GENERATED_DIR}/share/greenplum/gucs_disallowed_in_file.txt")
add_custom_command(
  OUTPUT "${_gpdb_guc_metadata_file}"
  COMMAND ${CMAKE_COMMAND} -E make_directory
          "${GPDB_GENERATED_DIR}/share/greenplum"
  COMMAND "${Python3_EXECUTABLE}"
          "${CMAKE_SOURCE_DIR}/gpMgmt/bin/gpconfig_modules/parse_guc_metadata.py"
          "${GPDB_GENERATED_DIR}"
  DEPENDS "${CMAKE_SOURCE_DIR}/gpMgmt/bin/gpconfig_modules/parse_guc_metadata.py"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/misc/guc.c"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/misc/guc_gp.c"
  VERBATIM)
add_custom_target(gpdb-guc-metadata DEPENDS "${_gpdb_guc_metadata_file}")
add_dependencies(gpdb-source-test-tools gpdb-guc-metadata)
install(FILES "${_gpdb_guc_metadata_file}"
  DESTINATION "${CMAKE_INSTALL_DATAROOTDIR}/greenplum")

if(TARGET plpython3)
  install(FILES
    src/pl/plpython/plpython3u.control
    src/pl/plpython/plpython3u--1.0.sql
    src/pl/plpython/plpython3u--unpackaged--1.0.sql
    DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
endif()

install(FILES
  src/test/fdw/extension/extended_protocol_commit_test_fdw.control
  src/test/fdw/extension/extended_protocol_commit_test_fdw--1.0.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/extension")

foreach(_module_dir IN ITEMS
    brin commit_ts dummy_seclabel snapshot_too_old test_bloomfilter
    test_ddl_deparse test_extensions test_integerset test_misc test_parser
    test_pg_dump test_planner test_predtest test_rbtree test_rls_hooks
    test_shm_mq unsafe_tests worker_spi)
  install(DIRECTORY "${CMAKE_SOURCE_DIR}/src/test/modules/${_module_dir}/"
    DESTINATION "${GPDB_INSTALL_DATADIR}/source-tests/modules/${_module_dir}")
  file(GLOB _module_extension_files CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/src/test/modules/${_module_dir}/*.control"
    "${CMAKE_SOURCE_DIR}/src/test/modules/${_module_dir}/*.sql")
  if(_module_extension_files)
    install(FILES ${_module_extension_files}
      DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
  endif()
endforeach()

# Keep all test inputs, TAP helpers, schedules, certificates and scripts in
# the same native install artifact.  This removes the old prepare-source-tests
# symlink tree and makes every test job consume one self-contained artifact.
foreach(_suite IN ITEMS
    regress isolation isolation2 fsync walrep heap_checksum fdw examples locale
    authentication recovery kerberos ldap ssl modules perl)
  install(DIRECTORY "${CMAKE_SOURCE_DIR}/src/test/${_suite}/"
    DESTINATION "${GPDB_INSTALL_DATADIR}/source-tests/${_suite}"
    USE_SOURCE_PERMISSIONS
    PATTERN "tmp_check" EXCLUDE
    PATTERN "output_iso" EXCLUDE
    PATTERN "results" EXCLUDE)
endforeach()

# fdw/extended_protocol_commit_test invokes the client executable with a
# relative path from the regression output directory.  Keep a copy in the
# installed suite in addition to the normal bin/ location.
install(PROGRAMS "$<TARGET_FILE:extended_protocol_commit_test>"
  DESTINATION "${GPDB_INSTALL_DATADIR}/source-tests/fdw")
