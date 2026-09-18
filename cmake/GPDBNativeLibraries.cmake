# Native CMake targets for the reusable frontend libraries.  The server
# target still consumes the legacy-generated configuration, but these targets
# are ordinary CMake libraries and can be compiled directly by Ninja.

set(_gpdb_generated_include_dirs
    "${GPDB_LEGACY_BUILD_DIR}/src/include"
    "${GPDB_LEGACY_BUILD_DIR}/src"
    "${GPDB_LEGACY_BUILD_DIR}/src/common"
    "${GPDB_LEGACY_BUILD_DIR}/src/port"
    "${CMAKE_SOURCE_DIR}/src/include"
    "${CMAKE_SOURCE_DIR}/src/include/port"
    "${CMAKE_SOURCE_DIR}/src"
    "${CMAKE_SOURCE_DIR}/src/port")

# This header is derived from configure's Makefile variables rather than from
# a configure probe.  Native CMake compilation needs the same generated file
# before any frontend source (notably src/port/path.c) is compiled.
set(_gpdb_config_paths_header
    "${GPDB_LEGACY_BUILD_DIR}/src/port/pg_config_paths.h")
add_custom_command(
  OUTPUT "${_gpdb_config_paths_header}"
  COMMAND "${GPDB_MAKE_PROGRAM}" -C "${GPDB_LEGACY_BUILD_DIR}/src/port"
          pg_config_paths.h
  DEPENDS "${GPDB_LEGACY_BUILD_DIR}/src/Makefile.global"
          "${GPDB_LEGACY_BUILD_DIR}/src/port/Makefile"
          "${CMAKE_SOURCE_DIR}/src/port/Makefile"
  VERBATIM)
add_custom_target(gpdb-generated-paths DEPENDS "${_gpdb_config_paths_header}")

# PostgreSQL's common sources include SQLSTATE macros and generated catalog
# headers.  Build the legacy backend generated-header aggregate, which also
# creates the build-tree symlinks for fmgr/parser/storage headers, instead of
# duplicating its Perl/symlink rules in CMake.
set(_gpdb_errcodes_header
    "${GPDB_LEGACY_BUILD_DIR}/src/include/utils/errcodes.h")
set(_gpdb_tablespace_header
    "${GPDB_LEGACY_BUILD_DIR}/src/include/catalog/pg_tablespace_d.h")
add_custom_command(
  OUTPUT "${_gpdb_errcodes_header}" "${_gpdb_tablespace_header}"
  COMMAND "${GPDB_MAKE_PROGRAM}" -C "${GPDB_LEGACY_BUILD_DIR}/src/backend"
          generated-headers
  DEPENDS "${GPDB_LEGACY_BUILD_DIR}/src/backend/Makefile"
          "${GPDB_LEGACY_BUILD_DIR}/src/Makefile.global"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/errcodes.txt"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/generate-errcodes.pl"
  VERBATIM)
add_custom_target(gpdb-generated-headers
  DEPENDS "${_gpdb_errcodes_header}" "${_gpdb_tablespace_header}")
add_dependencies(gpdb-generated-paths gpdb-generated-headers)

set(_gpdb_port_names
    chklocale erand48 inet_net_ntop noblock path pg_bitutils pgcheckdir
    pgmkdirp pgsleep pg_strong_random pgstrcasecmp pgstrsignal pqsignal
    qsort qsort_arg quotes snprintf sprompt strerror tar thread)
set(_gpdb_port_sources)
foreach(_name IN LISTS _gpdb_port_names)
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/port/${_name}.c")
    list(APPEND _gpdb_port_sources "${CMAKE_SOURCE_DIR}/src/port/${_name}.c")
    endif()
endforeach()
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
  list(APPEND _gpdb_port_sources
       "${CMAKE_SOURCE_DIR}/src/port/pg_crc32c_armv8.c")
else()
  list(APPEND _gpdb_port_sources
       "${CMAKE_SOURCE_DIR}/src/port/pg_crc32c_sb8.c")
endif()
add_library(pgport STATIC ${_gpdb_port_sources})
add_dependencies(pgport gpdb-generated-paths)
target_compile_definitions(pgport PRIVATE FRONTEND)
target_include_directories(pgport PRIVATE ${_gpdb_generated_include_dirs})
target_link_libraries(pgport PUBLIC Threads::Threads)

