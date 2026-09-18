cmake_minimum_required(VERSION 3.20)

project(gpdb LANGUAGES NONE)

# Keep the historical configure default unless the caller explicitly selected
# a CMake installation prefix.
if(CMAKE_INSTALL_PREFIX_INITIALIZED_TO_DEFAULT)
  set(CMAKE_INSTALL_PREFIX "/usr/local/pomelodb" CACHE PATH
      "Install path prefix, prepended onto install directories." FORCE)
endif()

# GPDB historically uses configure + GNU Make.  This top-level project keeps
# that interface intact while exposing every configure switch through a
# CMake cache and making CMake's selected generator (including Ninja) the
# public build entry point.

include(CTest)
include(CMakeParseArguments)

set(GPDB_EXTRA_VERSION "" CACHE STRING "Append a string to the GPDB version")
set(GPDB_EXEC_PREFIX "" CACHE PATH "configure --exec-prefix value")
set(GPDB_TEMPLATE "" CACHE STRING "configure --with-template value")
set(GPDB_INCLUDES "" CACHE PATH "Additional include directories")
set(GPDB_LIBRARIES "" CACHE PATH "Additional library directories")
set(GPDB_LIBS_DIR "" CACHE PATH "Additional library directories (configure --with-libs alias)")
set(GPDB_PGPORT "5432" CACHE STRING "Default PostgreSQL port")
set(GPDB_BLOCKSIZE "32" CACHE STRING "Table block size in kB")
set(GPDB_SEGSIZE "1" CACHE STRING "Table segment size in GB")
set(GPDB_WAL_BLOCKSIZE "32" CACHE STRING "WAL block size in kB")
set(GPDB_CC "" CACHE STRING "C compiler command (configure compatibility)")
set(GPDB_TCLCONFIG "" CACHE PATH "Directory containing tclConfig.sh")
set(GPDB_KRB_SRVNAM "postgres" CACHE STRING "Kerberos service principal")
set(GPDB_UUID "" CACHE STRING "uuid-ossp provider: bsd, e2fs, or ossp")
set(GPDB_SYSTEM_TZDATA "" CACHE PATH "System timezone data directory")
set(GPDB_APR_CONFIG "" CACHE FILEPATH "Path to apr-1-config")
set(GPDB_LDFLAGS_EX "" CACHE STRING "Extra executable linker flags")
set(GPDB_LDFLAGS_SL "" CACHE STRING "Extra shared-library linker flags")
set(GPDB_CFLAGS "" CACHE STRING "Additional C compiler flags for configure")
set(GPDB_CXXFLAGS "" CACHE STRING "Additional C++ compiler flags for configure")
set(GPDB_LDFLAGS "" CACHE STRING "Additional linker flags for configure")
set(GPDB_CPPFLAGS "" CACHE STRING "Preprocessor flags for configure")
set(GPDB_LIBS "" CACHE STRING "Additional libraries for configure")
set(GPDB_BUILD "" CACHE STRING "configure --build triplet")
set(GPDB_HOST "" CACHE STRING "configure --host triplet")
option(GPDB_DISABLE_OPTION_CHECKING "Pass --disable-option-checking to configure" OFF)
option(GPDB_ENABLE_INTEGER_DATETIMES "Accept the obsolete integer-datetimes switch" ON)
option(GPDB_ENABLE_LARGEFILE "Build with large-file support" ON)

set(_gpdb_default_on_options RPATH SPINLOCKS ATOMICS STRONG_RANDOM GPFDIST DEBUG_EXTENSIONS ORCA THREAD_SAFETY)
set(GPDB_SUPPORTED_ENABLE_OPTIONS
    RPATH SPINLOCKS ATOMICS STRONG_RANDOM GPFDIST DEBUG_EXTENSIONS ORAFCE DEBUG
    PROFILING COVERAGE DTRACE TAP_TESTS DEPEND CASSERT ORCA GPCLOUD IC_PROXY
    THREAD_SAFETY INTEGER_DATETIMES LARGEFILE CACHE INTERNAL "Supported configure --enable options")
foreach(_option IN ITEMS
    RPATH SPINLOCKS ATOMICS STRONG_RANDOM GPFDIST DEBUG_EXTENSIONS ORAFCE DEBUG
    PROFILING COVERAGE DTRACE TAP_TESTS DEPEND CASSERT ORCA GPCLOUD IC_PROXY
    THREAD_SAFETY)
  set(_default OFF)
  if(_option IN_LIST _gpdb_default_on_options)
    set(_default ON)
  endif()
  option(GPDB_ENABLE_${_option} "Enable configure feature ${_option}" ${_default})
