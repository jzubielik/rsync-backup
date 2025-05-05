# rsync-backup

This project aims to deliver a bi-directional asynchronous replication based on rsync over SSH and cron.

## Installation

```bash
git clone git@github.com:jzubielik/rsync-backup.git
cd rsync-backup
make install
```

## Configuration

In order to create create or edit the configuration file run:

```bash
make config
```

The following set of variables needs to be set:

```bash
REMOTE_USER=username
REMOTE_HOST=remote.host.address
REMOTE_PATH=/remote/path
LOCAL_PATH=/local/path
```

> Please note that variables like `RSYNC_OPTS`, `TIMEOUT` and `LOG_DIR` can be overrided in the configuration file.

In order to configure a new synchronization create `.sync` file in a directory you wish to be synchronized. 

The following example will allow synchronization of `/local/path/Documents` to `/remote/path/Documents` at the remote host:

```bash
touch ~/Documents/.sync
```

The following example will allow synchronization of `/local/path/Documents/important` to `/remote/path/Documents/important` at the remote host:

```bash
touch ~/Documents/important/.sync
```

The following example will allow to exlude some files from the synchronization:

```bash
echo "EXCLUDES=(private/secret.txt '*.tmp')" > ~/Documents/important/.sync
```

This will prevent synchronization of the `/local/path/Documents/important/private/secret.txt` file and all `.tmp` files from any of the subdirectories.

## Initialization

By default the following set of flags is used for `rsync`:

```bash
RSYNC_OPTS=(
  -aPDAXUH
  --fake-super
  --progress
  --verbose
  --update
  --delete
  --one-file-system
)
```

Since the `--delete` flag is used it's imposible to synchronize two sources with different states without loosing one of them. In order to prevent that there is an option to perform an initial synchronization without the `--delete` flag. This inital synchronization will merge both sources.

In order to perform an initial synchronization run:

```bash
make init
```

> Please note that this operation needs to be performed before enabling the cron job or after disabling it as when executed by cron it will use the `--delete` flag by default and may remove data from one of the sources.

## Enabling

In order to enable the cron jon run:

```bash
make enable
```

## Disabling

In order to disable the cron jon run:

```bash
make disable
```

## Logging

By default logs are kept in `~/.local/log/rsync-backup` directory.
