#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <frg> <test_proj_host_user> <test_proj_host> <test_proj_user>
# <test_proj_name>` starts and tests a local RepoGate deployment. See
# `README.md` for details.

set -o errexit

if [ $# -ne 5 ] ; then
    echo "usage: $0 <frg> <test_proj_host_user> <test_proj_host> <test_proj_user> <test_proj_name>" >&2
    exit 1
fi

frg="$1"
test_proj_host_user="$2"
test_proj_host="$3"
test_proj_user="$4"
test_proj_name="$5"

img_name=repogate/deploy_test

# https://stackoverflow.com/a/30543453/497142
if [ "$(docker images -q $img_name 2> /dev/null)" = "" ]; then
     docker build -t "$img_name" - < docker/Dockerfile.test
fi

cont_id=$(
    docker \
        create \
        --interactive \
        --tty \
        --workdir='/home/dev/deploy_rg' \
        "$img_name" \
        bash \
            -c \
            "
                set -o errexit

                # We run a 'sudo' command once to skip the warning that appears
                # before the first 'sudo' run.
                sudo true &>/dev/null

                sudo \
                    useradd \
                    --password='' \
                    --create-home \
                    repogate

                sudo \
                    bash \
                    install_start_test.sh \
                    \"\$PWD/frg\" \
                    $(date '+%Y%m%d_%H%M%S') \
                    \"$test_proj_host_user\" \
                    \"$test_proj_host\" \
                    \"$test_proj_user\" \
                    \"$test_proj_name\" \
            "
)

trap 'echo "Removed container $(docker rm $cont_id)"' EXIT

docker cp . "$cont_id":/home/dev/deploy_rg
docker cp "$frg" "$cont_id":/home/dev/deploy_rg

docker start --attach --interactive "$cont_id"