endforeach()

# These defaults mirror configure.in, rather than CMake's usual defaults.
option(GPDB_WITH_LLVM "Build LLVM JIT support" OFF)
option(GPDB_WITH_ICU "Build ICU support" OFF)
option(GPDB_WITH_TCL "Build PL/Tcl" OFF)
option(GPDB_WITH_PERL "Build PL/Perl" OFF)
option(GPDB_WITH_PYTHON "Build PL/Python" ON)
option(GPDB_WITH_GSSAPI "Build GSSAPI support" OFF)
option(GPDB_WITH_PAM "Build PAM support" OFF)
option(GPDB_WITH_BSD_AUTH "Build BSD authentication support" OFF)
option(GPDB_WITH_LDAP "Build LDAP support" OFF)
option(GPDB_WITH_BONJOUR "Build Bonjour support" OFF)
option(GPDB_WITH_OPENSSL "Build OpenSSL support" OFF)
option(GPDB_WITH_SELINUX "Build SELinux support" OFF)
option(GPDB_WITH_SYSTEMD "Build systemd support" OFF)
option(GPDB_WITH_READLINE "Build readline/libedit support" ON)
option(GPDB_WITH_LIBEDIT_PREFERRED "Prefer libedit over readline" OFF)
option(GPDB_WITH_LIBXML "Build XML support" OFF)
option(GPDB_WITH_LIBXSLT "Build XSLT support" OFF)
option(GPDB_WITH_ZLIB "Build zlib support" ON)
option(GPDB_WITH_LIBBZ2 "Build bzip2 support" ON)
option(GPDB_WITH_ZSTD "Build Zstandard support" ON)
option(GPDB_WITH_RT "Build realtime library support" ON)
option(GPDB_WITH_LIBCURL "Build libcurl support" ON)
option(GPDB_WITH_OSSP_UUID "Use the obsolete OSSP UUID spelling" OFF)
option(GPDB_WITH_GNU_LD "Assume the linker is GNU ld" OFF)
set(GPDB_SUPPORTED_WITH_OPTIONS
    LLVM ICU TCL PERL PYTHON GSSAPI PAM BSD_AUTH LDAP BONJOUR OPENSSL SELINUX SYSTEMD
    READLINE LIBEDIT_PREFERRED LIBXML LIBXSLT ZLIB LIBBZ2 ZSTD RT LIBCURL
    OSSP_UUID GNU_LD CACHE INTERNAL "Supported configure --with options")

set(GPDB_CONFIGURE_EXTRA_ARGS "" CACHE STRING
    "Additional configure arguments (semicolon-separated CMake list)")
set(GPDB_CONFIGURE_ENV "" CACHE STRING
    "Additional configure environment entries (semicolon-separated NAME=VALUE list)")
option(GPDB_SKIP_CONFIGURE "Only validate the CMake interface; do not run configure" OFF)
option(GPDB_ENABLE_NATIVE_TARGETS "Build native CMake library targets" ON)
option(GPDB_BUILD_NATIVE_TARGETS_WITH_GPDB
       "Make the full gpdb target also build the optional native frontend subset" OFF)
option(POMELODB_WITH_DUCKDB
       "Build the embedded DuckDB executor and SQL entry point" ON)

if(GPDB_ENABLE_NATIVE_TARGETS)
  enable_language(C CXX)
endif()

find_program(GPDB_MAKE_PROGRAM NAMES gmake make REQUIRED)
if(GPDB_ENABLE_NATIVE_TARGETS)
  find_package(Threads REQUIRED)
  find_library(GPDB_M_LIBRARY NAMES m)
  find_package(ZLIB QUIET)
  find_package(BZip2 QUIET)
  find_package(OpenSSL QUIET)
  if(GPDB_WITH_ZSTD)
    find_library(GPDB_ZSTD_LIBRARY NAMES zstd REQUIRED)
  endif()
  find_package(LibXml2 QUIET)
  find_package(CURL QUIET)
  find_package(ICU COMPONENTS uc i18n QUIET)
  find_package(Perl QUIET)
  if(GPDB_WITH_READLINE)
    find_path(GPDB_READLINE_INCLUDE_DIR NAMES readline/readline.h)
    find_library(GPDB_READLINE_LIBRARY NAMES readline)
  endif()
  if(GPDB_WITH_GSSAPI)
    if(APPLE)
      # GSS.framework does not export the Kerberos OID globals used by
      # libpq on current Apple SDKs.  They are provided by the SDK's
      # libgssapi_krb5 stub library instead.
      if(GPDB_GSS_LIBRARY MATCHES "GSS\\.framework$")
        unset(GPDB_GSS_LIBRARY CACHE)
      endif()
      find_library(GPDB_GSS_LIBRARY NAMES gssapi_krb5 REQUIRED)
    else()
      find_library(GPDB_GSS_LIBRARY NAMES gssapi_krb5 gssapi REQUIRED)
    endif()
  endif()
  find_program(GPDB_FLEX_EXECUTABLE flex)
  find_package(PkgConfig QUIET)
  if(PkgConfig_FOUND AND GPDB_WITH_ZSTD)
    pkg_check_modules(ZSTD libzstd>=1.4.0)
  endif()
