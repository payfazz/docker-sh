# Docker utility script

This is simple POSIX script for managing docker container, just like `docker-compose` for single container, but more powerful.

Because this is POSIX shell script, the possibility is limitless.

This approach is inspired by openrc from gentoo, ebuild from gentoo, PKGBUILD from archlinux, and APKBUILD from alpine.

This script is written with POSIX shell standard, so it will work with `bash`, `ash`, `dash` or any shell that follow POSIX standard.

## How to install

To install in default location (`/usr/local/bin/docker.sh`)

    curl -sSLf https://raw.githubusercontent.com/payfazz/docker-sh/master/install.sh | sudo sh

or to custom location, e.g. `/opt/bin/docker.sh`

    curl -sSLf https://raw.githubusercontent.com/payfazz/docker-sh/master/install.sh | sudo sh -s - /opt/bin/docker.sh


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

then make it executable by `chmod 755 nginx`, after that, you can run this file, `./nginx help` will give you more info.

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

*NOTE*: `opts`, `args`, `stop_opts`, `rm_opts`, `kill_opts` are processed with `quote` function (see below).


Hook function:
- `pre_start`,
  If container not exists it will called twice, first `pre_start run` before the container created,
  second `pre_start created` after the container created but before the container started.
  If container already exists but not running, `pre_start start` will be called.
  It will not be called if container already running.
- `post_start`,
  If container not exsits `post_start run` will be called after container running.
  If container already exists but not running,`post_start start` will be called.
  It will not be called if container already running.
- `pre_stop`
- `post_stop`
- `pre_restart`
- `post_restart`
- `pre_rm`
- `post_rm`
- `pre_pull`
- `post_pull`

Some variable will be defined before execute your spec file:
- `$dir`,
  The directory path contain the spec file.
- `$file`,
  The path of the spec file.
- `$dirname`,
  The directory name of spec file (name only, without path).
- `$filename`,
  The name of the spec file (name only, without path).
- `$dirsum`,
  The checksum of `$dir`. Useful for avoiding name collision.

If `name` is not specified in the spec file, it will be `$dirname-$filename-$dirsum`.

*NOTE*: You can use`show_cmds` to see the final result of constructed argument.

#### `quote` function.
Because POSIX shell does't support array (actually tt does provide ONE array, the args, `"$@"`),
We provide `quote` function utility, to safely convert string to quoted one so you can use it in `eval` and `set` command to modify `"$@"`.
```sh
old_args=$(quote "$@")
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

command_reload() (
  "$file" exec nginx -s reload
)
```

`./nginx reload` will be available.


## Example

content of `postgres/app`:
```sh
#!/usr/bin/env docker.sh

image=postgres:9-alpine
net=net0
opts="
  --network-alias postgres
  --restart always
  -v '$dir/data:/var/lib/postgresql/data'
  -p 5432:5432
"
```

content of `pgadmin/app`:
```sh
#!/usr/bin/env docker.sh

image=thajeztah/pgadmin4
net=net0
opts_vol="-v '$dir/data:/pgadmin'"
opts="
  --restart always
  $opts_vol
  -p 5050:5050
"

pre_start() (
  "$dir/../postgres/app" start || { echo 'failed to start postgres'; return 1; }
  if [ "${1:-}" = run ]; then
    # we need to chown the dir
    tmp=$(quote "$opts_vol") || return 1
    eval "set -- $tmp"
    docker run -it --rm \
      "$@" \
      -u 0:0 --entrypoint /bin/sh \
      "$image" -c 'chown pgadmin:pgadmin /pgadmin'
  fi
)
```
*NOTE*: Because we use bind-mount, `pgadmin` will be owned by root. Here I chown the directory before container start.

Change the permission so you can execute the script

    chmod 755 postgres/app pgadmin/app

now, you can run them with just one command

    pgadmin/app start

## TODO
- Automated testing
