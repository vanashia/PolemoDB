cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED GPDB_BINARY_DIR)
  message(FATAL_ERROR "GPDB_BINARY_DIR is required")
endif()

file(READ "${GPDB_BINARY_DIR}/build.ninja" _build_ninja)

foreach(_target IN ITEMS
    gpdb-generated gpdb-server gpdb-clients gpdb postgres pg_ctl psql gpfdist
    libpq_shared)
  string(FIND "${_build_ninja}" "build ${_target}:" _target_pos)
  if(_target_pos EQUAL -1 AND NOT EXISTS "${GPDB_BINARY_DIR}/CMakeFiles/${_target}.dir")
    message(FATAL_ERROR "native target was not generated: ${_target}")
  endif()
endforeach()

if(EXISTS "${GPDB_BINARY_DIR}/GPDBInstall.cmake")
  message(FATAL_ERROR "legacy GPDBInstall.cmake wrapper still exists")
endif()