endif()
set(GPDB_SYSTEM_LIBRARIES
    Threads::Threads m ZLIB::ZLIB BZip2::BZip2 OpenSSL::SSL OpenSSL::Crypto
    LibXml2::LibXml2 CURL::libcurl ICU::uc ICU::i18n
    CACHE INTERNAL "Libraries consumed by the GPDB build")

file(REAL_PATH "${CMAKE_SOURCE_DIR}" _gpdb_source_dir)
file(REAL_PATH "${CMAKE_BINARY_DIR}" _gpdb_binary_dir)
file(RELATIVE_PATH _gpdb_binary_relative "${_gpdb_source_dir}" "${_gpdb_binary_dir}")
if(_gpdb_binary_relative MATCHES "^\\.\\.")
  set(_gpdb_legacy_build_default "${CMAKE_BINARY_DIR}/legacy")
else()
  # configure's prep_buildtree scans every source subdirectory.  A legacy
  # build tree inside the source tree would therefore scan and recreate itself
  # recursively.  Keep it next to the source tree for common `-B build-ninja`
  # invocations instead.
  get_filename_component(_gpdb_binary_name "${CMAKE_BINARY_DIR}" NAME)
  set(_gpdb_legacy_build_default
      "${CMAKE_SOURCE_DIR}/../.${PROJECT_NAME}-legacy-${_gpdb_binary_name}")
endif()
if(DEFINED GPDB_LEGACY_BUILD_DIR AND
   "${GPDB_LEGACY_BUILD_DIR}" STREQUAL "${CMAKE_BINARY_DIR}/legacy")
  # Migrate the original unsafe default from an existing CMake cache.
  set(GPDB_LEGACY_BUILD_DIR "${_gpdb_legacy_build_default}" CACHE PATH
      "Directory used for configure-generated files" FORCE)
else()
  set(GPDB_LEGACY_BUILD_DIR "${_gpdb_legacy_build_default}" CACHE PATH
      "Directory used for configure-generated files")
endif()
get_filename_component(_gpdb_legacy_build_absolute "${GPDB_LEGACY_BUILD_DIR}"
                       ABSOLUTE BASE_DIR "${CMAKE_BINARY_DIR}")
file(RELATIVE_PATH _gpdb_legacy_relative "${_gpdb_source_dir}"
                   "${_gpdb_legacy_build_absolute}")
if(NOT _gpdb_legacy_relative MATCHES "^\\.\\.")
  message(FATAL_ERROR "GPDB_LEGACY_BUILD_DIR must be outside the source tree: ${_gpdb_legacy_build_absolute}")
endif()
file(MAKE_DIRECTORY "${GPDB_LEGACY_BUILD_DIR}")

# configure invokes ./getversion from its working directory.  Create a wrapper
# before the first external VPATH configure, so getversion itself runs from the
# source root and the configured GP version (and GP_MAJORVERSION) is not empty.
set(_gpdb_getversion_source "${CMAKE_SOURCE_DIR}/getversion")
set(_gpdb_getversion_destination "${GPDB_LEGACY_BUILD_DIR}/getversion")
if(NOT EXISTS "${_gpdb_getversion_source}")
  message(FATAL_ERROR "missing getversion helper: ${_gpdb_getversion_source}")
endif()
if(IS_SYMLINK "${_gpdb_getversion_destination}")
  file(REMOVE "${_gpdb_getversion_destination}")
endif()
file(WRITE "${_gpdb_getversion_destination}"
     "#!/usr/bin/env bash\nexec \"${_gpdb_getversion_source}\" \"\\$@\"\n")
file(CHMOD "${_gpdb_getversion_destination}"
     PERMISSIONS OWNER_READ OWNER_WRITE OWNER_EXECUTE GROUP_READ GROUP_EXECUTE
                 WORLD_READ WORLD_EXECUTE)

