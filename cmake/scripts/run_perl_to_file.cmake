if(NOT DEFINED OUTPUT OR NOT DEFINED PERL OR NOT DEFINED SCRIPT OR NOT DEFINED INPUT)
  message(FATAL_ERROR "OUTPUT, PERL, SCRIPT, and INPUT are required")
endif()
execute_process(
  COMMAND "${PERL}" "${SCRIPT}" "${INPUT}"
  RESULT_VARIABLE _result
  OUTPUT_FILE "${OUTPUT}"
  ERROR_VARIABLE _error)
if(NOT _result EQUAL 0)
  message(FATAL_ERROR "Perl generator failed (${_result}): ${_error}")
endif()
