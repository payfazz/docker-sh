# Docker utility script

This is simple POSIX script for managing docker container, just like `docker-compose`.

Because this is POSIX shell script, the possibility is limitless

This script is written with POSIX shell standard, so it will work with `bash`, `ash`, `dash` or any shell that follow POSIX standard

## How to install

to install in default location (`/usr/local/bin/docker.sh`)

    curl -sSLf https://raw.githubusercontent.com/payfazz/docker-sh/master/install.sh | sudo sh

or to custom location, e.g. /opt/bin/docker.sh

    curl -sSLf https://raw.githubusercontent.com/payfazz/docker-sh/master/install.sh | sudo sh -s - /opt/bin/docker.sh


## How to use it
`docker.sh` will be used as interpreter, you need to install it in your `PATH` e.g. by copy `docker.sh` file to `/usr/local/bin` (`install.sh` will do this for you)

Create spec file
```sh
#!/usr/env/bin docker.sh

name=test_nginx
image=nginx:alpine
opts="
  -p 8080:80
"
```

then make it executable by `chmod 755`.

#### variable and hook function
The things you need to set/define in spec file:

- `name` (string)
- `image` (string)
- `net` (string, optional)
- `opts` (array, optional)
- `args` (array, optional)
- `stop_opts` (array, optional)
- `rm_opts` (array, optional)
- `kill_opts` (array, optional)
- `pre_start` (function, optional), first parameter set to `run` if container not exists or `start` if container already exists
- `post_start` (function, optional), first parameter set to `run` if container not exists or `start` if container already exists
- `pre_stop` (function, optional)
- `post_stop` (function, optional)
- `pre_restart` (function, optional)
- `post_restart` (function, optional)
- `pre_rm` (function, optional)
- `post_rm` (function, optional)

Some variable will be defined before execute your spec file:
- `dir` will set to directory contain spec file
- `file` will set to path of spec file
- `dirname` will set to directory name of spec file (name only, without path)
- `filename` will set to name of spec file (name only, without path)
- `dirsum` checksum of `dir`, you should use this to avoid name collision

if `name` is not specified, it will be set to `$dirname-$dirsum`.

#### `quote` function
because POSIX shell does't support array (actually It doest provide ONE array, the args, `"$@"`), I provide `quote` function utility, to convert string to quoted one so you can use it in `eval` and `set` command to modify `"$@"` safely
```sh
old_args=$(quote "$@")
eval "set -- $(quote "a b 'c d' \"e'f\"")"
for x; do echo ">$x<"; done
eval "set -- $old_args"
```
will print:
```
>a<
>b<
>c d<
>e'f<
```

read `docker.sh` file if you need more information


## Example

content of `postgres/app`:
```sh
#!/usr/bin/env docker.sh

image=postgres:9-alpine
net=net0
opts="
  --restart always
  -v '$dir/data:/var/lib/postgresql/data'
  -p 5432:5432
"
```

content of `pgadmin/app`:
```sh
#!/usr/bin/env docker.sh

vol_opts="
  -v '$dir/data:/pgadmin'
"

image=thajeztah/pgadmin4
net=net0
opts="
  --restart always
  $vol_opts
  -p 5050:5050
"

pre_start() (
  "$dir/../postgres/app" start || { echo 'failed to start postgres'; return 1; }
  if [ "${1:-}" = run ]; then
    # we need to chown the dir
    tmp=$(quote "$vol_opts") || return 1
    eval "set -- $tmp"
    docker run -it --rm \
      "$@" \
      -u 0:0 --entrypoint /bin/sh \
      "$image" -c 'chown pgadmin:pgadmin /pgadmin'
  fi
)
```
NOTE: Here i chown the folder before container start (can't be done with `docker-compose`)

don't forget to change permission so you can execute the script

    chmod 755 postgres/app pgadmin/app

now, you can run them with just on command

    pgadmin/app start


## TODO

* improve `quote`, for now, `quote` is very expensive, it can't be used for long string.
  it also mean that you cannot use long string in `opts` and `args` because internally it use `quote`
