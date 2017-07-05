#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <password> <file>` outputs the contents of a `<file>` encrypted with
# `<password>`.

set -o errexit

if [ $# -ne 2 ] ; then
    echo "usage: $0 <password> <file>" >&2
    exit 1
fi

pass=$1
file=$2

openssl \
    aes-128-cbc \
    -d \
    -salt \
    -in "$file" \
    -k "$pass"