if(GPDB_ENABLE_NATIVE_TARGETS)
  if(NOT "${GPDB_CPPFLAGS}" STREQUAL "")
    separate_arguments(_gpdb_native_cppflags UNIX_COMMAND "${GPDB_CPPFLAGS}")
    add_compile_options(${_gpdb_native_cppflags})
  endif()
  if(NOT "${GPDB_LIBS}" STREQUAL "")
    separate_arguments(_gpdb_native_libs UNIX_COMMAND "${GPDB_LIBS}")
    add_link_options(${_gpdb_native_libs})
  endif()
  if(NOT "${GPDB_INCLUDES}" STREQUAL "")
    separate_arguments(_gpdb_native_includes UNIX_COMMAND "${GPDB_INCLUDES}")
    include_directories(${_gpdb_native_includes})
  endif()
  if(NOT "${GPDB_LIBRARIES}" STREQUAL "")
    separate_arguments(_gpdb_native_library_dirs UNIX_COMMAND "${GPDB_LIBRARIES}")
    link_directories(${_gpdb_native_library_dirs})
  endif()
  include("${CMAKE_SOURCE_DIR}/cmake/GPDBNativeLibraries.cmake")
  if(POMELODB_WITH_DUCKDB)
    include("${CMAKE_SOURCE_DIR}/cmake/PomeloDuckDB.cmake")
  endif()
endif()

set(_configure_args "--prefix=${CMAKE_INSTALL_PREFIX}")
if(NOT "${GPDB_EXEC_PREFIX}" STREQUAL "")
  list(APPEND _configure_args "--exec-prefix=${GPDB_EXEC_PREFIX}")
endif()
foreach(_dir IN ITEMS BINDIR SBINDIR LIBEXECDIR SYSCONFDIR SHAREDSTATEDIR
    LOCALSTATEDIR LIBDIR INCLUDEDIR OLDINCLUDEDIR DATAROOTDIR DATADIR INFODIR
    LOCALEDIR MANDIR DOCDIR HTMLDIR DVIDIR PDFDIR PSDIR)
  if(DEFINED CMAKE_INSTALL_${_dir} AND NOT "${CMAKE_INSTALL_${_dir}}" STREQUAL "")
    string(TOLOWER "${_dir}" _configure_dir)
    set(_configure_value "${CMAKE_INSTALL_${_dir}}")
    if(NOT IS_ABSOLUTE "${_configure_value}")
      get_filename_component(_configure_value "${_configure_value}" ABSOLUTE
                             BASE_DIR "${CMAKE_INSTALL_PREFIX}")
    endif()
    list(APPEND _configure_args "--${_configure_dir}=${_configure_value}")
  endif()
endforeach()
if(NOT "${GPDB_BUILD}" STREQUAL "")
  list(APPEND _configure_args "--build=${GPDB_BUILD}")
endif()
if(NOT "${GPDB_HOST}" STREQUAL "")
  list(APPEND _configure_args "--host=${GPDB_HOST}")
endif()
function(_gpdb_bool_arg _prefix _name _configure_name _mode)
  if(${_prefix}_${_name})
    list(APPEND _configure_args "--${_mode}-${_configure_name}")
  else()
    list(APPEND _configure_args "--disable-${_configure_name}")
  endif()
  set(_configure_args "${_configure_args}" PARENT_SCOPE)
endfunction()

foreach(_pair IN ITEMS
    "RPATH;rpath" "SPINLOCKS;spinlocks" "ATOMICS;atomics"
    "STRONG_RANDOM;strong-random" "GPFDIST;gpfdist"
    "DEBUG_EXTENSIONS;debug-extensions" "ORAFCE;orafce" "DEBUG;debug"
    "PROFILING;profiling" "COVERAGE;coverage" "DTRACE;dtrace"
    "TAP_TESTS;tap-tests" "DEPEND;depend" "CASSERT;cassert"
    "ORCA;orca" "GPCLOUD;gpcloud" "IC_PROXY;ic-proxy"
    "THREAD_SAFETY;thread-safety")
  list(GET _pair 0 _option)
  list(GET _pair 1 _configure_name)
  _gpdb_bool_arg(GPDB_ENABLE ${_option} ${_configure_name} enable)
