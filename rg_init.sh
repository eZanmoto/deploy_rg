#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0` initialises a repository as a RepoGate project.
#
# This script should be run in the root directory of the repository.

set -o errexit

if [ $# -ne 0 ] ; then
    echo "usage: $0" >&2
    exit 1
fi

rg_dir=".rg"
mkdir --parents "$rg_dir"
echo -n 'local' > "$rg_dir/env"
echo -n '' > "$rg_dir/envspec"
echo '' > "$rg_dir/test"
