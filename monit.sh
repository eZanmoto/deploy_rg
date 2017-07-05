#!/bin/bash

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <sess-id>` tracks logging made by the RepoGate deployment session
# `sess-id`.

set -o errexit

if [ $# -ne 1 ] ; then
    echo "usage: $0 <sess-id>" >&2
    exit 1
fi

sess_id=$1

tail \
    --follow \
    /var/tmp/frg/$1/{lab,wall}/{out,err}.log \
    /var/tmp/gitd/$1/{out,err}.log