endforeach()
foreach(_pair IN ITEMS
    "LLVM;llvm" "ICU;icu" "TCL;tcl" "PERL;perl" "PYTHON;python"
    "GSSAPI;gssapi" "PAM;pam" "BSD_AUTH;bsd-auth" "LDAP;ldap" "BONJOUR;bonjour"
    "OPENSSL;openssl" "SELINUX;selinux" "SYSTEMD;systemd"
    "READLINE;readline" "LIBEDIT_PREFERRED;libedit-preferred"
    "LIBXML;libxml" "LIBXSLT;libxslt" "ZLIB;zlib" "LIBBZ2;libbz2"
    "ZSTD;zstd" "RT;rt" "LIBCURL;libcurl")
  list(GET _pair 0 _option)
  list(GET _pair 1 _configure_name)
  if(GPDB_WITH_${_option})
    list(APPEND _configure_args "--with-${_configure_name}")
  else()
    list(APPEND _configure_args "--without-${_configure_name}")
  endif()
endforeach()

foreach(_pair IN ITEMS
    "GPDB_EXTRA_VERSION;extra-version" "GPDB_TEMPLATE;template"
    "GPDB_INCLUDES;includes" "GPDB_LIBRARIES;libraries" "GPDB_PGPORT;pgport"
    "GPDB_BLOCKSIZE;blocksize" "GPDB_SEGSIZE;segsize"
    "GPDB_WAL_BLOCKSIZE;wal-blocksize" "GPDB_TCLCONFIG;tclconfig"
    "GPDB_KRB_SRVNAM;krb-srvnam" "GPDB_SYSTEM_TZDATA;system-tzdata"
    "GPDB_APR_CONFIG;apr-config")
  list(GET _pair 0 _var)
  list(GET _pair 1 _name)
  if(NOT "${${_var}}" STREQUAL "")
    set(_configure_value "${${_var}}")
    # CMake represents a list of include/library directories with semicolons,
    # while configure consumes the platform PATH_SEPARATOR (':' on Unix).
    if(_var STREQUAL "GPDB_INCLUDES" OR _var STREQUAL "GPDB_LIBRARIES")
      if(WIN32)
        set(_gpdb_configure_path_separator ";")
      else()
        set(_gpdb_configure_path_separator ":")
      endif()
      string(REPLACE ";" "${_gpdb_configure_path_separator}"
             _configure_value "${_configure_value}")
    endif()
    list(APPEND _configure_args "--with-${_name}=${_configure_value}")
  endif()
endforeach()
if(NOT GPDB_ENABLE_INTEGER_DATETIMES)
  list(APPEND _configure_args "--disable-integer-datetimes")
endif()
if(NOT GPDB_ENABLE_LARGEFILE)
  list(APPEND _configure_args "--disable-largefile")
endif()
if(GPDB_WITH_OSSP_UUID)
  list(APPEND _configure_args "--with-ossp-uuid")
endif()
if(GPDB_WITH_GNU_LD)
  list(APPEND _configure_args "--with-gnu-ld")
endif()
if(NOT "${GPDB_UUID}" STREQUAL "")
  list(APPEND _configure_args "--with-uuid=${GPDB_UUID}")
endif()
if(NOT "${GPDB_LIBS_DIR}" STREQUAL "")
  if(WIN32)
    set(_gpdb_configure_path_separator ";")
  else()
    set(_gpdb_configure_path_separator ":")
  endif()
  string(REPLACE ";" "${_gpdb_configure_path_separator}"
         _gpdb_libs_dir "${GPDB_LIBS_DIR}")
  list(APPEND _configure_args "--with-libs=${_gpdb_libs_dir}")
endif()
if(NOT "${GPDB_CC}" STREQUAL "")
  list(APPEND _configure_args "--with-CC=${GPDB_CC}")
endif()
list(APPEND _configure_args ${GPDB_CONFIGURE_EXTRA_ARGS})
if(GPDB_DISABLE_OPTION_CHECKING)
  list(APPEND _configure_args "--disable-option-checking")
endif()
set(GPDB_CONFIGURE_ARGS "${_configure_args}" CACHE INTERNAL
    "Effective configure arguments generated from CMake options")

set(_configure_env)
foreach(_env_name IN ITEMS
    LLVM_CONFIG CLANG CPP PKG_CONFIG PKG_CONFIG_PATH PKG_CONFIG_LIBDIR ICU_CFLAGS ICU_LIBS XML2_CONFIG
    XML2_CFLAGS XML2_LIBS ZSTD_CFLAGS ZSTD_LIBS PERL PYTHON MSGFMT TCLSH)
  set(_cache_name "GPDB_${_env_name}")
  set(${_cache_name} "" CACHE STRING "${_env_name} passed to configure")
  if(NOT "${${_cache_name}}" STREQUAL "")
    list(APPEND _configure_env "${_env_name}=${${_cache_name}}")
  endif()
