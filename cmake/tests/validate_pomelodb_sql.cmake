if(NOT DEFINED POMELODB_SQL_EXECUTABLE)
  message(FATAL_ERROR "POMELODB_SQL_EXECUTABLE is required")
endif()

execute_process(
  COMMAND "${POMELODB_SQL_EXECUTABLE}" "SELECT 42 AS answer"
  RESULT_VARIABLE _result
  OUTPUT_VARIABLE _output
  ERROR_VARIABLE _error
  OUTPUT_STRIP_TRAILING_WHITESPACE)
if(NOT _result EQUAL 0)
  message(FATAL_ERROR "pomelodb-sql failed (${_result}): ${_error}")
endif()
if(NOT _output MATCHES "answer")
  message(FATAL_ERROR "pomelodb-sql output is missing the answer column: ${_output}")
endif()
if(NOT _output MATCHES "(^|[\n\t])42($|[\n\t])")
  message(FATAL_ERROR "pomelodb-sql output is missing value 42: ${_output}")
endif()
