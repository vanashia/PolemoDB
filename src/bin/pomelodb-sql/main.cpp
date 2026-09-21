#include "pomelodb_duckdb_executor.h"

#include <iostream>
#include <sstream>
#include <string>

namespace {

std::string ReadSql(int argc, char **argv) {
  if (argc > 1) {
    std::ostringstream sql;
    for (int index = 1; index < argc; ++index) {
      if (index > 1) {
        sql << ' ';
      }
      sql << argv[index];
    }
    return sql.str();
  }

  std::ostringstream sql;
  sql << std::cin.rdbuf();
  return sql.str();
}

void PrintResult(const pomelodb::duckdb::QueryResult &result) {
  for (size_t column = 0; column < result.column_names.size(); ++column) {
    if (column > 0) {
      std::cout << '\t';
    }
    std::cout << result.column_names[column];
  }
  if (!result.column_names.empty()) {
    std::cout << '\n';
  }

  for (const auto &row : result.rows) {
    for (size_t column = 0; column < row.size(); ++column) {
      if (column > 0) {
        std::cout << '\t';
      }
      std::cout << row[column];
    }
    std::cout << '\n';
  }
}

}  // namespace

int main(int argc, char **argv) {
  try {
    const auto sql = ReadSql(argc, argv);
    if (sql.find_first_not_of(" \t\r\n") == std::string::npos) {
      std::cerr << "SQL input is empty\n";
      return 2;
    }

    pomelodb::duckdb::PomeloDuckDBExecutor executor;
    PrintResult(executor.Execute(sql));
    return 0;
  } catch (const std::exception &error) {
    std::cerr << "pomelodb-sql: " << error.what() << '\n';
    return 1;
  }
}
