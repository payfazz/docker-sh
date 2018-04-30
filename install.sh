#!/bin/sh

set -eu

download=y

if [ "$(basename "$0")" = "install.sh" ]; then
    file="$(dirname "$0")/docker.sh"
    if [ -f "$file" ]; then
        cp "$file" /usr/local/bin/docker.sh && download=n
    fi
fi

[ $download = y ] && curl -sSLfo /usr/local/bin/docker.sh https://raw.githubusercontent.com/payfazz/docker-sh/master/docker.sh
chmod 755 /usr/local/bin/docker.sh

exit 0
