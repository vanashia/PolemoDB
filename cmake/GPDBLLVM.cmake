if(NOT GPDB_WITH_LLVM)
  return()
endif()

set(_gpdb_llvm_sources
  "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit.c"
  "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit_error.cpp"
  "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit_inline.cpp"
  "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit_wrap.cpp"
  "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit_expr.c"
  "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit_deform.c")

add_library(llvmjit MODULE ${_gpdb_llvm_sources})
gpdb_apply_common_options(llvmjit)
add_dependencies(llvmjit gpdb-generated)
target_compile_definitions(llvmjit PRIVATE USE_LLVM)
target_include_directories(llvmjit PRIVATE
  ${_gpdb_include_dirs}
  "${CMAKE_SOURCE_DIR}/src/backend"
  "${GPDB_GENERATED_BACKEND_DIR}")
target_compile_options(llvmjit PRIVATE ${GPDB_LLVM_CPPFLAGS}
  $<$<COMPILE_LANGUAGE:CXX>:${GPDB_LLVM_CXXFLAGS}>)
target_link_options(llvmjit PRIVATE ${GPDB_LLVM_LDFLAGS})
target_link_libraries(llvmjit PRIVATE gpdb-platform ${GPDB_LLVM_LIBS})
set_target_properties(llvmjit PROPERTIES
  PREFIX ""
  SUFFIX ".so"
  CXX_STANDARD 14
  CXX_STANDARD_REQUIRED ON)
gpdb_apply_module_link_options(llvmjit)

set(GPDB_LLVM_TYPES_BITCODE
  "${CMAKE_CURRENT_BINARY_DIR}/llvmjit_types.bc")
add_custom_command(
  OUTPUT "${GPDB_LLVM_TYPES_BITCODE}"
  COMMAND "${GPDB_LLVM_CLANG_EXECUTABLE}"
    ${GPDB_LLVM_CPPFLAGS}
    -D_GNU_SOURCE
    -DUSE_LLVM
    -DFLOAT4PASSBYVAL=true
    -DFLOAT8PASSBYVAL=true
    -DUSE_FLOAT4_BYVAL
    -DUSE_FLOAT8_BYVAL
    -I${CMAKE_SOURCE_DIR}/src/include
    -I${CMAKE_SOURCE_DIR}/src/include/port
    -I${CMAKE_SOURCE_DIR}/src
    -I${CMAKE_SOURCE_DIR}/src/common
    -I${CMAKE_SOURCE_DIR}/src/port
    -I${CMAKE_SOURCE_DIR}/src/interfaces/libpq
    -I${GPDB_GENERATED_INCLUDE_DIR}
    -I${GPDB_GENERATED_BACKEND_DIR}
    -emit-llvm -c
    "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit_types.c"
    -o "${GPDB_LLVM_TYPES_BITCODE}"
  DEPENDS gpdb-generated
    "${CMAKE_SOURCE_DIR}/src/backend/jit/llvm/llvmjit_types.c"
  VERBATIM)
add_custom_target(llvmjit-types DEPENDS "${GPDB_LLVM_TYPES_BITCODE}")
