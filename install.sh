#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <user>` installs infrastructure for repogate deployments for `<user>`.
#
# This script assumes that `<user>` is a member of a group of the same name and
# has `/home/<user>` as their home directory.

if [ $# -ne 1 ] ; then
    echo "usage: $0 <user>" >&2
    exit 1
fi

user=$1

install \
    --owner="$user" \
    --group="$user" \
    --mode=0744 \
    --directory \
    "/home/$user/scripts"

install \
    --owner="$user" \
    --group="$user" \
    --mode=0644 \
    -D \
    clone.sh \
    es-add.sh \
    es-get.sh \
    es-rm.sh \
    es-show.sh \
    monit.sh \
    rg_init.sh \
    start_frg.sh \
    start_ro_gitd.sh \
    "/home/$user/scripts"

install \
    --owner="$user" \
    --group="$user" \
    --mode=0744 \
    -D \
    git \
    "/home/$user/bin/git"

install \
    --owner="$user" \
    --group="$user" \
    --mode=0744 \
    --directory \
    "/home/$user/repos"
