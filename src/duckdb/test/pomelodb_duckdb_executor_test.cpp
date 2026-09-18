#include "pomelodb_duckdb_executor.h"

#include <cassert>
#include <stdexcept>
#include <string>

int main() {
  pomelodb::duckdb::PomeloDuckDBExecutor executor;
  const auto result = executor.Execute("SELECT 1 + 1 AS answer");

  assert(result.column_names.size() == 1);
  assert(result.column_names[0] == "answer");
  assert(result.rows.size() == 1);
  assert(result.rows[0].size() == 1);
  assert(result.rows[0][0] == "2");

  const auto values = executor.Execute("SELECT * FROM (VALUES (1, 'pomelo'))");
  assert(values.column_names.size() == 2);
  assert(values.rows.size() == 1);
  assert(values.rows[0].size() == 2);
  assert(values.rows[0][0] == "1");
  assert(values.rows[0][1] == "pomelo");

  bool failed = false;
  try {
    executor.Execute("SELECT * FROM missing_table");
  } catch (const std::runtime_error &error) {
    failed = std::string(error.what()).find("missing_table") != std::string::npos;
  }
  assert(failed);
  return 0;
}
