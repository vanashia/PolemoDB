cmake_minimum_required(VERSION 3.20)

if(NOT DEFINED GPDB_SOURCE_DIR)
  message(FATAL_ERROR "GPDB_SOURCE_DIR is required")
endif()

file(READ "${GPDB_SOURCE_DIR}/CMakeLists.txt" _cmake)
file(READ "${GPDB_SOURCE_DIR}/cmake/GPDBGenerate.cmake" _generate_cmake)
file(READ "${GPDB_SOURCE_DIR}/cmake/GPDBBackend.cmake" _backend_cmake)
file(READ "${GPDB_SOURCE_DIR}/cmake/GPDBClients.cmake" _clients_cmake)
file(READ "${GPDB_SOURCE_DIR}/cmake/GPDBGpfdist.cmake" _gpfdist_cmake)
set(_native_sources "${_cmake}\n${_generate_cmake}\n${_backend_cmake}\n${_clients_cmake}\n${_gpfdist_cmake}")

foreach(_forbidden IN ITEMS
    "execute_process(" "GPDB_LEGACY_BUILD_DIR"
    "GPDB_SKIP_CONFIGURE" "GPDBInstall.cmake.in" "GPDB_MAKE_PROGRAM"
    "-C \\${GPDB_LEGACY_BUILD_DIR}")
  string(FIND "${_cmake}" "${_forbidden}" _forbidden_pos)
  if(NOT _forbidden_pos EQUAL -1)
    message(FATAL_ERROR "native CMake must not contain legacy build entry ${_forbidden}")
  endif()
endforeach()

foreach(_required IN ITEMS
    "include(GPDBGenerate)" "include(CTest)" "install(TARGETS"
    "gpdb-generated" "gpdb-server" "gpdb-clients" "gpfdist")
  string(FIND "${_native_sources}" "${_required}" _required_pos)
  if(_required_pos EQUAL -1)
    message(FATAL_ERROR "native CMake is missing required entry ${_required}")
  endif()
endforeach()

foreach(_required_file IN ITEMS
    "${GPDB_SOURCE_DIR}/cmake/GPDBGenerate.cmake"
    "${GPDB_SOURCE_DIR}/cmake/GPDBBackend.cmake"
    "${GPDB_SOURCE_DIR}/cmake/GPDBClients.cmake"
    "${GPDB_SOURCE_DIR}/cmake/GPDBGpfdist.cmake")
  if(NOT EXISTS "${_required_file}")
    message(FATAL_ERROR "missing native CMake module ${_required_file}")
  endif()
endforeach()

file(READ "${GPDB_SOURCE_DIR}/cmake/GPDBNativeLibraries.cmake" _native_cmake)
string(FIND "${_native_cmake}" "add_custom_command" _generation_pos)
if(NOT _generation_pos EQUAL -1)
  message(FATAL_ERROR "old native module must not own generated-file rules")
endif()
