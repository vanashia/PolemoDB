cmake_minimum_required(VERSION 3.20)

project(PomeloDB VERSION 7.0.0 LANGUAGES C CXX)

include(GNUInstallDirs)
include(CTest)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(GPDBOptions)

if(GPDB_ENABLE_RPATH)
  if(APPLE)
    set(CMAKE_BUILD_RPATH "${CMAKE_INSTALL_FULL_LIBDIR}")
    set(CMAKE_INSTALL_RPATH "${CMAKE_INSTALL_FULL_LIBDIR}")
  elseif(UNIX)
    set(CMAKE_BUILD_RPATH "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
    set(CMAKE_INSTALL_RPATH "\$ORIGIN/../${CMAKE_INSTALL_LIBDIR}")
  endif()
endif()

include(GPDBDependencies)
include(GPDBGenerate)
include(GPDBNativeLibraries)
include(GPDBBackend)
include(GPDBClients)
include(GPDBGpfdist)
include(GPDBTests)
include(GPDBSourceTests)

# gpMgmt uses this helper while creating the production MPP array. Build it
# natively and install it under libexec, which is where gpcreateseg.sh and
# gp_bash_functions.sh look for ${GPHOME}/libexec/ifaddrs.
add_executable(gpdb-ifaddrs gpMgmt/bin/ifaddrs/main.c)
gpdb_apply_common_options(gpdb-ifaddrs)
set_target_properties(gpdb-ifaddrs PROPERTIES OUTPUT_NAME ifaddrs)

add_custom_target(gpdb ALL DEPENDS gpdb-server gpdb-clients)
add_dependencies(gpdb gpdb-ifaddrs)
add_dependencies(gpdb gpdb-guc-metadata)
add_dependencies(gpdb-source-test-tools gpdb)
if(TARGET gpfdist)
  add_dependencies(gpdb gpfdist)
endif()
add_dependencies(gpdb dict_snowball)
add_dependencies(gpdb plpgsql)
add_dependencies(gpdb gp_exttable_fdw)
add_dependencies(gpdb gp_toolkit)
add_dependencies(gpdb gp_ao_co_diagnostics gp_workfile_mgr
  gp_session_state_memory_stats gp_instrument_shmem)
add_dependencies(gpdb pageinspect gp_inject_fault gp_debug_numsegments)
add_dependencies(gpdb ${GPDB_CONVERSION_TARGETS} ${GPDB_SOURCE_EXTENSION_TARGETS})
if(TARGET gp_zstd_compression)
  add_dependencies(gpdb gp_zstd_compression)
endif()

install(TARGETS postgres pg_ctl psql pg_config initdb
  pg_archivecleanup pg_checksums pg_controldata pg_resetwal pg_test_fsync
  pg_test_timing pg_basebackup pg_receivewal pg_recvlogical pg_dump pg_restore
  pg_dumpall pg_rewind pg_waldump clusterdb createdb createuser dropdb dropuser
  pg_isready reindexdb vacuumdb pgbench libpq_shared
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
if(TARGET gpfdist)
  install(TARGETS gpfdist RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()
install(TARGETS gpdb-ifaddrs RUNTIME DESTINATION "${CMAKE_INSTALL_LIBEXECDIR}")
install(TARGETS dict_snowball LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS plpgsql LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS gp_exttable_fdw LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS gp_toolkit LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS gp_ao_co_diagnostics gp_workfile_mgr gp_session_state_memory_stats
  gp_instrument_shmem LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS pageinspect gp_inject_fault gp_debug_numsegments
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS ${GPDB_CONVERSION_TARGETS} ${GPDB_SOURCE_EXTENSION_TARGETS}
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
if(TARGET gp_zstd_compression)
  install(TARGETS gp_zstd_compression
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
endif()

install(TARGETS pgport pgport_shlib pgport_srv pgcommon pgcommon_shlib
  pgcommon_srv pgfeutils libpq
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
install(TARGETS pg_regress extended_protocol_resqueue twophase_pqexecparams
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(TARGETS regress autoinc refint test_hook query_info_hook_test
  LIBRARY DESTINATION "${GPDB_INSTALL_DATADIR}/regress")
if(TARGET gpos)
  install(TARGETS gpos gpopt naucrates gpdbcost
    RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
    LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
    ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
endif()

# PostgreSQL derives its loadable-module directory from the location of the
# postgres executable and verifies it during every startup, including initdb's
# bootstrap probes.  Keep the directory present even when no optional modules
# are enabled yet.
install(DIRECTORY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(DIRECTORY "${GPDB_GENERATED_TIMEZONE_DIR}/"
  DESTINATION "${GPDB_INSTALL_DATADIR}/timezone"
  FILES_MATCHING PATTERN "*"
  PATTERN ".stamp" EXCLUDE)

install(DIRECTORY src/include/
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/postgresql"
  FILES_MATCHING PATTERN "*.h"
  PATTERN "*.in" EXCLUDE)
install(DIRECTORY "${GPDB_GENERATED_INCLUDE_DIR}/"
  DESTINATION "${CMAKE_INSTALL_INCLUDEDIR}/postgresql"
  FILES_MATCHING PATTERN "*.h")
install(FILES
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/postgres.bki"
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/postgres.description"
  "${GPDB_GENERATED_INCLUDE_DIR}/catalog/postgres.shdescription"
  DESTINATION "${GPDB_INSTALL_DATADIR}")
install(FILES
  src/backend/catalog/system_views.sql
  src/backend/catalog/system_views_gp_summary.sql
  src/backend/catalog/information_schema.sql
  src/backend/catalog/sql_features.txt
  "${GPDB_GENERATED_SYSTEM_VIEWS_GP}"
  "${GPDB_GENERATED_SNOWBALL_CREATE}"
  DESTINATION "${GPDB_INSTALL_DATADIR}")
install(FILES src/backend/catalog/cdb_schema.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/cdb_init.d")
install(FILES gpcontrib/gp_toolkit/sql/gp_toolkit.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/cdb_init.d")
if(GPDB_WITH_ZSTD)
  install(FILES gpcontrib/zstd/zstd_compression.sql
    DESTINATION "${GPDB_INSTALL_DATADIR}/cdb_init.d")
endif()

install(DIRECTORY src/timezone/tznames/
  DESTINATION "${GPDB_INSTALL_DATADIR}/timezonesets"
  FILES_MATCHING
  PATTERN "*.txt"
  PATTERN "Default"
  PATTERN "Australia"
  PATTERN "India")
install(DIRECTORY src/backend/tsearch/dicts/
  DESTINATION "${GPDB_INSTALL_DATADIR}/tsearch_data"
  FILES_MATCHING PATTERN "*.affix" PATTERN "*.dict" PATTERN "*.syn" PATTERN "*.ths")
install(DIRECTORY src/backend/snowball/stopwords/
  DESTINATION "${GPDB_INSTALL_DATADIR}/tsearch_data"
  FILES_MATCHING PATTERN "*.stop")
install(FILES
  src/pl/plpgsql/src/plpgsql.control
  src/pl/plpgsql/src/plpgsql--1.0.sql
  src/pl/plpgsql/src/plpgsql--unpackaged--1.0.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
install(FILES
  gpcontrib/gp_exttable_fdw/gp_exttable_fdw.control
  gpcontrib/gp_exttable_fdw/gp_exttable_fdw--1.0.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
install(FILES
  gpcontrib/gp_toolkit/gp_toolkit.control
  gpcontrib/gp_toolkit/gp_toolkit--1.0.sql
  gpcontrib/gp_toolkit/gp_toolkit--1.0--1.1.sql
  gpcontrib/gp_toolkit/gp_toolkit--1.1--1.2.sql
  gpcontrib/gp_toolkit/gp_toolkit--1.2--1.3.sql
  gpcontrib/gp_toolkit/gp_toolkit--1.3.sql
  gpcontrib/gp_toolkit/gp_toolkit--1.3--1.4.sql
  gpcontrib/gp_toolkit/gp_toolkit--1.4--1.5.sql
  gpcontrib/gp_toolkit/gp_toolkit--1.5--1.6.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
install(FILES
  gpcontrib/gp_internal_tools/gp_internal_tools.control
  gpcontrib/gp_internal_tools/gp_internal_tools--1.0.0.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
install(FILES
  contrib/pageinspect/pageinspect.control
  contrib/pageinspect/pageinspect--1.0--1.1.sql
  contrib/pageinspect/pageinspect--1.1--1.2.sql
  contrib/pageinspect/pageinspect--1.2--1.3.sql
  contrib/pageinspect/pageinspect--1.3--1.4.sql
  contrib/pageinspect/pageinspect--1.4--1.5.sql
  contrib/pageinspect/pageinspect--1.5.sql
  contrib/pageinspect/pageinspect--1.5--1.6.sql
  contrib/pageinspect/pageinspect--1.6--1.7.sql
  contrib/pageinspect/pageinspect--1.7--1.8.sql
  contrib/pageinspect/pageinspect--1.8--1.9.sql
  contrib/pageinspect/pageinspect--unpackaged--1.0.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
install(FILES
  gpcontrib/gp_inject_fault/gp_inject_fault.control
  gpcontrib/gp_inject_fault/gp_inject_fault--1.0.sql
  gpcontrib/gp_debug_numsegments/gp_debug_numsegments.control
  gpcontrib/gp_debug_numsegments/gp_debug_numsegments--1.0.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
foreach(_source_extension IN ITEMS btree_gin pg_stat_statements sslinfo)
  if(EXISTS "${CMAKE_SOURCE_DIR}/contrib/${_source_extension}/${_source_extension}.control")
    file(GLOB _source_extension_files
      "${CMAKE_SOURCE_DIR}/contrib/${_source_extension}/${_source_extension}.control"
      "${CMAKE_SOURCE_DIR}/contrib/${_source_extension}/${_source_extension}--*.sql")
    install(FILES ${_source_extension_files}
      DESTINATION "${GPDB_INSTALL_DATADIR}/extension")
  endif()
endforeach()

install(FILES
  src/backend/utils/misc/postgresql.conf.sample
  src/backend/libpq/pg_hba.conf.sample
  src/backend/libpq/pg_ident.conf.sample
  DESTINATION "${GPDB_INSTALL_DATADIR}")
install(DIRECTORY src/test/regress/
  DESTINATION "${GPDB_INSTALL_DATADIR}/regress"
  USE_SOURCE_PERMISSIONS
  FILES_MATCHING
  PATTERN "*.sql"
  PATTERN "*.out"
  PATTERN "*.sh"
  PATTERN "*.pl"
  PATTERN "*.pm"
  PATTERN "*.source"
  PATTERN "*_schedule"
  PATTERN "resultmap"
  PATTERN "init_file"
  PATTERN "test_dbconn.py")
install(DIRECTORY "${GPDB_REGRESS_BUILD_DIR}/"
  DESTINATION "${GPDB_INSTALL_DATADIR}/regress"
  USE_SOURCE_PERMISSIONS
  FILES_MATCHING
  PATTERN "*.pl"
  PATTERN "*.pm"
  PATTERN "*.sh"
  PATTERN "pg_regress"
  PATTERN "*.so")
install(PROGRAMS
  "${GPDB_REGRESS_BUILD_DIR}/gpdiff.pl"
  "${GPDB_REGRESS_BUILD_DIR}/gpstringsubs.pl"
  "${GPDB_REGRESS_BUILD_DIR}/atmsort.pl"
  "${GPDB_REGRESS_BUILD_DIR}/explain.pl"
  "${GPDB_REGRESS_BUILD_DIR}/scan_flaky_fault_injectors.sh"
  DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(FILES
  "${GPDB_REGRESS_BUILD_DIR}/atmsort.pm"
  "${GPDB_REGRESS_BUILD_DIR}/explain.pm"
  "${GPDB_REGRESS_BUILD_DIR}/GPTest.pm"
  DESTINATION "${CMAKE_INSTALL_BINDIR}")
install(DIRECTORY gpMgmt/bin/
  DESTINATION "${CMAKE_INSTALL_BINDIR}"
  USE_SOURCE_PERMISSIONS
  FILES_MATCHING PATTERN "*"
  PATTERN "gp_bash_version.sh.in" EXCLUDE
  PATTERN "__pycache__" EXCLUDE
  PATTERN "ifaddrs" EXCLUDE
  PATTERN "gppylib" EXCLUDE)
install(DIRECTORY gpMgmt/bin/gppylib/
  DESTINATION "${CMAKE_INSTALL_LIBDIR}/python/gppylib"
  USE_SOURCE_PERMISSIONS
  FILES_MATCHING
  PATTERN "*.py"
  PATTERN "*.json"
  PATTERN "gpunit"
  PATTERN "unit2"
  PATTERN "__pycache__" EXCLUDE)
install(PROGRAMS
  gpMgmt/sbin/gpconfig_helper.py
  gpMgmt/sbin/gpoperation.py
  gpMgmt/sbin/gpsegstop.py
  gpMgmt/sbin/gpcleansegmentdir.py
  gpMgmt/sbin/gpgetstatususingtransition.py
  gpMgmt/sbin/gpsegstart.py
  gpMgmt/sbin/seg_update_pg_hba.py
  gpMgmt/sbin/gpsegrecovery.py
  gpMgmt/sbin/gpsegsetuprecovery.py
  gpMgmt/sbin/recovery_base.py
  gpMgmt/sbin/packcore
  DESTINATION "${CMAKE_INSTALL_SBINDIR}")
configure_file(
  "${CMAKE_SOURCE_DIR}/gpMgmt/bin/lib/gp_bash_version.sh.in"
  "${CMAKE_CURRENT_BINARY_DIR}/gp_bash_version.sh"
  @ONLY)
install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/gp_bash_version.sh"
  DESTINATION "${CMAKE_INSTALL_BINDIR}/lib")
install(FILES
  gpMgmt/bin/pomelodb
  gpMgmt/bin/gpstart
  gpMgmt/bin/gpstop
  gpMgmt/bin/gpinitsystem
  DESTINATION "${CMAKE_INSTALL_BINDIR}"
  PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE
              GROUP_READ GROUP_EXECUTE
              WORLD_READ WORLD_EXECUTE)
install(FILES gpMgmt/bin/pomelodb.conf
  DESTINATION ".")

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/greenplum_path.sh"
  "#!/bin/sh\n"
  "GPHOME=\"${CMAKE_INSTALL_PREFIX}\"\n"
  "PATH=\"$GPHOME/bin:$GPHOME/sbin:$PATH\"\n"
  "PYTHONPATH=\"$GPHOME/lib/python:\${PYTHONPATH:-}\"\n"
  "LD_LIBRARY_PATH=\"$GPHOME/lib:$GPHOME/lib/postgresql:\${LD_LIBRARY_PATH:-}\"\n"
  "DYLD_LIBRARY_PATH=\"$GPHOME/lib:$GPHOME/lib/postgresql:\${DYLD_LIBRARY_PATH:-}\"\n"
  "export GPHOME PATH PYTHONPATH LD_LIBRARY_PATH DYLD_LIBRARY_PATH\n")
install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/greenplum_path.sh"
  DESTINATION ".")

add_test(NAME gpdb-cmake-interface
  COMMAND ${CMAKE_COMMAND} -DGPDB_SOURCE_DIR=${CMAKE_SOURCE_DIR}
          -P ${CMAKE_SOURCE_DIR}/cmake/tests/validate_native_interface.cmake)
add_test(NAME gpdb-native-targets
  COMMAND ${CMAKE_COMMAND} -DGPDB_BINARY_DIR=${CMAKE_BINARY_DIR}
          -P ${CMAKE_SOURCE_DIR}/cmake/tests/validate_native_targets.cmake)

message(STATUS "PomeloDB native CMake build configured")
message(STATUS "  prefix: ${CMAKE_INSTALL_PREFIX}")
message(STATUS "  generator: ${CMAKE_GENERATOR}")
message(STATUS "  compiler: ${CMAKE_C_COMPILER}")
