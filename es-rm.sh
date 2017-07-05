#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <password> <file> <key>` removes the value stored under `<key>` in the
# `<file>` encrypted with `<password>`.

set -o errexit

if [ $# -ne 3 ] ; then
    echo "usage: $0 <password> <file> <key>" >&2
    exit 1
fi

pass=$1
file=$2
key=$3

if [ ! -e "$file" ] ; then
    echo -n '' | \
        openssl \
            aes-128-cbc \
            -salt \
            -out "$file" \
            -k "$pass"
fi

tempf=$(mktemp)
openssl \
    aes-128-cbc \
    -salt \
    -in <(grep \
            -v \
            "^$key:" \
            <(openssl \
                    aes-128-cbc \
                    -d \
                    -salt \
                    -in "$file" \
                    -k "$pass") \
        ) \
  -out "$tempf" \
  -k "$pass"
mv "$tempf" "$file"
