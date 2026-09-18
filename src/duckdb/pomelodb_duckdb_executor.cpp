#include "pomelodb_duckdb_executor.h"

#include "duckdb.hpp"

#include <stdexcept>
#include <utility>

namespace pomelodb::duckdb {

struct PomeloDuckDBExecutor::Impl {
  explicit Impl(const std::string &database_path)
      : database(database_path), connection(database) {}

  ::duckdb::DuckDB database;
  ::duckdb::Connection connection;
};

PomeloDuckDBExecutor::PomeloDuckDBExecutor(std::string database_path)
    : impl_(std::make_unique<Impl>(database_path)) {}

PomeloDuckDBExecutor::~PomeloDuckDBExecutor() = default;

PomeloDuckDBExecutor::PomeloDuckDBExecutor(
    PomeloDuckDBExecutor &&other) noexcept = default;

PomeloDuckDBExecutor &PomeloDuckDBExecutor::operator=(
    PomeloDuckDBExecutor &&other) noexcept = default;

QueryResult PomeloDuckDBExecutor::Execute(std::string_view sql) {
  auto result = impl_->connection.Query(std::string(sql));
  if (!result) {
    throw std::runtime_error("DuckDB returned no query result");
  }
  if (result->HasError()) {
    throw std::runtime_error(result->GetError());
  }

  QueryResult output;
  const auto &names = result->GetNames();
  const auto &types = result->GetTypes();
  output.column_names.reserve(names.size());
  output.column_types.reserve(types.size());
  for (const auto &name : names) {
    output.column_names.emplace_back(name.GetIdentifierName());
  }
  for (const auto &type : types) {
    output.column_types.emplace_back(type.ToString());
  }

  while (auto chunk = result->Fetch()) {
    for (::duckdb::idx_t row = 0; row < chunk->size(); ++row) {
      std::vector<std::string> values;
      values.reserve(chunk->ColumnCount());
      for (::duckdb::idx_t column = 0; column < chunk->ColumnCount(); ++column) {
        const auto value = chunk->GetValue(column, row);
        values.emplace_back(value.IsNull() ? "NULL" : value.ToString());
      }
      output.rows.emplace_back(std::move(values));
    }
  }
  if (result->HasError()) {
    throw std::runtime_error(result->GetError());
  }
  return output;
}

}  // namespace pomelodb::duckdb
