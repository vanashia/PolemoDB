include(CheckIncludeFile)
include(CheckCSourceCompiles)
include(CheckSymbolExists)
include(FindPackageHandleStandardArgs)

find_package(Threads REQUIRED)
find_package(Perl REQUIRED)
find_package(PkgConfig QUIET)
if(NOT WIN32)
  find_library(GPDB_M_LIBRARY NAMES m REQUIRED)
  find_library(GPDB_CRYPT_LIBRARY NAMES crypt)
endif()

# Keep the generated pg_config.h consistent with the C library headers.  The
# legacy configure path probes these symbols and port.h only supplies fallback
# declarations when the corresponding HAVE_* macro is absent.
set(_gpdb_saved_required_definitions "${CMAKE_REQUIRED_DEFINITIONS}")
set(_gpdb_saved_required_libraries "${CMAKE_REQUIRED_LIBRARIES}")
set(CMAKE_REQUIRED_DEFINITIONS -D_GNU_SOURCE)
set(CMAKE_REQUIRED_LIBRARIES ${GPDB_M_LIBRARY} ${GPDB_CRYPT_LIBRARY})
check_symbol_exists(crypt "unistd.h" GPDB_HAVE_CRYPT)
check_symbol_exists(rint "math.h" GPDB_HAVE_RINT)
check_symbol_exists(dlopen "dlfcn.h" GPDB_HAVE_DLOPEN)
check_symbol_exists(strchrnul "string.h" GPDB_HAVE_STRCHRNUL)
check_symbol_exists(fls "strings.h" GPDB_HAVE_FLS)
check_symbol_exists(getpeereid "unistd.h" GPDB_HAVE_GETPEEREID)
set(CMAKE_REQUIRED_DEFINITIONS "${_gpdb_saved_required_definitions}")
set(CMAKE_REQUIRED_LIBRARIES "${_gpdb_saved_required_libraries}")
unset(_gpdb_saved_required_definitions)
unset(_gpdb_saved_required_libraries)

# Keep the generated dynamic shared-memory default consistent with the host.
# initdb copies postgresql.conf.sample, which defaults to POSIX DSM when
# shm_open() is available.  Without this native probe macOS would generate a
# server that rejects its own freshly initialized configuration.
check_symbol_exists(shm_open "sys/mman.h" GPDB_HAVE_SHM_OPEN)

# SysV semaphore headers do not consistently declare union semun.  The
# legacy configure probe detects this type and sysv_sema.c supplies the
# fallback definition when it is absent, so keep the native CMake path
# consistent with that behavior on Linux and other SysV platforms.
if(NOT WIN32)
check_c_source_compiles("#include <sys/types.h>
#include <sys/ipc.h>
#include <sys/sem.h>
int main(void) { union semun value; value.val = 0; return value.val; }"
  GPDB_HAVE_UNION_SEMUN)
endif()

if(GPDB_WITH_ZLIB)
  find_package(ZLIB REQUIRED)
endif()
if(GPDB_WITH_LIBBZ2)
  find_package(BZip2 REQUIRED)
endif()
if(GPDB_WITH_OPENSSL)
  find_package(OpenSSL REQUIRED)
endif()
if(GPDB_WITH_LIBXML)
  find_package(LibXml2 REQUIRED)
endif()
if(GPDB_WITH_LIBCURL)
  find_package(CURL REQUIRED)
endif()
if(GPDB_WITH_ICU)
  find_package(ICU REQUIRED COMPONENTS uc i18n)
endif()
if(GPDB_WITH_READLINE)
  find_path(GPDB_READLINE_INCLUDE_DIR readline/readline.h)
  find_library(GPDB_READLINE_LIBRARY NAMES readline edit)
endif()
if(GPDB_WITH_ZSTD)
  find_library(GPDB_ZSTD_LIBRARY NAMES zstd REQUIRED)
  find_path(GPDB_ZSTD_INCLUDE_DIR zstd.h REQUIRED)
endif()

if(GPDB_WITH_GSSAPI)
  if(APPLE)
    find_library(GPDB_GSS_LIBRARY NAMES gssapi_krb5 REQUIRED)
  else()
    find_library(GPDB_GSS_LIBRARY NAMES gssapi_krb5 gssapi REQUIRED)
  endif()
endif()

