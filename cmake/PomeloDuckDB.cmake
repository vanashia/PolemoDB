if(NOT EXISTS "${CMAKE_SOURCE_DIR}/third_party/duckdb/CMakeLists.txt")
  message(FATAL_ERROR
          "POMELODB_WITH_DUCKDB=ON requires the third_party/duckdb submodule")
endif()

set(BUILD_SHELL OFF CACHE BOOL "" FORCE)
set(BUILD_UNITTESTS OFF CACHE BOOL "" FORCE)
set(ENABLE_UNITTEST_CPP_TESTS OFF CACHE BOOL "" FORCE)
set(BUILD_BENCHMARKS OFF CACHE BOOL "" FORCE)
set(BUILD_EXTENSIONS_ONLY OFF CACHE BOOL "" FORCE)
set(BUILD_MAIN_DUCKDB_LIBRARY ON CACHE BOOL "" FORCE)
set(DISABLE_EXTENSION_LOAD ON CACHE BOOL "" FORCE)
set(DISABLE_BUILTIN_EXTENSIONS ON CACHE BOOL "" FORCE)
set(BUILD_EXTENSIONS "" CACHE STRING "" FORCE)

add_subdirectory("${CMAKE_SOURCE_DIR}/third_party/duckdb"
                 "${CMAKE_BINARY_DIR}/third_party/duckdb"
                 EXCLUDE_FROM_ALL)

add_library(pomelodb_duckdb_executor STATIC
            "${CMAKE_SOURCE_DIR}/src/duckdb/pomelodb_duckdb_executor.cpp")
target_include_directories(pomelodb_duckdb_executor
                           PUBLIC "${CMAKE_SOURCE_DIR}/src/duckdb"
                                  "${CMAKE_SOURCE_DIR}/third_party/duckdb/src/include")
target_link_libraries(pomelodb_duckdb_executor PUBLIC
                      duckdb_static dummy_static_extension_loader)
target_compile_features(pomelodb_duckdb_executor PUBLIC cxx_std_17)

add_executable(pomelodb-sql
               "${CMAKE_SOURCE_DIR}/src/bin/pomelodb-sql/main.cpp")
target_link_libraries(pomelodb-sql PRIVATE pomelodb_duckdb_executor)
target_compile_features(pomelodb-sql PRIVATE cxx_std_17)

if(BUILD_TESTING)
  add_test(NAME pomelodb-sql
           COMMAND "${CMAKE_COMMAND}"
                   "-DPOMELODB_SQL_EXECUTABLE=$<TARGET_FILE:pomelodb-sql>"
                   -P "${CMAKE_SOURCE_DIR}/cmake/tests/validate_pomelodb_sql.cmake")
endif()

if(BUILD_TESTING)
  add_executable(pomelodb_duckdb_executor_test
                 "${CMAKE_SOURCE_DIR}/src/duckdb/test/pomelodb_duckdb_executor_test.cpp")
  target_link_libraries(pomelodb_duckdb_executor_test PRIVATE pomelodb_duckdb_executor)
  target_include_directories(pomelodb_duckdb_executor_test PRIVATE
                             "${CMAKE_SOURCE_DIR}/src/duckdb"
                             "${CMAKE_SOURCE_DIR}/third_party/duckdb/src/include")
  target_compile_features(pomelodb_duckdb_executor_test PRIVATE cxx_std_17)
  add_test(NAME pomelodb-duckdb-executor
           COMMAND pomelodb_duckdb_executor_test)
endif()
