find_program(GPDB_PERL_EXECUTABLE perl REQUIRED)
if(APPLE)
  # macOS ships an old Bison 2.3 which cannot parse the Greenplum grammar.
  # Prefer the versioned Homebrew locations before falling back to PATH.
  find_program(GPDB_BISON_EXECUTABLE bison
    HINTS /opt/homebrew/opt/bison/bin /usr/local/opt/bison/bin)
else()
  find_program(GPDB_BISON_EXECUTABLE bison)
endif()
if(NOT GPDB_BISON_EXECUTABLE)
  message(FATAL_ERROR "Bison is required to generate the parser sources")
endif()
find_program(GPDB_FLEX_EXECUTABLE flex REQUIRED)

set(GPDB_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/generated")
set(GPDB_GENERATED_INCLUDE_DIR "${GPDB_GENERATED_DIR}/src/include")
set(GPDB_GENERATED_BACKEND_DIR "${GPDB_GENERATED_DIR}/src/backend")
set(GPDB_GENERATED_SHARED_DIR "${GPDB_GENERATED_DIR}/share/postgresql")
file(MAKE_DIRECTORY "${GPDB_GENERATED_INCLUDE_DIR}")
file(MAKE_DIRECTORY "${GPDB_GENERATED_BACKEND_DIR}")
file(MAKE_DIRECTORY "${GPDB_GENERATED_SHARED_DIR}")

math(EXPR _gpdb_blcksz "${GPDB_BLOCKSIZE} * 1024")
math(EXPR _gpdb_relseg_size "(${GPDB_SEGSIZE} * 1024 * 1024 * 1024) / ${_gpdb_blcksz}")
math(EXPR _gpdb_xlog_blcksz "${GPDB_WAL_BLOCKSIZE} * 1024")
string(REGEX MATCH "^([0-9]+)\\.([0-9]+)" _gpdb_pg_version_match "${GPDB_PG_VERSION}")
math(EXPR _gpdb_pg_version_num "${CMAKE_MATCH_1} * 10000 + ${CMAKE_MATCH_2}")
string(REGEX MATCH "^[0-9]+" _gpdb_pg_major "${GPDB_PG_VERSION}")
if(CMAKE_SYSTEM_PROCESSOR MATCHES "^(arm64|aarch64)$")
  set(_gpdb_use_armv8_crc32c ON)
else()
  set(_gpdb_use_armv8_crc32c OFF)
endif()
if(NOT WIN32)
  set(_gpdb_use_sysv_semaphores ON)
else()
  set(_gpdb_use_sysv_semaphores OFF)
endif()

set(_gpdb_pg_config "${GPDB_GENERATED_INCLUDE_DIR}/pg_config.h")
add_custom_command(
  OUTPUT "${_gpdb_pg_config}"
  COMMAND ${CMAKE_COMMAND}
    -DTEMPLATE=${CMAKE_SOURCE_DIR}/src/include/pg_config.h.in
    -DOUTPUT=${_gpdb_pg_config}
    -DBLCKSZ=${_gpdb_blcksz}
    -DRELSEG_SIZE=${_gpdb_relseg_size}
    -DXLOG_BLCKSZ=${_gpdb_xlog_blcksz}
    -DDEF_PGPORT=${GPDB_PGPORT}
    -DGP_MAJORVERSION=${GPDB_MAJOR_VERSION}
    -DGP_VERSION=${GPDB_VERSION}
    -DGP_VERSION_NUM=70000
    -DPG_VERSION_VALUE=${GPDB_PG_VERSION}
    -DPG_MAJORVERSION_VALUE=${_gpdb_pg_major}
    -DPG_VERSION_NUM_VALUE=${_gpdb_pg_version_num}
    -DUSE_OPENSSL=${GPDB_WITH_OPENSSL}
    -DUSE_OPENSSL_RANDOM=${GPDB_WITH_OPENSSL}
    -DUSE_DEV_URANDOM=$<NOT:$<BOOL:${GPDB_WITH_OPENSSL}>>
    -DHAVE_LIBSSL=${GPDB_WITH_OPENSSL}
    -DHAVE_LIBBZ2=${GPDB_WITH_LIBBZ2}
    -DHAVE_LIBZ=${GPDB_WITH_ZLIB}
    -DHAVE_SHM_OPEN=${GPDB_HAVE_SHM_OPEN}
    -DHAVE_LIBREADLINE=$<BOOL:${GPDB_WITH_READLINE}>
    -DHAVE_READLINE_READLINE_H=$<BOOL:${GPDB_WITH_READLINE}>
    -DHAVE_READLINE_HISTORY_H=$<BOOL:${GPDB_WITH_READLINE}>
    -DENABLE_GSS=${GPDB_WITH_GSSAPI}
    -DHAVE_GSSAPI_GSSAPI_H=${GPDB_WITH_GSSAPI}
    -DENABLE_THREAD_SAFETY=${GPDB_ENABLE_THREAD_SAFETY}
    -DUSE_LIBXML=${GPDB_WITH_LIBXML}
    -DUSE_ZSTD=${GPDB_WITH_ZSTD}
    -DUSE_ORCA=${GPDB_ENABLE_ORCA}
    -DUSE_ARMV8_CRC32C=${_gpdb_use_armv8_crc32c}
    -DUSE_SYSV_SEMAPHORES=${_gpdb_use_sysv_semaphores}
    -DUSE_SYSV_SHARED_MEMORY=${_gpdb_use_sysv_semaphores}
    -DFAULT_INJECTOR=${GPDB_ENABLE_DEBUG_EXTENSIONS}
    -P ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_pg_config.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/include/pg_config.h.in"
          "${CMAKE_SOURCE_DIR}/cmake/scripts/generate_pg_config.cmake"
  VERBATIM)

set(_gpdb_system_views_gp "${GPDB_GENERATED_SHARED_DIR}/system_views_gp.sql")
add_custom_command(
  OUTPUT "${_gpdb_system_views_gp}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_SHARED_DIR}"
  COMMAND ${CMAKE_COMMAND} -DINPUT=${CMAKE_SOURCE_DIR}/src/backend/catalog/system_views_gp.in
          -DOUTPUT=${_gpdb_system_views_gp}
          -P ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_system_views_gp.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/catalog/system_views_gp.in"
          "${CMAKE_SOURCE_DIR}/cmake/scripts/generate_system_views_gp.cmake"
  VERBATIM)

set(_gpdb_snowball_create "${GPDB_GENERATED_SHARED_DIR}/snowball_create.sql")
add_custom_command(
  OUTPUT "${_gpdb_snowball_create}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_SHARED_DIR}"
  COMMAND ${CMAKE_COMMAND} -DSOURCE_DIR=${CMAKE_SOURCE_DIR}/src/backend/snowball
          -DOUTPUT=${_gpdb_snowball_create}
          -P ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_snowball_create.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/snowball/snowball_func.sql.in"
          "${CMAKE_SOURCE_DIR}/src/backend/snowball/snowball.sql.in"
          "${CMAKE_SOURCE_DIR}/cmake/scripts/generate_snowball_create.cmake"
  VERBATIM)

set(_gpdb_pg_config_ext "${GPDB_GENERATED_INCLUDE_DIR}/pg_config_ext.h")
add_custom_command(
  OUTPUT "${_gpdb_pg_config_ext}"
  COMMAND ${CMAKE_COMMAND} -DOUTPUT=${_gpdb_pg_config_ext}
          -P ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_pg_config_ext.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/cmake/scripts/generate_pg_config_ext.cmake")

if(APPLE)
  set(_gpdb_os_template "${CMAKE_SOURCE_DIR}/src/include/port/darwin.h")
else()
  set(_gpdb_os_template "${CMAKE_SOURCE_DIR}/src/include/port/linux.h")
endif()
set(_gpdb_pg_config_os "${GPDB_GENERATED_INCLUDE_DIR}/pg_config_os.h")
add_custom_command(
  OUTPUT "${_gpdb_pg_config_os}"
  COMMAND ${CMAKE_COMMAND} -E copy "${_gpdb_os_template}" "${_gpdb_pg_config_os}"
  DEPENDS "${_gpdb_os_template}")

set(_gpdb_pg_paths "${GPDB_GENERATED_DIR}/src/port/pg_config_paths.h")
add_custom_command(
  OUTPUT "${_gpdb_pg_paths}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_DIR}/src/port"
  COMMAND ${CMAKE_COMMAND}
    -DOUTPUT=${_gpdb_pg_paths}
    -DBINDIR=${CMAKE_INSTALL_FULL_BINDIR}
    -DDATADIR=${CMAKE_INSTALL_FULL_DATADIR}/postgresql
    -DSYSCONFDIR=${CMAKE_INSTALL_FULL_SYSCONFDIR}
    -DINCLUDEDIR=${CMAKE_INSTALL_FULL_INCLUDEDIR}
    -DPKGINCLUDEDIR=${CMAKE_INSTALL_FULL_INCLUDEDIR}/postgresql
    -DINCLUDEDIRSERVER=${CMAKE_INSTALL_FULL_INCLUDEDIR}/postgresql/server
    -DLIBDIR=${CMAKE_INSTALL_FULL_LIBDIR}
    -DPKGLIBDIR=${CMAKE_INSTALL_FULL_LIBDIR}/postgresql
    -DLOCALEDIR=${CMAKE_INSTALL_FULL_LOCALEDIR}
    -DDOCDIR=${CMAKE_INSTALL_FULL_DOCDIR}
    -DHTMLDIR=${CMAKE_INSTALL_FULL_DOCDIR}
    -DMANDIR=${CMAKE_INSTALL_FULL_MANDIR}
    -P ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_pg_config_paths.cmake
  VERBATIM)

set(GPDB_VERSION_LONG "${GPDB_VERSION}" CACHE INTERNAL "Full GP version")
configure_file("${CMAKE_SOURCE_DIR}/src/include/catalog/gp_version_at_initdb.dat.in"
               "${GPDB_GENERATED_INCLUDE_DIR}/catalog/gp_version_at_initdb.dat" @ONLY)

set(_catalog_names
  pg_proc pg_type pg_attribute pg_class pg_attrdef pg_constraint pg_inherits
  pg_index pg_operator pg_opfamily pg_opclass pg_am pg_amop pg_amproc
  pg_language pg_largeobject_metadata pg_largeobject pg_aggregate
  pg_statistic_ext pg_statistic_ext_data pg_statistic pg_rewrite pg_trigger
  pg_event_trigger pg_description pg_cast pg_enum pg_namespace pg_conversion
  pg_depend pg_database pg_db_role_setting pg_tablespace pg_pltemplate pg_authid
  pg_auth_members pg_shdepend pg_shdescription pg_ts_config pg_ts_config_map
  pg_ts_dict pg_ts_parser pg_ts_template pg_extension pg_foreign_data_wrapper
  pg_foreign_server pg_user_mapping pg_resqueue pg_resqueuecapability
  pg_resourcetype pg_resgroup pg_resgroupcapability gp_configuration_history
  gp_id gp_distribution_policy gp_version_at_initdb gp_segment_configuration
  pg_appendonly gp_fastsequence pg_extprotocol pg_attribute_encoding
  pg_auth_time_constraint pg_compression pg_proc_callback pg_type_encoding
  pg_stat_last_operation pg_stat_last_shoperation pg_foreign_table pg_policy
  pg_replication_origin pg_default_acl pg_init_privs pg_seclabel pg_shseclabel
  pg_collation pg_partitioned_table pg_range pg_transform pg_sequence
  pg_publication pg_publication_rel pg_subscription pg_subscription_rel
  gp_partition_template)
set(_catalog_inputs)
set(_catalog_command_inputs)
set(_catalog_outputs)
foreach(_name IN LISTS _catalog_names)
  list(APPEND _catalog_inputs "${CMAKE_SOURCE_DIR}/src/include/catalog/${_name}.h")
  if(_name STREQUAL "gp_version_at_initdb")
    list(APPEND _catalog_command_inputs "${GPDB_GENERATED_INCLUDE_DIR}/catalog/${_name}.h")
  else()
    list(APPEND _catalog_command_inputs "${CMAKE_SOURCE_DIR}/src/include/catalog/${_name}.h")
  endif()
  list(APPEND _catalog_outputs "${GPDB_GENERATED_INCLUDE_DIR}/catalog/${_name}_d.h")
endforeach()
list(APPEND _catalog_inputs
  "${CMAKE_SOURCE_DIR}/src/include/catalog/toasting.h"
  "${CMAKE_SOURCE_DIR}/src/include/catalog/indexing.h"
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/gp_version_at_initdb.dat")
list(APPEND _catalog_command_inputs
  "${CMAKE_SOURCE_DIR}/src/include/catalog/toasting.h"
  "${CMAKE_SOURCE_DIR}/src/include/catalog/indexing.h")
list(APPEND _catalog_outputs
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/postgres.bki"
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/postgres.description"
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/postgres.shdescription"
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/schemapg.h")
add_custom_command(
  OUTPUT ${_catalog_outputs}
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_INCLUDE_DIR}/catalog"
  COMMAND ${CMAKE_COMMAND} -E copy
          "${CMAKE_SOURCE_DIR}/src/include/catalog/gp_version_at_initdb.h"
          "${GPDB_GENERATED_INCLUDE_DIR}/catalog/gp_version_at_initdb.h"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_INCLUDE_DIR}/catalog"
  COMMAND "${GPDB_PERL_EXECUTABLE}" -I "${CMAKE_SOURCE_DIR}/src/backend/catalog"
          "${CMAKE_SOURCE_DIR}/src/backend/catalog/genbki.pl"
          --output "${GPDB_GENERATED_INCLUDE_DIR}/catalog"
          --include-path=${CMAKE_SOURCE_DIR}/src/include
          --set-version=${_gpdb_pg_major}
          ${_catalog_command_inputs}
  WORKING_DIRECTORY "${GPDB_GENERATED_INCLUDE_DIR}/catalog"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/catalog/genbki.pl"
          "${CMAKE_SOURCE_DIR}/src/backend/catalog/Catalog.pm"
          ${_catalog_inputs}
  VERBATIM)

set(_gpdb_fmgr_outputs
  "${GPDB_GENERATED_INCLUDE_DIR}/utils/fmgroids.h"
  "${GPDB_GENERATED_INCLUDE_DIR}/utils/fmgrprotos.h"
  "${GPDB_GENERATED_BACKEND_DIR}/utils/fmgrtab.c")
add_custom_command(
  OUTPUT ${_gpdb_fmgr_outputs}
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_INCLUDE_DIR}/utils"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_BACKEND_DIR}/utils"
  COMMAND "${GPDB_PERL_EXECUTABLE}" -I "${CMAKE_SOURCE_DIR}/src/backend/catalog"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/Gen_fmgrtab.pl"
          --output "${GPDB_GENERATED_BACKEND_DIR}/utils"
          --include-path=${CMAKE_SOURCE_DIR}/src/include
          "${CMAKE_SOURCE_DIR}/src/include/catalog/pg_proc.dat"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/utils/Gen_fmgrtab.pl"
          "${CMAKE_SOURCE_DIR}/src/backend/catalog/Catalog.pm"
          "${CMAKE_SOURCE_DIR}/src/include/catalog/pg_proc.h"
          "${CMAKE_SOURCE_DIR}/src/include/catalog/pg_proc.dat"
  VERBATIM)

set(_gpdb_errcodes "${GPDB_GENERATED_INCLUDE_DIR}/utils/errcodes.h")
add_custom_command(
  OUTPUT "${_gpdb_errcodes}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_INCLUDE_DIR}/utils"
  COMMAND ${CMAKE_COMMAND}
    -DOUTPUT=${_gpdb_errcodes}
    -DPERL=${GPDB_PERL_EXECUTABLE}
    -DSCRIPT=${CMAKE_SOURCE_DIR}/src/backend/utils/generate-errcodes.pl
    -DINPUT=${CMAKE_SOURCE_DIR}/src/backend/utils/errcodes.txt
    -P ${CMAKE_SOURCE_DIR}/cmake/scripts/run_perl_to_file.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/utils/generate-errcodes.pl"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/errcodes.txt"
          "${CMAKE_SOURCE_DIR}/cmake/scripts/run_perl_to_file.cmake"
  VERBATIM)

set(_gpdb_kwlist "${GPDB_GENERATED_DIR}/src/common/kwlist_d.h")
add_custom_command(
  OUTPUT "${_gpdb_kwlist}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_DIR}/src/common"
  COMMAND "${GPDB_PERL_EXECUTABLE}" -I "${CMAKE_SOURCE_DIR}/src/tools"
          "${CMAKE_SOURCE_DIR}/src/tools/gen_keywordlist.pl" --extern
          -o "${GPDB_GENERATED_DIR}/src/common"
          "${CMAKE_SOURCE_DIR}/src/include/parser/kwlist.h"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/tools/gen_keywordlist.pl"
          "${CMAKE_SOURCE_DIR}/src/tools/PerfectHash.pm"
          "${CMAKE_SOURCE_DIR}/src/include/parser/kwlist.h"
  VERBATIM)

set(_gpdb_qsort_tuple "${GPDB_GENERATED_BACKEND_DIR}/sort/qsort_tuple.c")
add_custom_command(
  OUTPUT "${_gpdb_qsort_tuple}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_BACKEND_DIR}/sort"
  COMMAND ${CMAKE_COMMAND}
    -DOUTPUT=${_gpdb_qsort_tuple}
    -DPERL=${GPDB_PERL_EXECUTABLE}
    -DSCRIPT=${CMAKE_SOURCE_DIR}/src/backend/utils/sort/gen_qsort_tuple.pl
    -DINPUT=${CMAKE_SOURCE_DIR}/src/backend/utils/sort/gen_qsort_tuple.pl
    -P ${CMAKE_SOURCE_DIR}/cmake/scripts/run_perl_to_file.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/utils/sort/gen_qsort_tuple.pl"
          "${CMAKE_SOURCE_DIR}/cmake/scripts/run_perl_to_file.cmake"
  VERBATIM)

set(_gpdb_lwlock_h "${GPDB_GENERATED_BACKEND_DIR}/storage/lwlocknames.h")
set(_gpdb_lwlock_c "${GPDB_GENERATED_BACKEND_DIR}/storage/lwlocknames.c")
add_custom_command(
  OUTPUT "${_gpdb_lwlock_h}" "${_gpdb_lwlock_c}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_BACKEND_DIR}/storage"
  COMMAND "${GPDB_PERL_EXECUTABLE}"
          "${CMAKE_SOURCE_DIR}/src/backend/storage/lmgr/generate-lwlocknames.pl"
          "${CMAKE_SOURCE_DIR}/src/backend/storage/lmgr/lwlocknames.txt"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/storage/lmgr/generate-lwlocknames.pl"
          "${CMAKE_SOURCE_DIR}/src/backend/storage/lmgr/lwlocknames.txt"
  WORKING_DIRECTORY "${GPDB_GENERATED_BACKEND_DIR}/storage"
  VERBATIM)

function(gpdb_add_bison _name _source)
  set(_out_dir "${GPDB_GENERATED_BACKEND_DIR}/${_name}")
  get_filename_component(_base "${_source}" NAME_WE)
  set(_c "${_out_dir}/${_base}.c")
  set(_h "${_out_dir}/${_base}.h")
  add_custom_command(OUTPUT "${_c}" "${_h}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_out_dir}"
    COMMAND "${GPDB_BISON_EXECUTABLE}" -d -o "${_c}" "${CMAKE_SOURCE_DIR}/${_source}"
    DEPENDS "${CMAKE_SOURCE_DIR}/${_source}" VERBATIM)
  set(GPDB_BISON_${_name}_C "${_c}" PARENT_SCOPE)
  set(GPDB_BISON_${_name}_H "${_h}" PARENT_SCOPE)
endfunction()
function(gpdb_add_flex _name _source)
  set(_out_dir "${GPDB_GENERATED_BACKEND_DIR}/${_name}")
  get_filename_component(_base "${_source}" NAME_WE)
  set(_c "${_out_dir}/${_base}.c")
  add_custom_command(OUTPUT "${_c}"
    COMMAND ${CMAKE_COMMAND} -E make_directory "${_out_dir}"
    COMMAND "${GPDB_FLEX_EXECUTABLE}" -CF -p -p -o "${_c}" "${CMAKE_SOURCE_DIR}/${_source}"
    DEPENDS "${CMAKE_SOURCE_DIR}/${_source}" VERBATIM)
  set(GPDB_FLEX_${_name}_C "${_c}" PARENT_SCOPE)
endfunction()

gpdb_add_bison(parser src/backend/parser/gram.y)
gpdb_add_flex(parser src/backend/parser/scan.l)
gpdb_add_bison(bootstrap src/backend/bootstrap/bootparse.y)
gpdb_add_flex(bootstrap src/backend/bootstrap/bootscanner.l)
gpdb_add_bison(replication src/backend/replication/repl_gram.y)
gpdb_add_flex(replication src/backend/replication/repl_scanner.l)
gpdb_add_bison(syncrep src/backend/replication/syncrep_gram.y)
gpdb_add_flex(syncrep src/backend/replication/syncrep_scanner.l)
gpdb_add_bison(statistics src/backend/statistics/statistics_gram.y)
gpdb_add_flex(statistics src/backend/statistics/statistics_scanner.l)
gpdb_add_bison(jsonpath src/backend/utils/adt/jsonpath_gram.y)
gpdb_add_bison(plpgsql src/pl/plpgsql/src/pl_gram.y)
gpdb_add_flex(jsonpath src/backend/utils/adt/jsonpath_scan.l)
gpdb_add_flex(guc_file src/backend/utils/misc/guc-file.l)
gpdb_add_bison(io_limit src/backend/utils/resgroup/io_limit_gram.y)
gpdb_add_flex(io_limit src/backend/utils/resgroup/io_limit_scanner.l)
gpdb_add_flex(fe_utils src/fe_utils/psqlscan.l)

set(_gpdb_plpgsql_dir "${GPDB_GENERATED_BACKEND_DIR}/plpgsql")
set(_gpdb_plerrcodes "${_gpdb_plpgsql_dir}/plerrcodes.h")
add_custom_command(
  OUTPUT "${_gpdb_plerrcodes}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${_gpdb_plpgsql_dir}"
  COMMAND ${CMAKE_COMMAND}
    -DOUTPUT=${_gpdb_plerrcodes}
    -DPERL=${GPDB_PERL_EXECUTABLE}
    -DSCRIPT=${CMAKE_SOURCE_DIR}/src/pl/plpgsql/src/generate-plerrcodes.pl
    -DINPUT=${CMAKE_SOURCE_DIR}/src/backend/utils/errcodes.txt
    -P ${CMAKE_SOURCE_DIR}/cmake/scripts/run_perl_to_file.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/pl/plpgsql/src/generate-plerrcodes.pl"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/errcodes.txt"
          "${CMAKE_SOURCE_DIR}/cmake/scripts/run_perl_to_file.cmake"
  VERBATIM)
set(_gpdb_pl_reserved_kwlist "${_gpdb_plpgsql_dir}/pl_reserved_kwlist_d.h")
set(_gpdb_pl_unreserved_kwlist "${_gpdb_plpgsql_dir}/pl_unreserved_kwlist_d.h")
add_custom_command(
  OUTPUT "${_gpdb_pl_reserved_kwlist}" "${_gpdb_pl_unreserved_kwlist}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${_gpdb_plpgsql_dir}"
  COMMAND "${GPDB_PERL_EXECUTABLE}" -I "${CMAKE_SOURCE_DIR}/src/tools"
          "${CMAKE_SOURCE_DIR}/src/tools/gen_keywordlist.pl"
          --varname ReservedPLKeywords -o "${_gpdb_plpgsql_dir}"
          "${CMAKE_SOURCE_DIR}/src/pl/plpgsql/src/pl_reserved_kwlist.h"
  COMMAND "${GPDB_PERL_EXECUTABLE}" -I "${CMAKE_SOURCE_DIR}/src/tools"
          "${CMAKE_SOURCE_DIR}/src/tools/gen_keywordlist.pl"
          --varname UnreservedPLKeywords -o "${_gpdb_plpgsql_dir}"
          "${CMAKE_SOURCE_DIR}/src/pl/plpgsql/src/pl_unreserved_kwlist.h"
  DEPENDS "${CMAKE_SOURCE_DIR}/src/tools/gen_keywordlist.pl"
          "${CMAKE_SOURCE_DIR}/src/tools/PerfectHash.pm"
          "${CMAKE_SOURCE_DIR}/src/pl/plpgsql/src/pl_reserved_kwlist.h"
          "${CMAKE_SOURCE_DIR}/src/pl/plpgsql/src/pl_unreserved_kwlist.h"
  VERBATIM)

set(_gpdb_probes "${GPDB_GENERATED_INCLUDE_DIR}/utils/probes.h")
add_custom_command(
  OUTPUT "${_gpdb_probes}"
  COMMAND ${CMAKE_COMMAND} -E make_directory "${GPDB_GENERATED_INCLUDE_DIR}/utils"
  COMMAND ${CMAKE_COMMAND}
    -DINPUT=${CMAKE_SOURCE_DIR}/src/backend/utils/probes.d
    -DSCRIPT=${CMAKE_SOURCE_DIR}/src/backend/utils/Gen_dummy_probes.sed
    -DOUTPUT=${_gpdb_probes}
    -P ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_probes.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/backend/utils/Gen_dummy_probes.sed"
          "${CMAKE_SOURCE_DIR}/src/backend/utils/probes.d"
          "${CMAKE_SOURCE_DIR}/cmake/scripts/generate_probes.cmake"
  VERBATIM)

add_custom_target(gpdb-generated
  DEPENDS "${_gpdb_pg_config}" "${_gpdb_pg_config_ext}" "${_gpdb_pg_config_os}" "${_gpdb_pg_paths}"
          "${_gpdb_system_views_gp}" "${_gpdb_snowball_create}"
          ${_catalog_outputs} ${_gpdb_fmgr_outputs} "${_gpdb_errcodes}" "${_gpdb_kwlist}" "${_gpdb_qsort_tuple}"
          "${_gpdb_lwlock_h}" "${_gpdb_lwlock_c}"
          "${GPDB_BISON_parser_C}" "${GPDB_BISON_parser_H}" "${GPDB_FLEX_parser_C}"
          "${GPDB_BISON_bootstrap_C}" "${GPDB_BISON_bootstrap_H}" "${GPDB_FLEX_bootstrap_C}"
          "${GPDB_BISON_replication_C}" "${GPDB_BISON_replication_H}" "${GPDB_FLEX_replication_C}"
          "${GPDB_BISON_syncrep_C}" "${GPDB_BISON_syncrep_H}" "${GPDB_FLEX_syncrep_C}"
          "${GPDB_BISON_statistics_C}" "${GPDB_BISON_statistics_H}" "${GPDB_FLEX_statistics_C}"
          "${GPDB_BISON_jsonpath_C}" "${GPDB_BISON_jsonpath_H}" "${GPDB_FLEX_jsonpath_C}"
          "${GPDB_BISON_plpgsql_C}" "${GPDB_BISON_plpgsql_H}" "${_gpdb_plerrcodes}"
          "${_gpdb_pl_reserved_kwlist}" "${_gpdb_pl_unreserved_kwlist}"
          "${GPDB_FLEX_guc_file_C}" "${GPDB_BISON_io_limit_C}" "${GPDB_BISON_io_limit_H}"
          "${GPDB_FLEX_io_limit_C}" "${GPDB_FLEX_fe_utils_C}" "${_gpdb_probes}")

set(GPDB_GENERATED_INCLUDE_DIRS
  "${GPDB_GENERATED_INCLUDE_DIR}"
  "${GPDB_GENERATED_BACKEND_DIR}"
  "${GPDB_GENERATED_DIR}/src"
  "${GPDB_GENERATED_DIR}/src/common"
  "${GPDB_GENERATED_DIR}/src/port"
  )
set(GPDB_GENERATED_CONFIG_HEADER "${_gpdb_pg_config}")
set(GPDB_GENERATED_CONFIG_EXT_HEADER "${_gpdb_pg_config_ext}")
set(GPDB_GENERATED_CONFIG_OS_HEADER "${_gpdb_pg_config_os}")
set(GPDB_GENERATED_PATH_HEADER "${_gpdb_pg_paths}")
set(GPDB_GENERATED_CATALOG_OUTPUTS ${_catalog_outputs})
set(GPDB_GENERATED_FMGR_OUTPUTS ${_gpdb_fmgr_outputs})
set(GPDB_GENERATED_ERRCODES "${_gpdb_errcodes}")
set(GPDB_GENERATED_KWLIST "${_gpdb_kwlist}")
set(GPDB_GENERATED_QSORT_TUPLE "${_gpdb_qsort_tuple}")
set(GPDB_GENERATED_LWLOCK_C "${_gpdb_lwlock_c}")
set(GPDB_GENERATED_LWLOCK_H "${_gpdb_lwlock_h}")
set(GPDB_GENERATED_PROBES "${_gpdb_probes}")
set(GPDB_GENERATED_SYSTEM_VIEWS_GP "${_gpdb_system_views_gp}")
set(GPDB_GENERATED_SNOWBALL_CREATE "${_gpdb_snowball_create}")

set(GPDB_LIBPQ_EXPORTS "${CMAKE_BINARY_DIR}/generated/libpq-exports.list")
set(GPDB_LIBPQ_VERSION_MAP "${CMAKE_BINARY_DIR}/generated/libpq-version.map")
add_custom_command(
  OUTPUT "${GPDB_LIBPQ_EXPORTS}" "${GPDB_LIBPQ_VERSION_MAP}"
  COMMAND ${CMAKE_COMMAND}
          -DGPDB_EXPORTS_SOURCE=${CMAKE_SOURCE_DIR}/src/interfaces/libpq/exports.txt
          -DGPDB_MAC_OUTPUT=${GPDB_LIBPQ_EXPORTS}
          -DGPDB_LINUX_OUTPUT=${GPDB_LIBPQ_VERSION_MAP}
          -P ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_libpq_exports.cmake
  DEPENDS "${CMAKE_SOURCE_DIR}/src/interfaces/libpq/exports.txt"
          ${CMAKE_SOURCE_DIR}/cmake/scripts/generate_libpq_exports.cmake
  VERBATIM)
add_custom_target(gpdb-libpq-exports
  DEPENDS "${GPDB_LIBPQ_EXPORTS}" "${GPDB_LIBPQ_VERSION_MAP}")
