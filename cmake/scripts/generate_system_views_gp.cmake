if(NOT DEFINED INPUT OR NOT DEFINED OUTPUT)
  message(FATAL_ERROR "INPUT and OUTPUT are required")
endif()
file(STRINGS "${INPUT}" _view_names)
file(WRITE "${OUTPUT}"
  "-- MPP-aware system views of the PG system views.\n"
  "-- Auto-generated from system_views_gp.in.\n")
foreach(_view IN LISTS _view_names)
  if(NOT _view MATCHES "^[ \\t]*#" AND NOT _view STREQUAL "")
    string(STRIP "${_view}" _view)
    string(REGEX REPLACE "^pg_" "" _short_view "${_view}")
    file(APPEND "${OUTPUT}"
      "CREATE OR REPLACE VIEW gp_${_short_view} AS\n"
      "SELECT gp_execution_segment() as gp_segment_id, *\n"
      "FROM gp_dist_random('pg_${_short_view}')\n"
      "UNION ALL\n"
      "SELECT -1 as gp_segment_id, * from pg_${_short_view};\n\n")
  endif()
endforeach()
