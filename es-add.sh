#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <password> <file> <key> <value>` adds `<value>` under `<key>` to a
# `<file>` encrypted with `<password>`.

set -o errexit

if [ $# -ne 4 ] ; then
    echo "usage: $0 <password> <file> <key> <value>" >&2
    exit 1
fi

pass=$1
file=$2
key=$3
value=$4

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
    -in <(cat \
            <(echo "$key:$value") \
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