add_library(pgport_shlib STATIC ${_gpdb_port_sources})
add_dependencies(pgport_shlib gpdb-generated-paths)
target_compile_definitions(pgport_shlib PRIVATE FRONTEND)
target_include_directories(pgport_shlib PRIVATE ${_gpdb_generated_include_dirs})
target_link_libraries(pgport_shlib PUBLIC Threads::Threads)
set_target_properties(pgport_shlib PROPERTIES POSITION_INDEPENDENT_CODE ON)

add_library(pgport_srv STATIC ${_gpdb_port_sources})
add_dependencies(pgport_srv gpdb-generated-paths)
target_include_directories(pgport_srv PRIVATE ${_gpdb_generated_include_dirs})
target_link_libraries(pgport_srv PUBLIC Threads::Threads)

set(_gpdb_common_names
    base64 config_info controldata_utils d2s exec f2s file_perm hashfn ip
    keywords kwlookup link-canary md5 pg_get_line pg_lzcompress pgfnames
    psprintf relpath rmtree saslprep scram-common string stringinfo unicode_norm
    username wait_error)
set(_gpdb_common_sources)
foreach(_name IN LISTS _gpdb_common_names)
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/common/${_name}.c")
    list(APPEND _gpdb_common_sources "${CMAKE_SOURCE_DIR}/src/common/${_name}.c")
  endif()
endforeach()
if(GPDB_WITH_OPENSSL AND EXISTS "${CMAKE_SOURCE_DIR}/src/common/sha2_openssl.c")
  list(APPEND _gpdb_common_sources "${CMAKE_SOURCE_DIR}/src/common/sha2_openssl.c")
else()
  list(APPEND _gpdb_common_sources "${CMAKE_SOURCE_DIR}/src/common/sha2.c")
endif()
set(_gpdb_frontend_common_sources ${_gpdb_common_sources})
foreach(_name IN ITEMS fe_memutils file_utils logging restricted_token)
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/common/${_name}.c")
    list(APPEND _gpdb_frontend_common_sources
         "${CMAKE_SOURCE_DIR}/src/common/${_name}.c")
  endif()
endforeach()
add_library(pgcommon STATIC ${_gpdb_frontend_common_sources})
add_dependencies(pgcommon gpdb-generated-paths)
target_compile_definitions(pgcommon PRIVATE FRONTEND)
target_include_directories(pgcommon PRIVATE ${_gpdb_generated_include_dirs})
target_link_libraries(pgcommon PUBLIC pgport Threads::Threads)
if(Perl_FOUND)
  set(_gpdb_kwlist_header "${GPDB_LEGACY_BUILD_DIR}/src/common/kwlist_d.h")
  add_custom_command(
    OUTPUT "${_gpdb_kwlist_header}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_LEGACY_BUILD_DIR}/src/common"
    COMMAND "${PERL_EXECUTABLE}" -I "${CMAKE_SOURCE_DIR}/src/tools"
            "${CMAKE_SOURCE_DIR}/src/tools/gen_keywordlist.pl" --extern
            -o "${GPDB_LEGACY_BUILD_DIR}/src/common"
            "${CMAKE_SOURCE_DIR}/src/include/parser/kwlist.h"
    DEPENDS "${CMAKE_SOURCE_DIR}/src/tools/gen_keywordlist.pl"
            "${CMAKE_SOURCE_DIR}/src/tools/PerfectHash.pm"
            "${CMAKE_SOURCE_DIR}/src/include/parser/kwlist.h")
  target_sources(pgcommon PRIVATE "${_gpdb_kwlist_header}")
endif()
if(GPDB_WITH_OPENSSL AND TARGET OpenSSL::Crypto)
  target_link_libraries(pgcommon PUBLIC OpenSSL::Crypto)
endif()

add_library(pgcommon_shlib STATIC ${_gpdb_frontend_common_sources})
add_dependencies(pgcommon_shlib gpdb-generated-paths)
target_compile_definitions(pgcommon_shlib PRIVATE FRONTEND)
target_include_directories(pgcommon_shlib PRIVATE ${_gpdb_generated_include_dirs})
target_link_libraries(pgcommon_shlib PUBLIC pgport_shlib Threads::Threads)
set_target_properties(pgcommon_shlib PROPERTIES POSITION_INDEPENDENT_CODE ON)

add_library(pgcommon_srv STATIC ${_gpdb_common_sources})
add_dependencies(pgcommon_srv gpdb-generated-paths)
target_include_directories(pgcommon_srv PRIVATE ${_gpdb_generated_include_dirs})
target_link_libraries(pgcommon_srv PUBLIC pgport_srv Threads::Threads)
if(GPDB_WITH_OPENSSL AND TARGET OpenSSL::Crypto)
  target_link_libraries(pgcommon_shlib PUBLIC OpenSSL::Crypto)
  target_link_libraries(pgcommon_srv PUBLIC OpenSSL::Crypto)
