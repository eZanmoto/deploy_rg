#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <password> <file> <key>` outputs the value stored under `<key>` in the
# `<file>` encrypted with `<password>`.

set -o errexit

if [ $# -ne 3 ] ; then
    echo "usage: $0 <password> <file> <key>" >&2
    exit 1
fi

pass=$1
file=$2
key=$3

bash $(dirname $0)/es-show.sh "$pass" "$file" \
    | grep "^$key:" \
    | sed -s "s@^$key:@@"
