#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <http|https> <out-dir> <domains>` generates Let's Encrypt credentials for
# a list of comma-separated `domains` to `out-dir` using the local `http` or
# `https` port of the current host, which must be reachable using `domains`.

set -o errexit

if [ $# -ne 3 ] ; then
    echo "usage: $0 <http|https> <out-dir> <domains>" >&2
    exit 1
fi

method=$1
out_dir=$2
domains=$3

port=80
if [ "$method" == "https" ] ; then
    method='tls-sni'
    port=443
elif [ "$method" != "http" ] ; then
    echo "usage: $0 <http|https> <out-dir> <domains>" >&2
    exit 1
fi

img_name=repogate/letsencrypt

# https://stackoverflow.com/a/30543453/497142
if [ "$(docker images -q $img_name 2> /dev/null)" = "" ]; then
     docker build -t "$img_name" - < docker/Dockerfile.letsencrypt
fi

cont_id=$(
    docker \
        create \
        --interactive \
        --name="$cont_name" \
        --publish=$port:$port \
        --tty \
        "$img_name" \
        bash \
            -c \
            "
                /certbot-auto \
                    certonly \
                    --standalone \
                    --preferred-challenges '$method' \
                    --no-bootstrap \
                    --verbose \
                    --register-unsafely-without-email \
                    --non-interactive \
                    --agree-tos \
                    --domains '$domains' \
            "
)

trap 'echo "Removed container $(docker rm $cont_id)"' EXIT

docker start -ai "$cont_id"

docker cp "$cont_id":/etc/letsencrypt "$out_dir"
