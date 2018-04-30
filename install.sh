#!/bin/sh

set -eux

curl -sSLfo /usr/local/bin/docker.sh https://raw.githubusercontent.com/payfazz/docker-sh/master/docker.sh
chmod 755 /usr/local/bin/docker.sh

exit 0
