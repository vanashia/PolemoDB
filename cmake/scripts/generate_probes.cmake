if(NOT DEFINED INPUT OR NOT DEFINED SCRIPT OR NOT DEFINED OUTPUT)
  message(FATAL_ERROR "INPUT, SCRIPT, and OUTPUT are required")
endif()
execute_process(
  COMMAND sed -f "${SCRIPT}" "${INPUT}"
  RESULT_VARIABLE _result
  OUTPUT_FILE "${OUTPUT}"
  ERROR_VARIABLE _error)
if(NOT _result EQUAL 0)
  message(FATAL_ERROR "probe generator failed (${_result}): ${_error}")
endif()
