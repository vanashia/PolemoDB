function(gpdb_add_frontend_executable _target)
  add_executable(${_target} ${ARGN})
  gpdb_apply_common_options(${_target})
  add_dependencies(${_target} gpdb-generated)
  target_compile_definitions(${_target} PRIVATE FRONTEND)
  target_include_directories(${_target} PRIVATE ${_gpdb_include_dirs}
    "${CMAKE_SOURCE_DIR}/src/timezone")
  target_link_libraries(${_target} PRIVATE pgcommon pgport gpdb-platform)
endfunction()

gpdb_add_frontend_executable(pg_config src/bin/pg_config/pg_config.c)
foreach(_name IN ITEMS pg_archivecleanup pg_checksums pg_controldata pg_ctl
    pg_resetwal pg_test_fsync pg_test_timing)
  gpdb_add_frontend_executable(${_name} "${CMAKE_SOURCE_DIR}/src/bin/${_name}/${_name}.c")
endforeach()

gpdb_add_frontend_executable(initdb
  src/bin/initdb/initdb.c src/bin/initdb/findtimezone.c
  src/timezone/localtime.c)
target_link_libraries(initdb PRIVATE pgfeutils)
target_link_libraries(initdb PRIVATE libpq)

gpdb_add_frontend_executable(zic src/timezone/zic.c)
set(GPDB_GENERATED_TIMEZONE_DIR "${CMAKE_BINARY_DIR}/generated/share/postgresql/timezone")
set(GPDB_TIMEZONE_STAMP "${GPDB_GENERATED_TIMEZONE_DIR}/.stamp")
add_custom_command(
  OUTPUT "${GPDB_TIMEZONE_STAMP}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_TIMEZONE_DIR}"
  COMMAND "$<TARGET_FILE:zic>" -d "${GPDB_GENERATED_TIMEZONE_DIR}"
          -p US/Eastern -b fat "${CMAKE_SOURCE_DIR}/src/timezone/data/tzdata.zi"
  COMMAND ${CMAKE_COMMAND} -E touch "${GPDB_TIMEZONE_STAMP}"
  DEPENDS zic "${CMAKE_SOURCE_DIR}/src/timezone/data/tzdata.zi"
  VERBATIM)
add_custom_target(gpdb-timezone-data DEPENDS "${GPDB_TIMEZONE_STAMP}")

