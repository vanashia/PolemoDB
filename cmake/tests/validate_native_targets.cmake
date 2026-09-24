cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED GPDB_BINARY_DIR)
  message(FATAL_ERROR "GPDB_BINARY_DIR is required")
endif()

file(READ "${GPDB_BINARY_DIR}/build.ninja" _build_ninja)

set(_gpdb_expected_targets
    gpdb-generated gpdb-server gpdb-clients gpdb postgres pg_ctl psql
    libpq_shared pg_regress regress autoinc refint test_hook
    query_info_hook_test gp_toolkit gp_ao_co_diagnostics gp_workfile_mgr
    gp_session_state_memory_stats gp_instrument_shmem pageinspect gp_inject_fault
    gp_debug_numsegments file_fdw gpformatter pg_hint_plan isolation2_regress_module
    gpdb-regression-tools gpdb-regression)
file(STRINGS "${GPDB_BINARY_DIR}/CMakeCache.txt" _gpdb_gpfdist_enabled
     REGEX "^GPDB_ENABLE_GPFDIST:BOOL=ON$")
if(_gpdb_gpfdist_enabled)
  list(APPEND _gpdb_expected_targets gpfdist)
endif()

foreach(_target IN LISTS _gpdb_expected_targets)
  string(FIND "${_build_ninja}" "build ${_target}:" _target_pos)
  if(_target_pos EQUAL -1 AND NOT EXISTS "${GPDB_BINARY_DIR}/CMakeFiles/${_target}.dir")
    message(FATAL_ERROR "native target was not generated: ${_target}")
  endif()
endforeach()

if(EXISTS "${GPDB_BINARY_DIR}/GPDBInstall.cmake")
  message(FATAL_ERROR "legacy GPDBInstall.cmake wrapper still exists")
endif()
