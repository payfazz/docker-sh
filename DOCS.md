## How to use it
`docker.sh` will be used as interpreter, you need to install it in your `PATH` e.g. by copy `docker.sh` file to `/usr/local/bin` (`install.sh` will do this for you)

Create spec file `nginx`
```sh
#!/usr/bin/env docker.sh

name=test_nginx
image=nginx:alpine
opts="
  -p 8080:80
"
```

then make it executable by `chmod 755 nginx`, after that, you can execute this file, `./nginx help` will give you more info. (see *Available Command* below)

#### Variable and hook function.
Variable:

- `image` (**required**)
- `name`
- `net`,
  If network not exists yet, it will be created for you.
  This network will be removed when last container attach to it removed.
- `opts`
- `args`
- `stop_opts`
- `rm_opts`
- `kill_opts`
- `must_local`,
  If set to `y`, it will ensure docker daemon is running on local machine,
  useful if you want to use bind-mount.
- `create_only`,
  If set to `y`, `start` command will only create the container, but won't run it.

*NOTE*: `opts`, `args`, `stop_opts`, `rm_opts`, `kill_opts` are processed with `quote` function (see below).


Hook function:
- `pre_start`, see `start` command below.
- `post_start`, see `start` command below.
- `pre_stop`
- `post_stop`
- `pre_restart`
- `post_restart`
- `pre_rm`
- `post_rm`
- `pre_pull`
- `post_pull`

Some variable will be defined before execute your spec file (do not edit these var):
- `$dir`,
  The directory path contain the spec file.
- `$file`,
  The path of the spec file.
- `$dirname`,
  The directory name of spec file (name only, without path).
- `$filename`,
  The name of the spec file (name only, without path).
- `$dirsum`,
  The checksum of `$dir`. Useful for avoiding name collision (see example for usage).

If `name` is not specified in the spec file, it will be `$dirname-$filename-$dirsum`.

*NOTE*: You can use `show_cmds` to see the final result of constructed argument.

#### `quote` function.
Because POSIX shell does't support array,
we provide `quote` function utility to serialize array so you can use it safely in `eval` and `set` to change `"$@"`.

example usage:

```sh
old_args=$(no_proc=y quote "$@")
eval "set -- $(quote "a b 'c d' \"e'f\"")"
for x; do echo ">$x<"; done
# restore old args
eval "set -- $old_args"
```
will print:
```
>a<
>b<
>c d<
>e'f<
```

to set max count of `quote`, set `count` env, example:
```sh
count=2 quote a b c d # will print: 'a' 'b'
```

to disable special chars, set `no_proc` env to `y`, example:
```sh
quote a "'b" c d # will error with message: unmatched single quote
no_proc=y quote a "'b" c d # will print: 'a' ''\''b' 'c' 'd'
```

#### `exists` function.
This helper function to check existance of volume, image, container, network.
The function will exit with 0 if exists, or non-zero otherwise.

usage:

    exists <type> <name>

example:
```sh
if ! exists network my-network; then
  # do something
fi
```

#### `running` function.
This helper function to check if container is running or not.
The function will exit with 0 if the container is running, or non-zero otherwise.

usage:

    running <container_name>

example:
```sh
if running my-container; then
  # do something
fi
```

#### Adding arbitary command.
You can add arbitrary command by defining function `command_<name>`, for example adding `reload` command to nginx spec file.

Create spec file `nginx`
```sh
#!/usr/bin/env docker.sh

name=test_nginx
image=nginx:alpine
opts="
  -p 8080:80
"

command_reload() {
  "$file" exec nginx -s reload
}
```

`./nginx reload` will be available.

#### `panic` function
Print arguments to stderr and exit with exitcode 1

#### `main` function
This function is useful for invoking another command.

example:
```sh
#!/usr/bin/env docker.sh

image=nginx:alpine

command_top() {
  main exec sh -c 'eval `resize` && exec top'
}
```

## Available command

### `start`
Start the container if not started yet. The container will be started based on `opts` and `args`. See also `show_cmds`.

`pre_start` and `post_start` hook function will be called with different argument. That argument depend on following:

- If container not exists yet:
  - `pre_start run`
  - `docker create ...`
  - `pre_start created`
  - `docker start ...`
  - `post_start run`

- If container already exists, but not started yet:
  - `pre_start start`
  - `docker start ...`
  - `post_start start`


### `stop`
Stop the container if not stopped. The container will be stoped based on `stop_opts` and/or any argument passed to this command. Only `-t`/`--time` are supported for now.

### `restart`
Restart the container. The container will be stoped based on `stop_opts` and/or any argument passed to this command. Only `-t`/`--time` are supported for now.

### `rm`
Remove the container if exists. The container will be removed based on `rm_opts` and/or any argument passed to this. Only `-f`/`--force`, `-v`/`--volume`, `-l`/`--link` are supported for now.
Network defined on `net` will be removed if this container is the last container attach to that network.

### `exec`
Exec command inside container.

### `exec_root`
Exec command inside container as root.

### `exec_as`
Exec program inside the container as specified user.

### `kill`
Kill the container. The container will be stoped based on `kill_opts` and/or any argument passed to this command. Only `-s`/`--signal` are supported for now.

### `logs`
Show logs of the container. Any argument passed to this command will used by underlying docker program.

### `port`
Show port mapping of the container. Any argument passed to this command will used by underlying docker program.

### `status`
Show container status, possibel output are any combination (in one line) of:
- `different_opts`
- `different_image`
- `running`
- `not_running`
- `no_container`

### `name`
Print `name`

### `image`
Print `image`

### `net`
Print `net`

### `show_cmds`
Show the final constructed arguments for underlying docker program.

### `show_running_cmds`
Show the arguments for running current container.

### `pull`
Pull image specified in `image`.

### `ip`
Show ip address of the container, that attach to network `net`.

### `update`
Pull image specified in `image` (`-n`/`nopull` will skip this step).
Stop, remove, and start the container if running container using outdated image or `show_cmds` and `show_running_cmds` have different value or `-f`/`--force` specified to this command.

### `help`
Help

## Example

See files inside example directory.

### postgres

to start postgres, run

    ./example/postgres/app start

postgres will exposed on port 5432.


### pgadmin4

to start pgadmin4, run

    ./example/pgadmin/app start

pgadmin4 will be exposed on port 5050.


### wordpress

to start wordpress, run

    ./example/wordpress-mariadb/wordpress start

wordpress will be exposed on port 8080.


### phpmyadmin

to start phpmyadmin, run

    ./example/pgadmin/app start

phpmyadmin will be exposed on port 8080.

### jenkins

to start jenkins, run

    ./example/jenkins/app start

jenkins will be exposed on port 8080.
