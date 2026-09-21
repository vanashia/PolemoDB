# pomelodb-sql

`pomelodb-sql` is the native CMake SQL entry point for the embedded DuckDB
executor. It uses an in-memory DuckDB database by default and accepts one SQL
statement as an argument or from standard input:

```sh
build-duckdb/pomelodb-sql 'SELECT 1 + 1 AS answer'
printf 'SELECT 42 AS answer\n' | build-duckdb/pomelodb-sql
```

The command prints tab-separated column names and rows. SQL errors are written
to standard error and return a non-zero exit status.
