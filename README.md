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

see [full documentation](./DOCS.md) for more.

## Getting Started

Lets say you want to start wordpress project, using mariadb as database.
```sh
mkdir my-project
cd my-project
```

we need to create two spec file, unlike `docker-compose`, one spec file is used to control one container,
so we need to create two files

create file `wordpress` with following content:
```sh
#!/usr/bin/env docker.sh

name=wordpress
image=wordpress:latest
net=net-wordpress
opts="
  -p 8080:80
  -v wordpress-data:/var/www/html
  -e WORDPRESS_DB_HOST=mariadb
  -e WORDPRESS_DB_PASSWORD=password
"
```

create file `mariadb` with following content:
```sh
#!/usr/bin/env docker.sh

name=mariadb
image=mariadb:latest
net=net-wordpress
opts="
  -v mariadb-data:/var/lib/mysql
  -e MYSQL_ROOT_PASSWORD=password
"
```

Please note that `wordpress` and `mariadb` must have same `net` value so each container can communicate

then, make those two file executable by running
```sh
chmod +x wordpress mariadb
```

and start the the container by running:
```sh
./mariadb start
./wordpress start
```

and done. You can access wordpress on http://localhost:8080


## Use it with ansible

We also provide ansible module for this script, see inside [ansible_module](./ansible_module/README.md) directory.

## TODO

- Automated testing
