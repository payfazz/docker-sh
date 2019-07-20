# How to use it
`docker.sh` will be used as interpreter, you need to install it in your `PATH` e.g. by copy `docker.sh` file to `/usr/local/bin` (`install.sh` will do this for you)

Create spec file `nginx`
```sh
#!/usr/bin/env docker.sh

image=nginx:alpine
opts="
  -p 8080:80
"
```

then make it executable by `chmod +x nginx`, after that, you can execute this file, `./nginx help` will give you more info. (see *Available Command* below)

## Variable and hook function.

Some variable will be pre-defined before execute/evaluate your spec file (do not edit these var):

| Variable name | Description |
| --- | --- |
| `dir` | The directory fullpath contain the spec file (may contain space) |
| `file` | The fullpath of the spec file (may contain space) |
| `dirname` | The directory name of spec file (name only, without path, may contain space) |
| `filename` | The name of the spec file (name only, without path, may contain space) |
| `dirsum` | The checksum of `$dir` calculated using `calc_cksum` (see below) function. Useful for avoiding name collision (see example for usage) |

You should define following variable:

| Variable name | Description |
| --- | --- |
| `image` (**required**) | image to be used for this container|
| `name`| name of the container, if you don't specify this var the value will be `$dirname-$filename-$dirsum` |
| `net`| If network not exists yet, it will be created for you. This network will be removed when last container attach to it removed. |
| `opts` | options to be used for this container, see `docker create --help` |
| `args` | argument to be used for this container, see `docker create --help` |
| `stop_opts` | options to be used for `docker stop`, see `docker stop --help` |
| `rm_opts` | options to be used for `docker rm`, see `docker rm --help` |
| `kill_opts` | options to be used for `docker kill`, see `docker kill --help` |
| `must_local` | If set to `y`, it will ensure docker daemon is running on local machine, useful if you want to use bind-mount. |
| `create_only` | If set to `y`, `start` command will only create the container, but won't run it. |
| `skip_real_pull` | If set to `y`, `pull` command will not run `docker pull` to pull the image |

*NOTE*: You can use `show_cmds` (see below) to see the final result of constructed argument.

*NOTE*: `opts`, `args`, `stop_opts`, `rm_opts`, `kill_opts` are processed with `quote` function (see below).

Hook function that you can define:

| Hook function | Description |
| --- | --- |
| `pre_start` | see `start` command below |
| `post_start`| see `start` command below |
| `pre_stop` | |
| `post_stop` | |
| `pre_restart` | |
| `post_restart` | |
| `pre_rm` | |
| `post_rm` | |
| `pre_pull` | |
| `post_pull` | |

## Predefined function

### `quote` function.
Because POSIX shell does't support array,
we provide `quote` function utility to serialize array so you can use it safely in `eval` and `set` to change `"$@"`.

example usage:

```sh
old_args=$(no_proc=y quote "$@")
new_args=$(quote "a b 'c d' \"e'f\"") || exit 1
eval "set -- $new_args"
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
quote a "'b" c d # will error: unmatched single quote
no_proc=y quote a "'b" c d # will print: 'a' ''\''b' 'c' 'd'
```

### `exists` function.
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

### `running` function.
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

### `calc_cksum` function.
This helper function is to calculate cheksum

example:
```sh
calc_cksum hai # will print: 11742952433
```

### `panic` function
Print arguments to stderr and exit with exitcode 1

### `main` function
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
  - `pre_start run` hook
  - `docker create ...`
  - `pre_start created` hook
  - `docker start ...`
  - `post_start run` hook

- If container already exists, but not started yet:
  - `pre_start start` hook
  - `docker start ...`
  - `post_start start` hook


### `stop`
Stop the container if not stopped. The container will be stoped based on `stop_opts` and/or any argument passed to this command. Only `-t`/`--time` are supported for now.

option from command line is also supported

example:

    ./nginx stop

or

    ./nginx stop -t 5

### `restart`
Restart the container. The container will be stoped based on `stop_opts` and/or any argument passed to this command. Only `-t`/`--time` are supported for now.

option from command line is also supported

### `rm`
Remove the container if exists. The container will be removed based on `rm_opts` and/or any argument passed to this. Only `-f`/`--force`, `-v`/`--volume`, `-l`/`--link` are supported for now.
Network defined on `net` will be removed if this container is the last container attach to that network.

option from command line is also supported

### `exec`
Exec command inside container.

example:

    ./nginx exec sh

### `exec_root`
Exec command inside container as root.

example:

    ./nginx exec sh

### `exec_as`
Exec program inside the container as specified user.

example:

    ./nginx exec_as nobody sh

### `kill`
Kill the container. The container will be stoped based on `kill_opts` and/or any argument passed to this command. Only `-s`/`--signal` are supported for now.

option from command line is also supported

### `logs`
Show logs of the container. Any argument passed to this command will used by underlying docker program.

option from command line is also supported

### `port`
Show port mapping of the container. Any argument passed to this command will used by underlying docker program.

option from command line is also supported

### `status`
Show container status, possibel output are any combination (in one line) of:
- `different_opts`
- `different_image`
- `restarting`
- `running`
- `starting`
- `not_running`
- `not_healthy`
- `no_container`

### `name`
Print `name`

### `image`
Print `image`

### `net`
Print `net`

### `show_cmds`
Show the final constructed arguments for underlying docker program.

example:

    ./nginx exec_as show_cmds

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

## Adding arbitary command.
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
