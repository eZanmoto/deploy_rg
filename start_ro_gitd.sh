#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <dir> <sess-id>` starts a "read-only" (only cloning and pulling permitted)
# Git daemon in the current directory and logs output to session directories for
# session `sess-id`.

set -o errexit

if [ $# -ne 2 ] ; then
    echo "usage: $0 <dir> <sess-id>" >&2
    exit 1
fi

dir=$1
sess_id=$2

var_dir=/var/tmp/gitd/"$sess_id"

mkdir --parents "$var_dir"

cd "$dir"

git \
    daemon \
    --verbose \
    --reuseaddr \
    --export-all \
    --base-path=. \
    &> "$var_dir/log" \
    &
