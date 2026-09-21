# Native CMake targets for the source regression drivers and their loadable
# test modules.  These targets deliberately do not include or invoke any of
# the legacy GNUmakefiles; the installed server and client targets are the
# only runtime prerequisites.

set(GPDB_TEST_BUILD_DIR "${CMAKE_BINARY_DIR}/src/test")
set(GPDB_REGRESS_BUILD_DIR "${GPDB_TEST_BUILD_DIR}/regress")
set(GPDB_TEST_VERSION "${GPDB_VERSION_LONG}")
set(GPDB_REGRESS_GPTEST "${GPDB_REGRESS_BUILD_DIR}/GPTest.pm")
set(_gpdb_regression_extension_options)
if(GPDB_ENABLE_DEBUG_EXTENSIONS)
  list(APPEND _gpdb_regression_extension_options
    --load-extension=gp_inject_fault)
endif()
configure_file("${CMAKE_SOURCE_DIR}/src/test/regress/GPTest.pm.in"
               "${GPDB_REGRESS_GPTEST}" @ONLY)

function(gpdb_add_test_module _target)
  add_library(${_target} MODULE ${ARGN})
  gpdb_apply_common_options(${_target})
  add_dependencies(${_target} gpdb-generated)
  target_include_directories(${_target} PRIVATE
    ${_gpdb_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/backend"
    "${CMAKE_SOURCE_DIR}/src/include/snowball"
    "${GPDB_GENERATED_BACKEND_DIR}")
  set_target_properties(${_target} PROPERTIES
    PREFIX ""
    SUFFIX ".so"
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/test-modules")
  gpdb_apply_module_link_options(${_target})
endfunction()

gpdb_add_test_module(regress
  src/test/regress/regress.c
  src/test/regress/regress_gp.c)
target_link_libraries(regress PRIVATE libpq gpdb-platform)

gpdb_add_test_module(autoinc contrib/spi/autoinc.c)
gpdb_add_test_module(refint contrib/spi/refint.c)
target_compile_definitions(refint PRIVATE REFINT_VERBOSE)

gpdb_add_test_module(test_hook src/test/regress/hooktest/hook_test.c)
gpdb_add_test_module(query_info_hook_test
  src/test/regress/query_info_hook_test/query_info_hook_test.c)

add_executable(pg_regress
  src/test/regress/pg_regress.c
  src/test/regress/pg_regress_main.c)
gpdb_apply_common_options(pg_regress)
add_dependencies(pg_regress gpdb-generated)
target_compile_definitions(pg_regress PRIVATE
  FRONTEND
  HOST_TUPLE="${CMAKE_SYSTEM_PROCESSOR}-${CMAKE_SYSTEM_NAME}"
  SHELLPROG="/bin/sh"
  DLSUFFIX=".so")
target_include_directories(pg_regress PRIVATE
  ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend"
  "${CMAKE_SOURCE_DIR}/src/port"
  "${GPDB_GENERATED_DIR}/src/port")
target_link_libraries(pg_regress PRIVATE pgcommon pgport gpdb-platform)

foreach(_program IN ITEMS extended_protocol_resqueue twophase_pqexecparams)
  add_executable(${_program} "${CMAKE_SOURCE_DIR}/src/test/regress/${_program}.c")
  gpdb_apply_common_options(${_program})
  add_dependencies(${_program} gpdb-generated)
  target_compile_definitions(${_program} PRIVATE FRONTEND)
  target_include_directories(${_program} PRIVATE ${_gpdb_include_dirs})
  target_link_libraries(${_program} PRIVATE libpq gpdb-platform)
endforeach()

set(_gpdb_regress_helper_files
  gpdiff.pl gpstringsubs.pl atmsort.pl atmsort.pm explain.pl explain.pm
  GPTest.pm scan_flaky_fault_injectors.sh)
set(_gpdb_regress_helper_sources)
foreach(_helper IN LISTS _gpdb_regress_helper_files)
  if(NOT _helper STREQUAL "GPTest.pm")
    list(APPEND _gpdb_regress_helper_sources
         "${CMAKE_SOURCE_DIR}/src/test/regress/${_helper}")
  endif()
endforeach()
set(_gpdb_regress_helper_outputs)
foreach(_helper IN LISTS _gpdb_regress_helper_files)
  list(APPEND _gpdb_regress_helper_outputs "${GPDB_REGRESS_BUILD_DIR}/${_helper}")
endforeach()

set(_gpdb_regress_module_outputs
  "${GPDB_REGRESS_BUILD_DIR}/regress.so"
  "${GPDB_REGRESS_BUILD_DIR}/autoinc.so"
  "${GPDB_REGRESS_BUILD_DIR}/refint.so"
  "${GPDB_REGRESS_BUILD_DIR}/hooktest/test_hook.so"
  "${GPDB_REGRESS_BUILD_DIR}/query_info_hook_test/query_info_hook_test.so")

add_custom_command(
  OUTPUT "${GPDB_REGRESS_BUILD_DIR}/.prepared"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_REGRESS_BUILD_DIR}"
  COMMAND ${CMAKE_COMMAND} -E make_directory
          "${GPDB_REGRESS_BUILD_DIR}/hooktest"
  COMMAND ${CMAKE_COMMAND} -E make_directory
          "${GPDB_REGRESS_BUILD_DIR}/query_info_hook_test"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:pg_regress>" "${GPDB_REGRESS_BUILD_DIR}/pg_regress"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:extended_protocol_resqueue>"
          "${GPDB_REGRESS_BUILD_DIR}/extended_protocol_resqueue"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:twophase_pqexecparams>"
          "${GPDB_REGRESS_BUILD_DIR}/twophase_pqexecparams"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:regress>" "${GPDB_REGRESS_BUILD_DIR}/regress.so"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:autoinc>" "${GPDB_REGRESS_BUILD_DIR}/autoinc.so"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:refint>" "${GPDB_REGRESS_BUILD_DIR}/refint.so"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:test_hook>"
          "${GPDB_REGRESS_BUILD_DIR}/hooktest/test_hook.so"
  COMMAND ${CMAKE_COMMAND} -E copy
          "$<TARGET_FILE:query_info_hook_test>"
          "${GPDB_REGRESS_BUILD_DIR}/query_info_hook_test/query_info_hook_test.so"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/test/regress/gpdiff.pl"
          "${GPDB_REGRESS_BUILD_DIR}/gpdiff.pl"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/test/regress/gpstringsubs.pl"
          "${GPDB_REGRESS_BUILD_DIR}/gpstringsubs.pl"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/test/regress/atmsort.pl"
          "${GPDB_REGRESS_BUILD_DIR}/atmsort.pl"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/test/regress/atmsort.pm"
          "${GPDB_REGRESS_BUILD_DIR}/atmsort.pm"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/test/regress/explain.pl"
          "${GPDB_REGRESS_BUILD_DIR}/explain.pl"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/test/regress/explain.pm"
          "${GPDB_REGRESS_BUILD_DIR}/explain.pm"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${GPDB_REGRESS_GPTEST}" "${GPDB_REGRESS_BUILD_DIR}/GPTest.pm"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/test/regress/scan_flaky_fault_injectors.sh"
          "${GPDB_REGRESS_BUILD_DIR}/scan_flaky_fault_injectors.sh"
  COMMAND ${CMAKE_COMMAND} -E touch "${GPDB_REGRESS_BUILD_DIR}/.prepared"
  DEPENDS pg_regress extended_protocol_resqueue twophase_pqexecparams
          regress autoinc refint test_hook query_info_hook_test
          ${_gpdb_regress_helper_sources} "${GPDB_REGRESS_GPTEST}"
  VERBATIM)

add_custom_target(gpdb-regression-tools
  DEPENDS "${GPDB_REGRESS_BUILD_DIR}/.prepared")

add_custom_target(gpdb-regression
  COMMAND ${CMAKE_COMMAND} -E env
          "PATH=${CMAKE_BINARY_DIR}:${CMAKE_INSTALL_PREFIX}/bin:$ENV{PATH}"
          "${GPDB_REGRESS_BUILD_DIR}/pg_regress"
          --inputdir="${CMAKE_SOURCE_DIR}/src/test/regress"
          --outputdir="${GPDB_REGRESS_BUILD_DIR}"
          --bindir="${CMAKE_BINARY_DIR}"
          --dlpath="${GPDB_REGRESS_BUILD_DIR}"
          --tablespace-dir="${GPDB_REGRESS_BUILD_DIR}"
          --max-concurrent-tests=20
          --init-file="${CMAKE_SOURCE_DIR}/src/test/regress/init_file"
          ${_gpdb_regression_extension_options}
          --schedule="${CMAKE_SOURCE_DIR}/src/test/regress/parallel_schedule"
          --schedule="${CMAKE_SOURCE_DIR}/src/test/regress/greenplum_schedule"
  DEPENDS gpdb-regression-tools postgres pg_ctl initdb psql)

add_custom_target(gpdb-tests
  DEPENDS gpdb-regression)
