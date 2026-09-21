set(_gpdb_include_dirs
  ${GPDB_GENERATED_INCLUDE_DIRS}
  "${CMAKE_SOURCE_DIR}/src/include"
  "${CMAKE_SOURCE_DIR}/src/include/port"
  "${CMAKE_SOURCE_DIR}/src"
  "${CMAKE_SOURCE_DIR}/src/common"
  "${CMAKE_SOURCE_DIR}/src/port"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")

set(_gpdb_port_names
  chklocale erand48 inet_net_ntop noblock path pg_bitutils pgcheckdir pgmkdirp
  pgsleep pg_strong_random pgstrcasecmp pgstrsignal pqsignal qsort qsort_arg
  quotes snprintf sprompt strerror tar thread)
set(_gpdb_port_sources)
foreach(_name IN LISTS _gpdb_port_names)
  list(APPEND _gpdb_port_sources "${CMAKE_SOURCE_DIR}/src/port/${_name}.c")
endforeach()
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
  list(APPEND _gpdb_port_sources "${CMAKE_SOURCE_DIR}/src/port/pg_crc32c_armv8.c")
  set(_gpdb_crc32c_definition USE_ARMV8_CRC32C)
else()
  list(APPEND _gpdb_port_sources "${CMAKE_SOURCE_DIR}/src/port/pg_crc32c_sb8.c")
endif()
if(_gpdb_crc32c_definition)
  target_compile_definitions(gpdb-platform INTERFACE ${_gpdb_crc32c_definition})
endif()

function(_gpdb_configure_library _target _frontend _pic)
  gpdb_apply_common_options(${_target})
  add_dependencies(${_target} gpdb-generated)
  target_include_directories(${_target} PRIVATE ${_gpdb_include_dirs})
  target_link_libraries(${_target} PUBLIC gpdb-platform)
  if(_frontend)
    target_compile_definitions(${_target} PRIVATE FRONTEND)
  endif()
  if(_gpdb_crc32c_definition)
    target_compile_definitions(${_target} PRIVATE ${_gpdb_crc32c_definition})
  endif()
  if(_pic)
    set_target_properties(${_target} PROPERTIES POSITION_INDEPENDENT_CODE ON)
  endif()
endfunction()

add_library(pgport STATIC ${_gpdb_port_sources})
_gpdb_configure_library(pgport TRUE FALSE)
add_library(pgport_shlib STATIC ${_gpdb_port_sources})
_gpdb_configure_library(pgport_shlib TRUE TRUE)
add_library(pgport_srv STATIC ${_gpdb_port_sources})
_gpdb_configure_library(pgport_srv FALSE FALSE)

set(_gpdb_common_names
  base64 config_info controldata_utils d2s exec f2s file_perm hashfn ip keywords
  kwlookup link-canary md5 pg_get_line pg_lzcompress pgfnames psprintf relpath
  rmtree saslprep scram-common string stringinfo unicode_norm username wait_error)
set(_gpdb_common_sources)
foreach(_name IN LISTS _gpdb_common_names)
  list(APPEND _gpdb_common_sources "${CMAKE_SOURCE_DIR}/src/common/${_name}.c")
endforeach()
if(GPDB_WITH_OPENSSL)
  list(APPEND _gpdb_common_sources "${CMAKE_SOURCE_DIR}/src/common/sha2_openssl.c")
else()
  list(APPEND _gpdb_common_sources "${CMAKE_SOURCE_DIR}/src/common/sha2.c")
endif()
set(_gpdb_frontend_common_sources ${_gpdb_common_sources}
  "${CMAKE_SOURCE_DIR}/src/common/fe_memutils.c"
  "${CMAKE_SOURCE_DIR}/src/common/file_utils.c"
  "${CMAKE_SOURCE_DIR}/src/common/logging.c"
  "${CMAKE_SOURCE_DIR}/src/common/restricted_token.c")

add_library(pgcommon STATIC ${_gpdb_frontend_common_sources})
_gpdb_configure_library(pgcommon TRUE FALSE)
target_sources(pgcommon PRIVATE "${GPDB_GENERATED_KWLIST}")
add_library(pgcommon_shlib STATIC ${_gpdb_frontend_common_sources})
_gpdb_configure_library(pgcommon_shlib TRUE TRUE)
target_sources(pgcommon_shlib PRIVATE "${GPDB_GENERATED_KWLIST}")
add_library(pgcommon_srv STATIC ${_gpdb_common_sources})
_gpdb_configure_library(pgcommon_srv FALSE FALSE)
target_sources(pgcommon_srv PRIVATE "${GPDB_GENERATED_KWLIST}")
target_link_libraries(pgcommon PUBLIC pgport)
target_link_libraries(pgcommon_shlib PUBLIC pgport_shlib)
target_link_libraries(pgcommon_srv PUBLIC pgport_srv)

set(_gpdb_feutils_sources
  "${CMAKE_SOURCE_DIR}/src/fe_utils/conditional.c"
  "${CMAKE_SOURCE_DIR}/src/fe_utils/mbprint.c"
  "${CMAKE_SOURCE_DIR}/src/fe_utils/print.c"
  "${CMAKE_SOURCE_DIR}/src/fe_utils/recovery_gen.c"
  "${CMAKE_SOURCE_DIR}/src/fe_utils/simple_list.c"
  "${CMAKE_SOURCE_DIR}/src/fe_utils/string_utils.c"
  "${GPDB_FLEX_fe_utils_C}")
add_library(pgfeutils STATIC ${_gpdb_feutils_sources})
_gpdb_configure_library(pgfeutils TRUE FALSE)
target_link_libraries(pgfeutils PUBLIC pgcommon pgport)

set(_gpdb_libpq_sources)
foreach(_name IN ITEMS fe-auth fe-auth-scram fe-connect fe-exec fe-misc fe-print
    fe-lobj fe-protocol2 fe-protocol3 pqexpbuffer fe-secure legacy-pqsignal
    libpq-events)
  list(APPEND _gpdb_libpq_sources "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/${_name}.c")
endforeach()
list(APPEND _gpdb_libpq_sources
  "${CMAKE_SOURCE_DIR}/src/backend/utils/mb/encnames.c"
  "${CMAKE_SOURCE_DIR}/src/backend/utils/mb/wchar.c")
if(GPDB_WITH_OPENSSL)
  list(APPEND _gpdb_libpq_sources
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-common.c"
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-openssl.c")
endif()
if(GPDB_WITH_GSSAPI)
  list(APPEND _gpdb_libpq_sources
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-gssapi-common.c"
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-gssapi.c")
endif()
add_library(libpq STATIC ${_gpdb_libpq_sources})
_gpdb_configure_library(libpq TRUE FALSE)
target_compile_definitions(libpq PRIVATE UNSAFE_STAT_OK)
target_link_libraries(libpq PUBLIC pgcommon pgport)
add_library(libpq_shared SHARED ${_gpdb_libpq_sources})
_gpdb_configure_library(libpq_shared TRUE TRUE)
target_compile_definitions(libpq_shared PRIVATE UNSAFE_STAT_OK)
target_link_libraries(libpq_shared PUBLIC pgcommon_shlib pgport_shlib)
add_dependencies(libpq_shared gpdb-libpq-exports)
set_target_properties(libpq_shared PROPERTIES OUTPUT_NAME pq SOVERSION 5 VERSION 5.12)
if(APPLE)
  target_link_options(libpq_shared PRIVATE
    "-Wl,-exported_symbols_list,${GPDB_LIBPQ_EXPORTS}")
elseif(UNIX)
  target_link_options(libpq_shared PRIVATE
    "-Wl,--version-script=${GPDB_LIBPQ_VERSION_MAP}")
endif()

add_library(gpdb::pgport ALIAS pgport)
add_library(gpdb::pgport_shlib ALIAS pgport_shlib)
add_library(gpdb::pgport_srv ALIAS pgport_srv)
add_library(gpdb::pgcommon ALIAS pgcommon)
add_library(gpdb::pgcommon_shlib ALIAS pgcommon_shlib)
add_library(gpdb::pgcommon_srv ALIAS pgcommon_srv)
add_library(gpdb::pgfeutils ALIAS pgfeutils)
add_library(gpdb::libpq ALIAS libpq)
add_library(gpdb::libpq_shared ALIAS libpq_shared)