file(GLOB _gpdb_snowball_sources CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/backend/snowball/libstemmer/stem_*.c")
add_library(dict_snowball MODULE
  src/backend/snowball/dict_snowball.c
  src/backend/snowball/libstemmer/api.c
  src/backend/snowball/libstemmer/utilities.c
  ${_gpdb_snowball_sources})
gpdb_apply_common_options(dict_snowball)
add_dependencies(dict_snowball gpdb-generated)
target_include_directories(dict_snowball PRIVATE ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/include/snowball"
  "${CMAKE_SOURCE_DIR}/src/include/snowball/libstemmer")
set_target_properties(dict_snowball PROPERTIES PREFIX "" SUFFIX ".so")
gpdb_apply_module_link_options(dict_snowball)

set(_gpdb_plpgsql_sources
  src/pl/plpgsql/src/pl_handler.c
  src/pl/plpgsql/src/pl_comp.c
  src/pl/plpgsql/src/pl_exec.c
  src/pl/plpgsql/src/pl_funcs.c
  src/pl/plpgsql/src/pl_scanner.c
  "${GPDB_BISON_plpgsql_C}")
add_library(plpgsql MODULE ${_gpdb_plpgsql_sources})
gpdb_apply_common_options(plpgsql)
add_dependencies(plpgsql gpdb-generated)
target_include_directories(plpgsql PRIVATE ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/pl/plpgsql/src"
  "${GPDB_GENERATED_BACKEND_DIR}/plpgsql")
set_target_properties(plpgsql PROPERTIES PREFIX "" SUFFIX ".so")
gpdb_apply_module_link_options(plpgsql)

add_library(gp_exttable_fdw MODULE
  gpcontrib/gp_exttable_fdw/gp_exttable_fdw.c
  gpcontrib/gp_exttable_fdw/extaccess.c
  gpcontrib/gp_exttable_fdw/option.c)
gpdb_apply_common_options(gp_exttable_fdw)
add_dependencies(gp_exttable_fdw gpdb-generated)
target_include_directories(gp_exttable_fdw PRIVATE ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/gpcontrib/gp_exttable_fdw")
target_link_libraries(gp_exttable_fdw PRIVATE libpq gpdb-platform)
set_target_properties(gp_exttable_fdw PROPERTIES PREFIX "" SUFFIX ".so")
gpdb_apply_module_link_options(gp_exttable_fdw)

# Encoding conversion procedures are loadable backend modules.  The legacy
# build recurses through every directory under conversion_procs; keep the
# same complete set in the native installation so locale and DDL tests can
# resolve the built-in conversion functions from $libdir.
set(GPDB_CONVERSION_TARGETS)
set(_gpdb_conversion_modules
  ascii_and_mic cyrillic_and_mic euc_cn_and_mic euc_jp_and_sjis
  euc_kr_and_mic euc_tw_and_big5 latin2_and_win1250 latin_and_mic
  utf8_and_ascii utf8_and_big5 utf8_and_cyrillic utf8_and_euc_cn
  utf8_and_euc_jp utf8_and_euc_kr utf8_and_euc_tw utf8_and_gb18030
  utf8_and_gbk utf8_and_iso8859 utf8_and_iso8859_1 utf8_and_johab
  utf8_and_sjis utf8_and_win utf8_and_uhc utf8_and_euc2004
  utf8_and_sjis2004 euc2004_sjis2004)
foreach(_conversion_module IN LISTS _gpdb_conversion_modules)
  set(_conversion_sources
    "${CMAKE_SOURCE_DIR}/src/backend/utils/mb/conversion_procs/${_conversion_module}/${_conversion_module}.c")
  if(_conversion_module STREQUAL "euc_tw_and_big5")
    list(APPEND _conversion_sources
      "${CMAKE_SOURCE_DIR}/src/backend/utils/mb/conversion_procs/euc_tw_and_big5/big5.c")
  endif()
  add_library(${_conversion_module} MODULE
    ${_conversion_sources})
  gpdb_apply_common_options(${_conversion_module})
  add_dependencies(${_conversion_module} gpdb-generated)
  target_include_directories(${_conversion_module} PRIVATE
    ${_gpdb_include_dirs} "${CMAKE_SOURCE_DIR}/src/backend")
  target_link_libraries(${_conversion_module} PRIVATE gpdb-platform)
  set_target_properties(${_conversion_module} PROPERTIES PREFIX "" SUFFIX ".so")
  gpdb_apply_module_link_options(${_conversion_module})
  list(APPEND GPDB_CONVERSION_TARGETS ${_conversion_module})
endforeach()

if(GPDB_WITH_ZSTD)
  add_library(gp_zstd_compression MODULE gpcontrib/zstd/zstd_compression.c)
  gpdb_apply_common_options(gp_zstd_compression)
  add_dependencies(gp_zstd_compression gpdb-generated)
  target_include_directories(gp_zstd_compression PRIVATE
    ${_gpdb_include_dirs} "${CMAKE_SOURCE_DIR}/src/backend"
    "${GPDB_ZSTD_INCLUDE_DIR}")
  target_link_libraries(gp_zstd_compression PRIVATE gpdb-platform)
  set_target_properties(gp_zstd_compression PROPERTIES PREFIX "" SUFFIX ".so")
  gpdb_apply_module_link_options(gp_zstd_compression)
endif()

set(_gpdb_toolkit_sources gpcontrib/gp_toolkit/gp_partition_maint.c)
if(CMAKE_SYSTEM_NAME STREQUAL "Linux")
  list(APPEND _gpdb_toolkit_sources gpcontrib/gp_toolkit/resgroup.c)
else()
  list(APPEND _gpdb_toolkit_sources gpcontrib/gp_toolkit/resgroup-dummy.c)
endif()
add_library(gp_toolkit MODULE ${_gpdb_toolkit_sources})
gpdb_apply_common_options(gp_toolkit)
add_dependencies(gp_toolkit gpdb-generated)
target_include_directories(gp_toolkit PRIVATE ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend"
  "${CMAKE_SOURCE_DIR}/gpcontrib/gp_toolkit")
target_link_libraries(gp_toolkit PRIVATE gpdb-platform)
set_target_properties(gp_toolkit PROPERTIES PREFIX "" SUFFIX ".so")
gpdb_apply_module_link_options(gp_toolkit)

foreach(_gpdb_internal_tool IN ITEMS
    gp_ao_co_diagnostics gp_workfile_mgr gp_session_state_memory_stats
    gp_instrument_shmem)
  add_library(${_gpdb_internal_tool} MODULE
    "${CMAKE_SOURCE_DIR}/gpcontrib/gp_internal_tools/${_gpdb_internal_tool}.c")
  gpdb_apply_common_options(${_gpdb_internal_tool})
  add_dependencies(${_gpdb_internal_tool} gpdb-generated)
  target_include_directories(${_gpdb_internal_tool} PRIVATE
    ${_gpdb_include_dirs} "${CMAKE_SOURCE_DIR}/src/backend"
    "${CMAKE_SOURCE_DIR}/gpcontrib/gp_internal_tools")
  target_link_libraries(${_gpdb_internal_tool} PRIVATE gpdb-platform)
  set_target_properties(${_gpdb_internal_tool} PROPERTIES PREFIX "" SUFFIX ".so")
  gpdb_apply_module_link_options(${_gpdb_internal_tool})
endforeach()

add_library(pageinspect MODULE
  contrib/pageinspect/rawpage.c
  contrib/pageinspect/heapfuncs.c
  contrib/pageinspect/bmfuncs.c
  contrib/pageinspect/btreefuncs.c
  contrib/pageinspect/fsmfuncs.c
  contrib/pageinspect/brinfuncs.c
  contrib/pageinspect/ginfuncs.c
  contrib/pageinspect/hashfuncs.c)
gpdb_apply_common_options(pageinspect)
add_dependencies(pageinspect gpdb-generated)
target_include_directories(pageinspect PRIVATE ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend" "${CMAKE_SOURCE_DIR}/contrib/pageinspect")
target_link_libraries(pageinspect PRIVATE gpdb-platform)
set_target_properties(pageinspect PROPERTIES PREFIX "" SUFFIX ".so")
gpdb_apply_module_link_options(pageinspect)

# Source module suites also exercise standard contrib extensions that are not
# part of the production target list.  Build them natively so the test
# artifact has the same extension surface as the legacy installation.
set(GPDB_SOURCE_EXTENSION_TARGETS)
foreach(_source_extension IN ITEMS btree_gin pg_stat_statements)
  add_library(${_source_extension} MODULE
    "${CMAKE_SOURCE_DIR}/contrib/${_source_extension}/${_source_extension}.c")
  gpdb_apply_common_options(${_source_extension})
  add_dependencies(${_source_extension} gpdb-generated)
  target_include_directories(${_source_extension} PRIVATE
    ${_gpdb_include_dirs} "${CMAKE_SOURCE_DIR}/src/backend")
  target_link_libraries(${_source_extension} PRIVATE gpdb-platform)
  set_target_properties(${_source_extension} PROPERTIES PREFIX "" SUFFIX ".so")
  gpdb_apply_module_link_options(${_source_extension})
  list(APPEND GPDB_SOURCE_EXTENSION_TARGETS ${_source_extension})
endforeach()
if(GPDB_WITH_OPENSSL)
  add_library(sslinfo MODULE "${CMAKE_SOURCE_DIR}/contrib/sslinfo/sslinfo.c")
  gpdb_apply_common_options(sslinfo)
  add_dependencies(sslinfo gpdb-generated)
  target_include_directories(sslinfo PRIVATE
    ${_gpdb_include_dirs} "${CMAKE_SOURCE_DIR}/src/backend")
  target_link_libraries(sslinfo PRIVATE gpdb-platform)
  set_target_properties(sslinfo PROPERTIES PREFIX "" SUFFIX ".so")
  gpdb_apply_module_link_options(sslinfo)
  list(APPEND GPDB_SOURCE_EXTENSION_TARGETS sslinfo)
endif()

foreach(_gpdb_debug_extension IN ITEMS gp_inject_fault gp_debug_numsegments)
  add_library(${_gpdb_debug_extension} MODULE
    "${CMAKE_SOURCE_DIR}/gpcontrib/${_gpdb_debug_extension}/${_gpdb_debug_extension}.c")
  gpdb_apply_common_options(${_gpdb_debug_extension})
  add_dependencies(${_gpdb_debug_extension} gpdb-generated)
  target_include_directories(${_gpdb_debug_extension} PRIVATE
    ${_gpdb_include_dirs} "${CMAKE_SOURCE_DIR}/src/backend")
  target_link_libraries(${_gpdb_debug_extension} PRIVATE gpdb-platform)
  set_target_properties(${_gpdb_debug_extension} PROPERTIES PREFIX "" SUFFIX ".so")
  gpdb_apply_module_link_options(${_gpdb_debug_extension})
endforeach()

set(_basebackup_sources
  src/bin/pg_basebackup/receivelog.c src/bin/pg_basebackup/streamutil.c
  src/bin/pg_basebackup/walmethods.c)
foreach(_name IN ITEMS pg_basebackup pg_receivewal pg_recvlogical)
  gpdb_add_frontend_executable(${_name}
    ${_basebackup_sources} "${CMAKE_SOURCE_DIR}/src/bin/pg_basebackup/${_name}.c")
  target_include_directories(${_name} PRIVATE "${CMAKE_SOURCE_DIR}/src/bin/pg_basebackup")
  target_link_libraries(${_name} PRIVATE pgfeutils libpq)
endforeach()

file(GLOB _pg_dump_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/src/bin/pg_dump/*.c")
set(_pg_dump_library_sources ${_pg_dump_sources})
list(FILTER _pg_dump_library_sources EXCLUDE REGEX "/(pg_dump|pg_restore|pg_dumpall|common|pg_dump_sort)\.c$")
gpdb_add_frontend_executable(pg_dump
  ${_pg_dump_library_sources}
  "${CMAKE_SOURCE_DIR}/src/bin/pg_dump/common.c"
  "${CMAKE_SOURCE_DIR}/src/bin/pg_dump/pg_dump_sort.c"
  "${CMAKE_SOURCE_DIR}/src/bin/pg_dump/pg_dump.c")
gpdb_add_frontend_executable(pg_restore
  ${_pg_dump_library_sources}
  "${CMAKE_SOURCE_DIR}/src/bin/pg_dump/pg_restore.c")
gpdb_add_frontend_executable(pg_dumpall
  "${CMAKE_SOURCE_DIR}/src/bin/pg_dump/dumputils.c"
  "${CMAKE_SOURCE_DIR}/src/bin/pg_dump/pg_dumpall.c")
foreach(_name IN ITEMS pg_dump pg_restore pg_dumpall)
  target_include_directories(${_name} PRIVATE "${CMAKE_SOURCE_DIR}/src/bin/pg_dump")
  target_link_libraries(${_name} PRIVATE pgfeutils libpq)
endforeach()

file(GLOB _rewind_sources CONFIGURE_DEPENDS "${CMAKE_SOURCE_DIR}/src/bin/pg_rewind/*.c")
list(APPEND _rewind_sources "${CMAKE_SOURCE_DIR}/src/backend/access/transam/xlogreader.c")
gpdb_add_frontend_executable(pg_rewind ${_rewind_sources})
target_include_directories(pg_rewind PRIVATE "${CMAKE_SOURCE_DIR}/src/bin/pg_rewind"
  "${CMAKE_SOURCE_DIR}/src/backend")
target_link_libraries(pg_rewind PRIVATE pgfeutils libpq)

file(GLOB _waldump_sources CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/bin/pg_waldump/*.c"
  "${CMAKE_SOURCE_DIR}/src/backend/access/rmgrdesc/*.c")
list(APPEND _waldump_sources "${CMAKE_SOURCE_DIR}/src/backend/access/transam/xlogreader.c")
gpdb_add_frontend_executable(pg_waldump ${_waldump_sources})
target_include_directories(pg_waldump PRIVATE "${CMAKE_SOURCE_DIR}/src/bin/pg_waldump"
  "${CMAKE_SOURCE_DIR}/src/backend")
if(GPDB_WITH_ZSTD)
  target_link_libraries(pg_waldump PRIVATE "${GPDB_ZSTD_LIBRARY}")
endif()

set(_psql_generated_dir "${CMAKE_BINARY_DIR}/generated/src/bin/psql")
set(_psql_scan "${_psql_generated_dir}/psqlscanslash.c")
add_custom_command(OUTPUT "${_psql_scan}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${_psql_generated_dir}"
  COMMAND "${GPDB_FLEX_EXECUTABLE}" -Cfe -p -p -o "${_psql_scan}"
          "${CMAKE_SOURCE_DIR}/src/bin/psql/psqlscanslash.l"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/bin/psql/psqlscanslash.l" VERBATIM)
file(GLOB _psql_help_docs CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/doc/src/sgml/ref/*.sgml")
set(_psql_help_h "${_psql_generated_dir}/sql_help.h")
set(_psql_help_c "${_psql_generated_dir}/sql_help.c")
add_custom_command(
  OUTPUT "${_psql_help_h}" "${_psql_help_c}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${_psql_generated_dir}"
  COMMAND "${GPDB_PERL_EXECUTABLE}" "${CMAKE_SOURCE_DIR}/src/bin/psql/create_help.pl"
          "${CMAKE_SOURCE_DIR}/doc/src/sgml/ref"
          "${_psql_generated_dir}/sql_help"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/bin/psql/create_help.pl" ${_psql_help_docs}
  VERBATIM)
set(_psql_sources)
foreach(_name IN ITEMS command common copy crosstabview describe help input large_obj
    mainloop prompt startup stringutils tab-complete variables)
  list(APPEND _psql_sources "${CMAKE_SOURCE_DIR}/src/bin/psql/${_name}.c")
endforeach()
list(APPEND _psql_sources "${_psql_scan}" "${_psql_help_c}")
gpdb_add_frontend_executable(psql ${_psql_sources})
set_source_files_properties("${CMAKE_SOURCE_DIR}/src/bin/psql/help.c"
  PROPERTIES OBJECT_DEPENDS "${_psql_help_h}")
target_include_directories(psql PRIVATE "${CMAKE_SOURCE_DIR}/src/bin/psql"
  "${_psql_generated_dir}" "${CMAKE_SOURCE_DIR}/src/interfaces/libpq")
target_link_libraries(psql PRIVATE pgfeutils libpq)
if(GPDB_WITH_READLINE AND GPDB_READLINE_LIBRARY)
  target_compile_definitions(psql PRIVATE HAVE_LIBREADLINE=1)
  target_include_directories(psql PRIVATE "${GPDB_READLINE_INCLUDE_DIR}")
  target_link_libraries(psql PRIVATE "${GPDB_READLINE_LIBRARY}")
endif()

file(GLOB _script_common_sources CONFIGURE_DEPENDS
  "${CMAKE_SOURCE_DIR}/src/bin/scripts/common.c")
foreach(_name IN ITEMS clusterdb createdb createuser dropdb dropuser pg_isready reindexdb
    vacuumdb)
  gpdb_add_frontend_executable(${_name}
    ${_script_common_sources} "${CMAKE_SOURCE_DIR}/src/bin/scripts/${_name}.c")
  target_include_directories(${_name} PRIVATE "${CMAKE_SOURCE_DIR}/src/bin/scripts")
  target_link_libraries(${_name} PRIVATE pgfeutils libpq)
endforeach()

if(EXISTS "${CMAKE_SOURCE_DIR}/src/bin/pgbench/pgbench.c")
  set(_pgbench_generated_dir "${CMAKE_BINARY_DIR}/generated/src/bin/pgbench")
  set(_pgbench_exprparse "${_pgbench_generated_dir}/exprparse.c")
  set(_pgbench_exprparse_h "${_pgbench_generated_dir}/exprparse.h")
  set(_pgbench_exprscan "${_pgbench_generated_dir}/exprscan.c")
  add_custom_command(
    OUTPUT "${_pgbench_exprparse}" "${_pgbench_exprparse_h}" "${_pgbench_exprscan}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_pgbench_generated_dir}"
    COMMAND "${GPDB_BISON_EXECUTABLE}" -d
            -o "${_pgbench_exprparse}"
            "${CMAKE_SOURCE_DIR}/src/bin/pgbench/exprparse.y"
    COMMAND "${GPDB_FLEX_EXECUTABLE}" -o "${_pgbench_exprscan}"
            "${CMAKE_SOURCE_DIR}/src/bin/pgbench/exprscan.l"
    DEPENDS "${CMAKE_SOURCE_DIR}/src/bin/pgbench/exprparse.y"
            "${CMAKE_SOURCE_DIR}/src/bin/pgbench/exprscan.l"
    VERBATIM)
  gpdb_add_frontend_executable(pgbench
    src/bin/pgbench/pgbench.c "${_pgbench_exprparse}")
  target_include_directories(pgbench PRIVATE
    "${CMAKE_SOURCE_DIR}/src/bin/pgbench"
    "${_pgbench_generated_dir}")
  set_source_files_properties(src/bin/pgbench/pgbench.c
    PROPERTIES OBJECT_DEPENDS "${_pgbench_exprparse_h}")
  target_link_libraries(pgbench PRIVATE pgfeutils libpq)
endif()

set(_gpdb_compression_targets)
if(TARGET gp_zstd_compression)
  list(APPEND _gpdb_compression_targets gp_zstd_compression)
endif()

add_custom_target(gpdb-clients DEPENDS
  pg_config initdb zic gpdb-timezone-data dict_snowball plpgsql gp_exttable_fdw gp_toolkit
  gp_ao_co_diagnostics gp_workfile_mgr gp_session_state_memory_stats gp_instrument_shmem
  pageinspect gp_inject_fault gp_debug_numsegments ${_gpdb_compression_targets}
  libpq_shared pg_archivecleanup pg_checksums pg_controldata pg_ctl
  pg_resetwal pg_test_fsync pg_test_timing pg_basebackup pg_receivewal
  pg_recvlogical pg_dump pg_restore pg_dumpall pg_rewind pg_waldump psql
  clusterdb createdb createuser dropdb dropuser pg_isready reindexdb vacuumdb pgbench)
