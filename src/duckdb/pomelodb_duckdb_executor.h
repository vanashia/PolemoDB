#pragma once

#include <memory>
#include <string>
#include <string_view>
#include <vector>

namespace pomelodb::duckdb {

struct QueryResult {
  std::vector<std::string> column_names;
  std::vector<std::string> column_types;
  std::vector<std::vector<std::string>> rows;
};

class PomeloDuckDBExecutor {
 public:
  explicit PomeloDuckDBExecutor(std::string database_path = ":memory:");
  ~PomeloDuckDBExecutor();

  PomeloDuckDBExecutor(PomeloDuckDBExecutor &&) noexcept;
  PomeloDuckDBExecutor &operator=(PomeloDuckDBExecutor &&) noexcept;

  PomeloDuckDBExecutor(const PomeloDuckDBExecutor &) = delete;
  PomeloDuckDBExecutor &operator=(const PomeloDuckDBExecutor &) = delete;

  QueryResult Execute(std::string_view sql);

 private:
  struct Impl;
  std::unique_ptr<Impl> impl_;
};

}  // namespace pomelodb::duckdb
