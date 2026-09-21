# PomeloDB instance manager

The installation includes `bin/pomelodb` and a configuration file at the
installation prefix root:

```text
/usr/local/pomelodb/pomelodb.conf
```

The default file describes a single-host production MPP cluster. It keeps the
coordinator, segment, and logs in separate directories:

```conf
cluster_mode=mpp
coordinator_data_directory=mpp/coordinator/pomelodb-1
segment_data_directories=mpp/segment/pomelodb0
log_directory=log
stop_mode=fast
wait=true
```

Relative paths are resolved from the installation prefix. Absolute paths are
also supported. MPP data directories and `log_directory` must be separate.
`segment_data_directories` accepts a comma-separated list for additional local
segments.

The command does not require `PGDATA`, `GPHOME`, or a sourced environment
file. It resolves `initdb` and `pg_ctl` from the same installation prefix:

```sh
/usr/local/pomelodb/bin/pomelodb init
/usr/local/pomelodb/bin/pomelodb start
/usr/local/pomelodb/bin/pomelodb status
/usr/local/pomelodb/bin/pomelodb reload
/usr/local/pomelodb/bin/pomelodb stop
```

Run `gpinitsystem` once to initialize the listed coordinator and segment
directories. Then `pomelodb start`, `status`, `reload`, and `stop` operate all
local instances directly with their production roles. There is no utility-mode
or single-instance compatibility path. `init` validates and applies logging to
an already initialized MPP cluster. The configuration file is plain
`key=value` text and can also be sourced by a shell.