endif()
if(Perl_FOUND)
  target_sources(pgcommon_shlib PRIVATE "${_gpdb_kwlist_header}")
  target_sources(pgcommon_srv PRIVATE "${_gpdb_kwlist_header}")
endif()

set(_gpdb_feutils_names conditional mbprint print recovery_gen simple_list string_utils)
set(_gpdb_feutils_sources)
foreach(_name IN LISTS _gpdb_feutils_names)
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/fe_utils/${_name}.c")
    list(APPEND _gpdb_feutils_sources "${CMAKE_SOURCE_DIR}/src/fe_utils/${_name}.c")
  endif()
endforeach()
if(GPDB_FLEX_EXECUTABLE)
  set(_gpdb_psqlscan "${CMAKE_CURRENT_BINARY_DIR}/fe_utils/psqlscan.c")
  add_custom_command(
    OUTPUT "${_gpdb_psqlscan}"
    COMMAND ${CMAKE_COMMAND} -E make_directory
            "${CMAKE_CURRENT_BINARY_DIR}/fe_utils"
    COMMAND "${GPDB_FLEX_EXECUTABLE}" -Cfe -p -p -o "${_gpdb_psqlscan}"
            "${CMAKE_SOURCE_DIR}/src/fe_utils/psqlscan.l"
    DEPENDS "${CMAKE_SOURCE_DIR}/src/fe_utils/psqlscan.l")
  list(APPEND _gpdb_feutils_sources "${_gpdb_psqlscan}")