if(GPDB_ENABLE_GPFDIST)
  set(_gpdb_apr_hint_includes)
  set(_gpdb_apr_hint_libdirs)
  if(GPDB_APR_CONFIG)
    get_filename_component(_gpdb_apr_config_dir "${GPDB_APR_CONFIG}" DIRECTORY)
    get_filename_component(_gpdb_apr_prefix "${_gpdb_apr_config_dir}/.." ABSOLUTE)
    list(APPEND _gpdb_apr_hint_includes
      "${_gpdb_apr_prefix}/include/apr-1"
      "${_gpdb_apr_config_dir}/../include/apr-1")
    list(APPEND _gpdb_apr_hint_libdirs "${_gpdb_apr_prefix}/lib"
      "${_gpdb_apr_config_dir}/../lib")
    unset(GPDB_APR_INCLUDE_DIR CACHE)
    unset(GPDB_APR_LIBRARY CACHE)
  endif()
  if(PkgConfig_FOUND)
    pkg_check_modules(APR apr-1)
    pkg_check_modules(LIBEVENT libevent)
    pkg_check_modules(YAML yaml-0.1)
  endif()
  find_path(GPDB_APR_INCLUDE_DIR NAMES apr.h
    HINTS ${_gpdb_apr_hint_includes} ${APR_INCLUDE_DIRS})
  find_library(GPDB_APR_LIBRARY NAMES apr-1
    HINTS ${_gpdb_apr_hint_libdirs} ${APR_LIBRARY_DIRS})
  set(GPDB_LIBEVENT_INCLUDE_DIR ${LIBEVENT_INCLUDE_DIRS})
  find_library(GPDB_LIBEVENT_LIBRARY NAMES event_core event HINTS ${LIBEVENT_LIBRARY_DIRS})
  set(GPDB_YAML_INCLUDE_DIR ${YAML_INCLUDE_DIRS})
  find_library(GPDB_YAML_LIBRARY NAMES yaml yaml-0 HINTS ${YAML_LIBRARY_DIRS})
  find_package_handle_standard_args(GPDBGpfdist DEFAULT_MSG
    GPDB_APR_INCLUDE_DIR GPDB_APR_LIBRARY GPDB_LIBEVENT_INCLUDE_DIR
    GPDB_LIBEVENT_LIBRARY)
endif()

add_library(gpdb-platform INTERFACE)
target_link_libraries(gpdb-platform INTERFACE Threads::Threads ${GPDB_M_LIBRARY})
if(GPDB_CRYPT_LIBRARY)
  target_link_libraries(gpdb-platform INTERFACE "${GPDB_CRYPT_LIBRARY}")
endif()
if(GPDB_WITH_ZLIB)
  target_link_libraries(gpdb-platform INTERFACE ZLIB::ZLIB)
endif()
if(GPDB_WITH_LIBBZ2)
  target_link_libraries(gpdb-platform INTERFACE BZip2::BZip2)
endif()
if(GPDB_WITH_OPENSSL)
  target_link_libraries(gpdb-platform INTERFACE OpenSSL::SSL OpenSSL::Crypto)
endif()
if(GPDB_WITH_LIBXML)
  target_link_libraries(gpdb-platform INTERFACE LibXml2::LibXml2)
endif()
if(GPDB_WITH_LIBCURL)
  target_link_libraries(gpdb-platform INTERFACE CURL::libcurl)
endif()
if(GPDB_WITH_ICU)
  target_link_libraries(gpdb-platform INTERFACE ICU::uc ICU::i18n)
endif()
if(GPDB_WITH_ZSTD)
  target_include_directories(gpdb-platform INTERFACE "${GPDB_ZSTD_INCLUDE_DIR}")
  target_link_libraries(gpdb-platform INTERFACE "${GPDB_ZSTD_LIBRARY}")
endif()
if(GPDB_WITH_GSSAPI)
  target_link_libraries(gpdb-platform INTERFACE "${GPDB_GSS_LIBRARY}")
endif()
if(GPDB_INCLUDES)
  separate_arguments(_gpdb_extra_includes UNIX_COMMAND "${GPDB_INCLUDES}")
  target_include_directories(gpdb-platform INTERFACE ${_gpdb_extra_includes})
endif()
if(GPDB_LIBRARIES)
  separate_arguments(_gpdb_extra_libdirs UNIX_COMMAND "${GPDB_LIBRARIES}")
  target_link_directories(gpdb-platform INTERFACE ${_gpdb_extra_libdirs})
endif()

if(CMAKE_C_COMPILER_LAUNCHER OR CMAKE_CXX_COMPILER_LAUNCHER)
  # Respect an explicitly selected launcher.
elseif(CMAKE_GENERATOR MATCHES "Ninja")
  find_program(GPDB_CCACHE_PROGRAM ccache)
  if(GPDB_CCACHE_PROGRAM)
    set(CMAKE_C_COMPILER_LAUNCHER "${GPDB_CCACHE_PROGRAM}" CACHE FILEPATH
        "Compiler launcher" FORCE)
    set(CMAKE_CXX_COMPILER_LAUNCHER "${GPDB_CCACHE_PROGRAM}" CACHE FILEPATH
        "C++ compiler launcher" FORCE)
  endif()
endif()
