cmake_minimum_required(VERSION 3.20)

project(PomeloDB VERSION 7.0.0 LANGUAGES C CXX)

include(GNUInstallDirs)
include(CTest)

list(APPEND CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
include(GPDBOptions)
include(GPDBDependencies)
include(GPDBGenerate)
include(GPDBNativeLibraries)
include(GPDBBackend)
include(GPDBClients)
include(GPDBGpfdist)

add_custom_target(gpdb ALL DEPENDS gpdb-server gpdb-clients)
if(TARGET gpfdist)
  add_dependencies(gpdb gpfdist)
endif()
add_dependencies(gpdb dict_snowball)
add_dependencies(gpdb plpgsql)
add_dependencies(gpdb gp_exttable_fdw)

install(TARGETS postgres pg_ctl psql pg_config initdb
  pg_archivecleanup pg_checksums pg_controldata pg_resetwal pg_test_fsync
  pg_test_timing pg_basebackup pg_receivewal pg_recvlogical pg_dump pg_restore
  pg_dumpall pg_rewind pg_waldump clusterdb createdb createuser dropdb dropuser
  pg_isready reindexdb vacuumdb libpq_shared
  RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}"
  LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}"
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")
if(TARGET gpfdist)
  install(TARGETS gpfdist RUNTIME DESTINATION "${CMAKE_INSTALL_BINDIR}")
endif()
install(TARGETS dict_snowball LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS plpgsql LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")
install(TARGETS gp_exttable_fdw LIBRARY DESTINATION "${CMAKE_INSTALL_LIBDIR}/postgresql")

install(TARGETS pgport pgport_shlib pgport_srv pgcommon pgcommon_shlib
  pgcommon_srv pgfeutils libpq
  ARCHIVE DESTINATION "${CMAKE_INSTALL_LIBDIR}")

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
  src/backend/catalog/cdb_schema.sql
  "${GPDB_GENERATED_SYSTEM_VIEWS_GP}"
  "${GPDB_GENERATED_SNOWBALL_CREATE}"
  DESTINATION "${GPDB_INSTALL_DATADIR}")
install(FILES gpcontrib/gp_toolkit/sql/gp_toolkit.sql
  DESTINATION "${GPDB_INSTALL_DATADIR}/cdb_init.d")

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
  src/backend/utils/misc/postgresql.conf.sample
  src/backend/libpq/pg_hba.conf.sample
  src/backend/libpq/pg_ident.conf.sample
  DESTINATION "${GPDB_INSTALL_DATADIR}")
install(DIRECTORY src/test/regress/
  DESTINATION "${GPDB_INSTALL_DATADIR}/regress"
  FILES_MATCHING PATTERN "*.sql" PATTERN "*.out" PATTERN "*.sh" PATTERN "*.pl")
install(DIRECTORY gpMgmt/bin/
  DESTINATION "${CMAKE_INSTALL_BINDIR}"
  FILES_MATCHING PATTERN "*"
  PATTERN "__pycache__" EXCLUDE)
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
  DESTINATION "${CMAKE_INSTALL_PREFIX}")

file(WRITE "${CMAKE_CURRENT_BINARY_DIR}/greenplum_path.sh"
  "#!/bin/sh\n"
  "GPHOME=\"${CMAKE_INSTALL_PREFIX}\"\n"
  "PATH=\"$GPHOME/bin:$GPHOME/sbin:$PATH\"\n"
  "LD_LIBRARY_PATH=\"$GPHOME/lib:$GPHOME/lib/postgresql:$LD_LIBRARY_PATH\"\n"
  "DYLD_LIBRARY_PATH=\"$GPHOME/lib:$GPHOME/lib/postgresql:$DYLD_LIBRARY_PATH\"\n"
  "export GPHOME PATH LD_LIBRARY_PATH DYLD_LIBRARY_PATH\n")
install(PROGRAMS "${CMAKE_CURRENT_BINARY_DIR}/greenplum_path.sh"
  DESTINATION "${CMAKE_INSTALL_PREFIX}")

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