endforeach()
if(DEFINED CMAKE_C_COMPILER AND NOT "${CMAKE_C_COMPILER}" STREQUAL "")
  list(APPEND _configure_env "CC=${CMAKE_C_COMPILER}")
endif()
if(DEFINED CMAKE_CXX_COMPILER AND NOT "${CMAKE_CXX_COMPILER}" STREQUAL "")
  list(APPEND _configure_env "CXX=${CMAKE_CXX_COMPILER}")
endif()
set(_gpdb_effective_cflags "${CMAKE_C_FLAGS} ${GPDB_CFLAGS}")
set(_gpdb_effective_cxxflags "${CMAKE_CXX_FLAGS} ${GPDB_CXXFLAGS}")
if(NOT "${CMAKE_BUILD_TYPE}" STREQUAL "")
  string(TOUPPER "${CMAKE_BUILD_TYPE}" _gpdb_build_type_upper)
  if(DEFINED CMAKE_C_FLAGS_${_gpdb_build_type_upper})
    string(APPEND _gpdb_effective_cflags " ${CMAKE_C_FLAGS_${_gpdb_build_type_upper}}")
  endif()
  if(DEFINED CMAKE_CXX_FLAGS_${_gpdb_build_type_upper})
    string(APPEND _gpdb_effective_cxxflags " ${CMAKE_CXX_FLAGS_${_gpdb_build_type_upper}}")
  endif()
endif()
string(STRIP "${_gpdb_effective_cflags}" _gpdb_effective_cflags)
string(STRIP "${_gpdb_effective_cxxflags}" _gpdb_effective_cxxflags)
if(NOT "${_gpdb_effective_cflags}" STREQUAL "")
  list(APPEND _configure_env "CFLAGS=${_gpdb_effective_cflags}")
endif()
if(NOT "${_gpdb_effective_cxxflags}" STREQUAL "")
  list(APPEND _configure_env "CXXFLAGS=${_gpdb_effective_cxxflags}")
endif()
if(NOT "${GPDB_CPPFLAGS}" STREQUAL "")
  list(APPEND _configure_env "CPPFLAGS=${GPDB_CPPFLAGS}")
endif()
set(_gpdb_effective_ldflags "${CMAKE_EXE_LINKER_FLAGS} ${CMAKE_SHARED_LINKER_FLAGS} ${GPDB_LDFLAGS}")
string(STRIP "${_gpdb_effective_ldflags}" _gpdb_effective_ldflags)
if(NOT "${_gpdb_effective_ldflags}" STREQUAL "")
  list(APPEND _configure_env "LDFLAGS=${_gpdb_effective_ldflags}")
endif()
if(NOT "${GPDB_LDFLAGS_EX}" STREQUAL "")
  list(APPEND _configure_env "LDFLAGS_EX=${GPDB_LDFLAGS_EX}")
endif()
if(NOT "${GPDB_LDFLAGS_SL}" STREQUAL "")
  list(APPEND _configure_env "LDFLAGS_SL=${GPDB_LDFLAGS_SL}")
endif()
if(NOT "${GPDB_LIBS}" STREQUAL "")
  list(APPEND _configure_env "LIBS=${GPDB_LIBS}")
endif()
list(APPEND _configure_env ${GPDB_CONFIGURE_ENV})
set(GPDB_CONFIGURE_ENVIRONMENT "${_configure_env}" CACHE INTERNAL
    "Effective configure environment generated from CMake options")
