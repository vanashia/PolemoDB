# PomeloDB instance manager

The installation includes `bin/pomelodb` and a configuration file at the
installation prefix root:

```text
/usr/local/pomelodb/pomelodb.conf
```

The default file keeps database files and logs in separate directories:

```conf
data_directory=data
log_directory=log
initdb_options=
server_options=-b -1 -C -1 -c gp_role=utility
stop_mode=fast
wait=true
```

Relative paths are resolved from the installation prefix. Absolute paths are
also supported. `data_directory` and `log_directory` must both be set and may
not be the same directory or nested below one another.

The command does not require `PGDATA`, `GPHOME`, or a sourced environment
file. It resolves `initdb` and `pg_ctl` from the same installation prefix:

```sh
/usr/local/pomelodb/bin/pomelodb init
/usr/local/pomelodb/bin/pomelodb start
/usr/local/pomelodb/bin/pomelodb status
/usr/local/pomelodb/bin/pomelodb reload
/usr/local/pomelodb/bin/pomelodb stop
```

`init` initializes the data directory and configures PostgreSQL's
`logging_collector` and `log_directory`. `start` writes the same logging
settings before starting, and sends `pg_ctl`'s startup output to
`log/pomelodb-startup.log`. The configuration file is parsed as data, not
executed as a shell script.
