#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <url>` pushes a test project to the empty (i.e. with no commits) hosted
# repository at `url`.
#
# This test repository is used for testing RepoGate deployments. See `README.md`
# for details.

set -o errexit

if [ $# -ne 1 ] ; then
    echo "usage: $0 <url>" >&2
    exit 1
fi

url="$1"

cwd=$PWD
cd $(mktemp --directory)
git init
echo 0 > VERSION
bash "$cwd/rg_init.sh"
echo 'cat VERSION' > .rg/test
git add .
git commit -m "Initial commit"
git remote add origin "$1"
git push -u origin master