endif()
add_library(pgfeutils STATIC ${_gpdb_feutils_sources})
add_dependencies(pgfeutils gpdb-generated-paths)
target_compile_definitions(pgfeutils PRIVATE FRONTEND)
target_include_directories(pgfeutils PRIVATE ${_gpdb_generated_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")
target_link_libraries(pgfeutils PUBLIC pgcommon pgport Threads::Threads)

set(_gpdb_libpq_names
    fe-auth fe-auth-scram fe-connect fe-exec fe-misc fe-print fe-lobj
    fe-protocol2 fe-protocol3 pqexpbuffer fe-secure legacy-pqsignal
    libpq-events fe-secure-common)
set(_gpdb_libpq_sources)
foreach(_name IN LISTS _gpdb_libpq_names)
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/${_name}.c")
    list(APPEND _gpdb_libpq_sources "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/${_name}.c")
  endif()
endforeach()
list(APPEND _gpdb_libpq_sources
    "${CMAKE_SOURCE_DIR}/src/backend/utils/mb/encnames.c"
    "${CMAKE_SOURCE_DIR}/src/backend/utils/mb/wchar.c")
if(GPDB_WITH_OPENSSL AND EXISTS "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-openssl.c")
  list(APPEND _gpdb_libpq_sources "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-openssl.c")
endif()
if(GPDB_WITH_GSSAPI)
  list(APPEND _gpdb_libpq_sources
      "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-gssapi-common.c"
      "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/fe-secure-gssapi.c")
endif()
add_library(libpq STATIC ${_gpdb_libpq_sources})
add_dependencies(libpq gpdb-generated-paths)
target_compile_definitions(libpq PRIVATE FRONTEND UNSAFE_STAT_OK)
target_include_directories(libpq PRIVATE ${_gpdb_generated_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")
target_link_libraries(libpq PUBLIC pgcommon pgport Threads::Threads)
if(GPDB_WITH_OPENSSL AND TARGET OpenSSL::SSL)
  target_link_libraries(libpq PUBLIC OpenSSL::SSL OpenSSL::Crypto)
endif()
if(GPDB_WITH_GSSAPI)
  target_link_libraries(libpq PUBLIC "${GPDB_GSS_LIBRARY}")
endif()

add_library(libpq_shared SHARED ${_gpdb_libpq_sources})
add_dependencies(libpq_shared gpdb-generated-paths)
target_compile_definitions(libpq_shared PRIVATE FRONTEND UNSAFE_STAT_OK)
target_include_directories(libpq_shared PRIVATE ${_gpdb_generated_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")
target_link_libraries(libpq_shared PUBLIC pgcommon_shlib pgport_shlib Threads::Threads)
set_target_properties(libpq_shared PROPERTIES OUTPUT_NAME pq SOVERSION 5)
if(GPDB_WITH_OPENSSL AND TARGET OpenSSL::SSL)
  target_link_libraries(libpq_shared PUBLIC OpenSSL::SSL OpenSSL::Crypto)
endif()
if(GPDB_WITH_GSSAPI)
  target_link_libraries(libpq_shared PUBLIC "${GPDB_GSS_LIBRARY}")
endif()

add_executable(pg_config "${CMAKE_SOURCE_DIR}/src/bin/pg_config/pg_config.c")
target_compile_definitions(pg_config PRIVATE FRONTEND)
target_include_directories(pg_config PRIVATE ${_gpdb_generated_include_dirs})
target_link_libraries(pg_config PRIVATE pgcommon pgport)

function(gpdb_add_simple_client _target)
  add_executable(${_target} "${CMAKE_SOURCE_DIR}/src/bin/${_target}/${_target}.c")
  target_compile_definitions(${_target} PRIVATE FRONTEND)
  target_include_directories(${_target} PRIVATE ${_gpdb_generated_include_dirs})
  target_link_libraries(${_target} PRIVATE pgcommon pgport Threads::Threads)
endfunction()

gpdb_add_simple_client(pg_archivecleanup)
gpdb_add_simple_client(pg_checksums)
gpdb_add_simple_client(pg_controldata)
gpdb_add_simple_client(pg_ctl)
gpdb_add_simple_client(pg_resetwal)
gpdb_add_simple_client(pg_test_fsync)
gpdb_add_simple_client(pg_test_timing)

set(_gpdb_basebackup_dir "${CMAKE_SOURCE_DIR}/src/bin/pg_basebackup")
add_library(pg_basebackup_common OBJECT
    "${_gpdb_basebackup_dir}/receivelog.c"
    "${_gpdb_basebackup_dir}/streamutil.c"
    "${_gpdb_basebackup_dir}/walmethods.c")
target_compile_definitions(pg_basebackup_common PRIVATE FRONTEND)
target_include_directories(pg_basebackup_common PRIVATE ${_gpdb_generated_include_dirs}
    "${_gpdb_basebackup_dir}"
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")
if(GPDB_WITH_ZLIB AND TARGET ZLIB::ZLIB)
  target_link_libraries(pg_basebackup_common PRIVATE ZLIB::ZLIB)
endif()

function(gpdb_add_basebackup_client _target)
  add_executable(${_target}
      "${_gpdb_basebackup_dir}/${_target}.c"
      $<TARGET_OBJECTS:pg_basebackup_common>)
  target_compile_definitions(${_target} PRIVATE FRONTEND)
  target_include_directories(${_target} PRIVATE ${_gpdb_generated_include_dirs}
      "${_gpdb_basebackup_dir}"
      "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")
  target_link_libraries(${_target} PRIVATE pgfeutils libpq pgcommon pgport Threads::Threads)
  if(GPDB_WITH_ZLIB AND TARGET ZLIB::ZLIB)
    target_link_libraries(${_target} PRIVATE ZLIB::ZLIB)
  endif()
endfunction()

gpdb_add_basebackup_client(pg_basebackup)
gpdb_add_basebackup_client(pg_receivewal)
gpdb_add_basebackup_client(pg_recvlogical)

file(GLOB _gpdb_rmgrdesc_sources CONFIGURE_DEPENDS
    "${CMAKE_SOURCE_DIR}/src/backend/access/rmgrdesc/*desc.c")
add_executable(pg_waldump
    "${CMAKE_SOURCE_DIR}/src/bin/pg_waldump/pg_waldump.c"
    "${CMAKE_SOURCE_DIR}/src/bin/pg_waldump/compat.c"
    "${CMAKE_SOURCE_DIR}/src/bin/pg_waldump/rmgrdesc.c"
    "${CMAKE_SOURCE_DIR}/src/backend/access/transam/xlogreader.c"
    ${_gpdb_rmgrdesc_sources})
target_compile_definitions(pg_waldump PRIVATE FRONTEND)
target_include_directories(pg_waldump PRIVATE ${_gpdb_generated_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/bin/pg_waldump"
    "${CMAKE_SOURCE_DIR}/src/backend")
target_link_libraries(pg_waldump PRIVATE pgcommon pgport Threads::Threads)
if(GPDB_WITH_ZSTD)
  target_link_libraries(pg_waldump PRIVATE "${GPDB_ZSTD_LIBRARY}")
endif()

set(_gpdb_psql_names
    command common copy crosstabview describe help input large_obj mainloop prompt
    startup stringutils tab-complete variables)
set(_gpdb_psql_sources)
foreach(_name IN LISTS _gpdb_psql_names)
  if(EXISTS "${CMAKE_SOURCE_DIR}/src/bin/psql/${_name}.c")
    list(APPEND _gpdb_psql_sources "${CMAKE_SOURCE_DIR}/src/bin/psql/${_name}.c")
  endif()
endforeach()
set(_gpdb_psql_generated_dir "${CMAKE_CURRENT_BINARY_DIR}/psql-generated")
if(GPDB_FLEX_EXECUTABLE)
  set(_gpdb_psql_scan "${_gpdb_psql_generated_dir}/psqlscanslash.c")
  add_custom_command(
    OUTPUT "${_gpdb_psql_scan}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_gpdb_psql_generated_dir}"
    COMMAND "${GPDB_FLEX_EXECUTABLE}" -Cfe -p -p -o "${_gpdb_psql_scan}"
            "${CMAKE_SOURCE_DIR}/src/bin/psql/psqlscanslash.l"
    DEPENDS "${CMAKE_SOURCE_DIR}/src/bin/psql/psqlscanslash.l")
  list(APPEND _gpdb_psql_sources "${_gpdb_psql_scan}")
endif()
if(Perl_FOUND AND EXISTS "${CMAKE_SOURCE_DIR}/doc/src/sgml/ref")
  set(_gpdb_sql_help_h "${_gpdb_psql_generated_dir}/sql_help.h")
  set(_gpdb_sql_help_c "${_gpdb_psql_generated_dir}/sql_help.c")
  add_custom_command(
    OUTPUT "${_gpdb_sql_help_h}" "${_gpdb_sql_help_c}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_gpdb_psql_generated_dir}"
    COMMAND "${PERL_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/src/bin/psql/create_help.pl"
            "${CMAKE_SOURCE_DIR}/doc/src/sgml/ref"
            "${_gpdb_psql_generated_dir}/sql_help"
    DEPENDS "${CMAKE_SOURCE_DIR}/src/bin/psql/create_help.pl")
  list(APPEND _gpdb_psql_sources "${_gpdb_sql_help_c}")
  set_source_files_properties(${_gpdb_psql_sources}
      PROPERTIES OBJECT_DEPENDS "${_gpdb_sql_help_h}")
endif()
add_executable(psql ${_gpdb_psql_sources})
target_compile_definitions(psql PRIVATE FRONTEND)
target_include_directories(psql PRIVATE ${_gpdb_generated_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/bin/psql"
    "${_gpdb_psql_generated_dir}"
    "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")
target_link_libraries(psql PRIVATE pgfeutils libpq pgcommon pgport Threads::Threads)
if(GPDB_WITH_READLINE AND GPDB_READLINE_LIBRARY)
  target_compile_definitions(psql PRIVATE HAVE_LIBREADLINE=1)
  if(GPDB_READLINE_INCLUDE_DIR)
    target_include_directories(psql PRIVATE "${GPDB_READLINE_INCLUDE_DIR}")
  endif()
  target_link_libraries(psql PRIVATE "${GPDB_READLINE_LIBRARY}")
endif()

if(NOT "${GPDB_LDFLAGS_EX}" STREQUAL "")
  separate_arguments(_gpdb_native_exe_ldflags UNIX_COMMAND "${GPDB_LDFLAGS_EX}")
  target_link_options(pg_config PRIVATE ${_gpdb_native_exe_ldflags})
  target_link_options(psql PRIVATE ${_gpdb_native_exe_ldflags})
endif()
if(NOT "${GPDB_LDFLAGS_SL}" STREQUAL "")
  separate_arguments(_gpdb_native_shared_ldflags UNIX_COMMAND "${GPDB_LDFLAGS_SL}")
  target_link_options(libpq_shared PRIVATE ${_gpdb_native_shared_ldflags})
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

add_custom_target(gpdb-native-libraries
  DEPENDS pgport pgport_shlib pgport_srv pgcommon pgcommon_shlib pgcommon_srv
          pgfeutils libpq libpq_shared)
add_custom_target(gpdb-native-clients
  DEPENDS pg_config psql pg_archivecleanup pg_checksums pg_controldata pg_ctl
          pg_resetwal pg_test_fsync pg_test_timing pg_basebackup pg_receivewal
          pg_recvlogical pg_waldump)