if(NOT GPDB_SKIP_CONFIGURE)
  file(SHA256 "${CMAKE_SOURCE_DIR}/configure" _gpdb_configure_source_hash)
  file(SHA256 "${_gpdb_getversion_source}" _gpdb_getversion_source_hash)
  file(SHA256 "${CMAKE_SOURCE_DIR}/CMakeLists.txt" _gpdb_cmake_source_hash)
  string(SHA256 _gpdb_configure_signature
         "${_gpdb_configure_source_hash};${_gpdb_getversion_source_hash};${_gpdb_cmake_source_hash};${_configure_args};${_configure_env}")
  set(_gpdb_configure_signature_file
      "${GPDB_LEGACY_BUILD_DIR}/.gpdb-configure-signature")
  set(_gpdb_configure_required ON)
  if(EXISTS "${GPDB_LEGACY_BUILD_DIR}/config.status" AND
     EXISTS "${_gpdb_configure_signature_file}")
    file(READ "${_gpdb_configure_signature_file}" _gpdb_previous_signature)
    string(STRIP "${_gpdb_previous_signature}" _gpdb_previous_signature)
    if(_gpdb_previous_signature STREQUAL _gpdb_configure_signature)
      set(_gpdb_configure_required OFF)
    endif()
  endif()
  if(_gpdb_configure_required)
    execute_process(
      COMMAND ${CMAKE_COMMAND} -E env ${_configure_env}
              "${CMAKE_SOURCE_DIR}/configure" ${_configure_args}
      WORKING_DIRECTORY "${GPDB_LEGACY_BUILD_DIR}"
      RESULT_VARIABLE _configure_result
      OUTPUT_VARIABLE _configure_output
      ERROR_VARIABLE _configure_error)
    if(NOT _configure_result EQUAL 0)
      message(FATAL_ERROR "GPDB configure failed (${_configure_result}):\n${_configure_output}\n${_configure_error}")
    endif()
    file(WRITE "${_gpdb_configure_signature_file}" "${_gpdb_configure_signature}\n")
  endif()

  # prep_buildtree links source Makefiles into an external VPATH build tree,
  # but src/Makefile includes this tracked companion file by its local name.
  # Make it available alongside the linked Makefile for every configure reuse
  # as well as a newly configured build.
  set(_gpdb_mock_makefile_source "${CMAKE_SOURCE_DIR}/src/Makefile.mock")
  set(_gpdb_mock_makefile_destination
      "${GPDB_LEGACY_BUILD_DIR}/src/Makefile.mock")
  if(EXISTS "${_gpdb_mock_makefile_source}" AND
     NOT EXISTS "${_gpdb_mock_makefile_destination}" AND
     NOT IS_SYMLINK "${_gpdb_mock_makefile_destination}")
    file(CREATE_LINK "${_gpdb_mock_makefile_source}"
         "${_gpdb_mock_makefile_destination}" SYMBOLIC)
  endif()

  # The management Makefile enumerates installed scripts.  Keep newly added
  # source-side management commands visible in an already configured external
  # VPATH tree as well as in a fresh one.
  set(_gpdb_pomelodb_source "${CMAKE_SOURCE_DIR}/gpMgmt/bin/pomelodb")
  set(_gpdb_pomelodb_destination "${GPDB_LEGACY_BUILD_DIR}/gpMgmt/bin/pomelodb")
  if(EXISTS "${_gpdb_pomelodb_source}" AND
     NOT EXISTS "${_gpdb_pomelodb_destination}" AND
     NOT IS_SYMLINK "${_gpdb_pomelodb_destination}")
    file(CREATE_LINK "${_gpdb_pomelodb_source}"
         "${_gpdb_pomelodb_destination}" SYMBOLIC)
  endif()
  set(_gpdb_pomelodb_conf_source "${CMAKE_SOURCE_DIR}/gpMgmt/bin/pomelodb.conf")
  set(_gpdb_pomelodb_conf_destination
      "${GPDB_LEGACY_BUILD_DIR}/gpMgmt/bin/pomelodb.conf")
  if(EXISTS "${_gpdb_pomelodb_conf_source}" AND
     NOT EXISTS "${_gpdb_pomelodb_conf_destination}" AND
     NOT IS_SYMLINK "${_gpdb_pomelodb_conf_destination}")
    file(CREATE_LINK "${_gpdb_pomelodb_conf_source}"
         "${_gpdb_pomelodb_conf_destination}" SYMBOLIC)
  endif()

  # gpMgmt's Python and shell tools are installed directly from their source
  # directories.  prep_buildtree links their Makefiles but not the scripts,
  # which leaves an external VPATH install tree incomplete.  Add only missing
  # source-file links so configure-generated files in the build tree win.
  file(GLOB_RECURSE _gpdb_management_sources
       RELATIVE "${CMAKE_SOURCE_DIR}" "${CMAKE_SOURCE_DIR}/gpMgmt/*")
  foreach(_gpdb_management_source IN LISTS _gpdb_management_sources)
    set(_gpdb_management_source_path
        "${CMAKE_SOURCE_DIR}/${_gpdb_management_source}")
    if(NOT IS_DIRECTORY "${_gpdb_management_source_path}")
      set(_gpdb_management_destination
          "${GPDB_LEGACY_BUILD_DIR}/${_gpdb_management_source}")
      if(NOT EXISTS "${_gpdb_management_destination}" AND
         NOT IS_SYMLINK "${_gpdb_management_destination}")
        get_filename_component(_gpdb_management_destination_dir
                               "${_gpdb_management_destination}" DIRECTORY)
        file(MAKE_DIRECTORY "${_gpdb_management_destination_dir}")
        file(CREATE_LINK "${_gpdb_management_source_path}"
             "${_gpdb_management_destination}" SYMBOLIC)
      endif()
    endif()
  endforeach()

  # configure.in creates this Perl module from a source-relative template.
  # In an external VPATH build that template is not linked by prep_buildtree,
  # so materialize the configured copy here for gpdiff.pl and pg_regress.
  set(_gpdb_gptest_template "${CMAKE_SOURCE_DIR}/src/test/regress/GPTest.pm.in")
  set(_gpdb_gptest_destination
      "${GPDB_LEGACY_BUILD_DIR}/src/test/regress/GPTest.pm")
  set(_gpdb_version_file "${GPDB_LEGACY_BUILD_DIR}/VERSION")
  if(NOT EXISTS "${_gpdb_gptest_template}" OR
     NOT EXISTS "${_gpdb_version_file}")
    message(FATAL_ERROR "missing GPTest.pm template or configured VERSION file")
  endif()
  file(READ "${_gpdb_version_file}" _gpdb_version)
  string(STRIP "${_gpdb_version}" _gpdb_version)
  file(READ "${_gpdb_gptest_template}" _gpdb_gptest_contents)
  string(REPLACE "##Version: ##" "${_gpdb_version}" _gpdb_gptest_contents
         "${_gpdb_gptest_contents}")
  file(WRITE "${_gpdb_gptest_destination}" "${_gpdb_gptest_contents}")

  # configure generates this management shell helper from a source-relative
  # template.  Materialize it explicitly for an external VPATH build so the
  # installed gpinitsystem can source it.
  set(_gpdb_bash_version_template
      "${CMAKE_SOURCE_DIR}/gpMgmt/bin/lib/gp_bash_version.sh.in")
  set(_gpdb_bash_version_destination
      "${GPDB_LEGACY_BUILD_DIR}/gpMgmt/bin/lib/gp_bash_version.sh")
  if(NOT EXISTS "${_gpdb_bash_version_template}")
    message(FATAL_ERROR "missing gp_bash_version.sh template")
  endif()
  file(READ "${_gpdb_bash_version_template}" _gpdb_bash_version_contents)
  string(REPLACE "##version##" "${_gpdb_version}"
         _gpdb_bash_version_contents "${_gpdb_bash_version_contents}")
  file(WRITE "${_gpdb_bash_version_destination}"
       "${_gpdb_bash_version_contents}")
