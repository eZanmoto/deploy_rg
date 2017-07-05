#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <run-dir> <sess-id> <frg>` starts `frg` in `run-dir` and logs output to
# session directories for session `sess-id`.

set -o errexit

if [ $# -ne 3 ] ; then
    echo "usage: $0 <run-dir> <sess-id> <frg>" >&2
    exit 1
fi

run_dir="$1"
sess_id="$2"
frg="$3"

cd "$run_dir"

var_dir=/var/tmp/frg/"$sess_id"

mkdir --parents "$var_dir"/{wall,lab}/tmp

lab_var_dir="$var_dir"/lab
"$frg" \
    --tmp-dir="$lab_var_dir"/tmp \
    --git-port=9002 \
    lab \
    --listen=127.0.0.1:9001 \
    &> "$lab_var_dir/log" \
    &

wall_var_dir="$var_dir"/wall
"$frg" \
    --tmp-dir="$wall_var_dir"/tmp \
    --git-port=9003 \
    wall \
    --lab=127.0.0.1:9001 \
    --listen=0.0.0.0:9000 \
    &> "$wall_var_dir/log" \
    &
