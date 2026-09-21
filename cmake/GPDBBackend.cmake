set(_gpdb_backend_sources)
file(GLOB_RECURSE _gpdb_backend_sources CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/backend/*.c")
list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/test/")
list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/gporca/")
list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/gpopt/")
if(NOT GPDB_WITH_LLVM)
  list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/jit/llvm/")
endif()
if(NOT GPDB_WITH_GSSAPI)
  list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/(be-gssapi-common|be-secure-gssapi)\\.c$")
endif()
if(NOT GPDB_ENABLE_ORCA)
  list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/orca\\.c$")
endif()
if(NOT GPDB_ENABLE_IC_PROXY)
  list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/ic_proxy_[^/]+\\.c$")
endif()
list(FILTER _gpdb_backend_sources EXCLUDE REGEX
  "/(explain_gp|nodeGroup|orindxpath|regc_lex|regc_color|regc_nfa|regc_cvec|regc_pg_locale|regc_locale|rege_dfa|like_match|levenshtein)\\.c$")
list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/snowball/")
list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/utils/mb/conversion_procs/")
list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/utils/mb/(iso|win1251|win866)\\.c$")
list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/replication/pgoutput/pgoutput\\.c$")
if(NOT WIN32)
  list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/port/win32(_|/)")
endif()
if(NOT WIN32)
  list(FILTER _gpdb_backend_sources EXCLUDE REGEX "/port/posix_sema\\.c$")
endif()
if(NOT CMAKE_SYSTEM_NAME STREQUAL "Linux")
  list(FILTER _gpdb_backend_sources EXCLUDE REGEX
    "/utils/resgroup/(cgroup|cgroup-ops-linux[^/]*|cgroup_io_limit)\\.c$")
endif()

list(APPEND _gpdb_backend_sources
  "${GPDB_GENERATED_FMGR_OUTPUTS}"
  "${GPDB_GENERATED_LWLOCK_C}"
  "${CMAKE_SOURCE_DIR}/src/timezone/localtime.c"
  "${CMAKE_SOURCE_DIR}/src/timezone/strftime.c"
  "${CMAKE_SOURCE_DIR}/src/timezone/pgtz.c"
  "${GPDB_BISON_parser_C}" "${GPDB_FLEX_parser_C}"
  "${GPDB_BISON_bootstrap_C}"
  "${GPDB_BISON_replication_C}"
  "${GPDB_BISON_syncrep_C}"
  "${GPDB_BISON_statistics_C}" "${GPDB_FLEX_statistics_C}"
  "${GPDB_BISON_jsonpath_C}")
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  list(APPEND _gpdb_backend_sources
    "${GPDB_BISON_io_limit_C}" "${GPDB_FLEX_io_limit_C}")
endif()

# Greenplum builds the client protocol implementation a second time as part
# of the backend libpq subsystem. It must not use FRONTEND: the coordinator
# and segments intentionally use backend memory/error routines, and the
# frontend libpq archive would trip the link-canary check at runtime.
set(_gpdb_backend_libpq_sources
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-protocol3.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-connect.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-exec.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/pqexpbuffer.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-auth.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-misc.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-protocol2.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure.c"
  "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-auth-scram.c")
if(GPDB_WITH_OPENSSL)
  list(APPEND _gpdb_backend_libpq_sources
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-common.c"
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-openssl.c")
endif()
if(GPDB_WITH_GSSAPI)
  list(APPEND _gpdb_backend_libpq_sources
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-gssapi-common.c"
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-gssapi.c")
endif()
list(APPEND _gpdb_backend_sources ${_gpdb_backend_libpq_sources})

add_library(gpdb-backend-objects OBJECT ${_gpdb_backend_sources})
gpdb_apply_common_options(gpdb-backend-objects)
if(GPDB_ENABLE_ORCA)
  target_compile_features(gpdb-backend-objects PRIVATE cxx_std_14)
  set_property(TARGET gpdb-backend-objects PROPERTY CXX_STANDARD 14)
  set_property(TARGET gpdb-backend-objects PROPERTY CXX_STANDARD_REQUIRED ON)
endif()
target_compile_definitions(gpdb-backend-objects PRIVATE DLSUFFIX=\".so\")
add_dependencies(gpdb-backend-objects gpdb-generated)
target_include_directories(gpdb-backend-objects PRIVATE
  ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend"
  "${CMAKE_SOURCE_DIR}/src/include/snowball"
  "${CMAKE_SOURCE_DIR}/src/include/snowball/libstemmer"
  "${CMAKE_SOURCE_DIR}/src/timezone"
  "${GPDB_GENERATED_BACKEND_DIR}"
  "${GPDB_GENERATED_BACKEND_DIR}/parser"
  "${GPDB_GENERATED_BACKEND_DIR}/bootstrap"
  "${GPDB_GENERATED_BACKEND_DIR}/replication"
  "${GPDB_GENERATED_BACKEND_DIR}/syncrep"
  "${GPDB_GENERATED_BACKEND_DIR}/statistics"
  "${GPDB_GENERATED_BACKEND_DIR}/jsonpath"
  "${GPDB_GENERATED_BACKEND_DIR}/guc_file"
  "${GPDB_GENERATED_BACKEND_DIR}/io_limit"
  "${GPDB_GENERATED_BACKEND_DIR}/sort")
target_link_libraries(gpdb-backend-objects PRIVATE gpdb-platform)

if(GPDB_ENABLE_ORCA)
  add_subdirectory("${CMAKE_SOURCE_DIR}/src/backend/gporca"
                   "${CMAKE_BINARY_DIR}/gporca" EXCLUDE_FROM_ALL)
  file(GLOB_RECURSE _gpdb_gpopt_sources CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/src/backend/gpopt/*.cpp")
  target_sources(gpdb-backend-objects PRIVATE ${_gpdb_gpopt_sources})
  target_include_directories(gpdb-backend-objects PRIVATE
    "${CMAKE_SOURCE_DIR}/src/backend/gpopt"
    "${CMAKE_SOURCE_DIR}/src/backend/gporca/libgpos/include"
    "${CMAKE_SOURCE_DIR}/src/backend/gporca/libnaucrates/include"
    "${CMAKE_SOURCE_DIR}/src/backend/gporca/libgpdbcost/include"
    "${CMAKE_SOURCE_DIR}/src/backend/gporca/libgpopt/include")
endif()

add_executable(postgres $<TARGET_OBJECTS:gpdb-backend-objects>)
gpdb_apply_common_options(postgres)
add_dependencies(postgres gpdb-generated)
target_include_directories(postgres PRIVATE ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend" "${GPDB_GENERATED_BACKEND_DIR}")
target_link_libraries(postgres PRIVATE gpdb-backend-objects pgcommon_srv pgport_srv gpdb-platform)
if(GPDB_ENABLE_ORCA)
  target_link_libraries(postgres PRIVATE gpopt gpdbcost naucrates gpos)
endif()
set_target_properties(postgres PROPERTIES ENABLE_EXPORTS ON)

add_custom_target(gpdb-server DEPENDS postgres)