endif()

add_custom_target(gpdb ALL
  COMMAND ${CMAKE_COMMAND} -E env ${_configure_env}
          "${GPDB_MAKE_PROGRAM}" -C "${GPDB_LEGACY_BUILD_DIR}" all
  USES_TERMINAL)
if(GPDB_ENABLE_NATIVE_TARGETS AND GPDB_BUILD_NATIVE_TARGETS_WITH_GPDB)
  add_dependencies(gpdb gpdb-native-libraries gpdb-native-clients)
endif()
add_custom_target(gpdb-install
  COMMAND ${CMAKE_COMMAND} -E env ${_configure_env}
          "${GPDB_MAKE_PROGRAM}" -C "${GPDB_LEGACY_BUILD_DIR}" install
  USES_TERMINAL)
add_custom_target(gpdb-clean
  COMMAND "${GPDB_MAKE_PROGRAM}" -C "${GPDB_LEGACY_BUILD_DIR}" clean
  USES_TERMINAL)

# `cmake --install` must install the complete database, not only the subset of
# frontend targets that currently have native CMake definitions.  Keep the
# generated install script in the build tree so it has the exact configure
# environment and legacy build directory selected for this CMake build.
configure_file("${CMAKE_SOURCE_DIR}/cmake/GPDBInstall.cmake.in"
               "${CMAKE_CURRENT_BINARY_DIR}/GPDBInstall.cmake" @ONLY)
install(SCRIPT "${CMAKE_CURRENT_BINARY_DIR}/GPDBInstall.cmake")

enable_testing()
add_test(NAME gpdb-cmake-interface
  COMMAND ${CMAKE_COMMAND} -DGPDB_SOURCE_DIR=${CMAKE_SOURCE_DIR}
          -P ${CMAKE_SOURCE_DIR}/cmake/tests/validate_configure_options.cmake)

message(STATUS "GPDB CMake interface configured")
message(STATUS "  legacy build directory: ${GPDB_LEGACY_BUILD_DIR}")
message(STATUS "  compiler: ${CMAKE_C_COMPILER}")
message(STATUS "  generator: ${CMAKE_GENERATOR}")
