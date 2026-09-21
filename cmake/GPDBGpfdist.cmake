if(GPDB_ENABLE_GPFDIST)
  set(_gpfdist_sources
    "${CMAKE_SOURCE_DIR}/src/bin/gpfdist/gpfdist.c"
    "${CMAKE_SOURCE_DIR}/src/bin/gpfdist/gpfdist_helper.c"
    "${CMAKE_SOURCE_DIR}/src/bin/gpfdist/transform.c"
    "${CMAKE_SOURCE_DIR}/src/backend/utils/misc/fstream/fstream.c"
    "${CMAKE_SOURCE_DIR}/src/backend/utils/misc/fstream/gfile.c")
  add_executable(gpfdist ${_gpfdist_sources})
  gpdb_apply_common_options(gpfdist)
  add_dependencies(gpfdist gpdb-generated)
  target_compile_definitions(gpfdist PRIVATE GPFXDIST)
  set_source_files_properties(
    "${CMAKE_SOURCE_DIR}/src/backend/utils/misc/fstream/gfile.c"
    PROPERTIES COMPILE_DEFINITIONS FRONTEND)
  target_include_directories(gpfdist PRIVATE
    "${CMAKE_SOURCE_DIR}/src/bin/gpfdist"
    "${CMAKE_SOURCE_DIR}/src/backend/utils/misc/fstream"
    ${GPDB_APR_INCLUDE_DIR} ${GPDB_LIBEVENT_INCLUDE_DIR} ${GPDB_YAML_INCLUDE_DIR}
    ${_gpdb_include_dirs})
  target_link_libraries(gpfdist PRIVATE pgcommon pgport gpdb-platform
    "${GPDB_APR_LIBRARY}" "${GPDB_LIBEVENT_LIBRARY}")
  if(GPDB_YAML_LIBRARY)
    target_link_libraries(gpfdist PRIVATE "${GPDB_YAML_LIBRARY}")
  endif()
endif()
