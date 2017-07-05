#!/bin/bash

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <frg> <sess-id> <test_proj_host_user> <test_proj_host> <test_proj_user>
# <test_proj_name>` installs, starts and tests a RepoGate deployment.

# FIXME The password read from the user is passed as a command-line argument to
# scripts. It would be better to use a combination of Python's `getpass` and
# `expect` to pass the passwords to each script so that passwords aren't exposed
# by passing `-x` to this script.

set -o errexit

if [ $# -ne 2 ] ; then
    echo "usage: $0 <frg> <sess-id>" >&2
    exit 1
fi

frg=$1
sess_id=$2

bash install.sh repogate

rg_home='/home/repogate'
repo_log_dir='/var/tmp/repo_update'

# Start services
# Clone test project from bitbucket
su - repogate bash -c "
    set -o errexit

    cd '$rg_home'
    echo '$sess_id' > cur_sess.txt

    bash \
        scripts/start_ro_gitd.sh \
        '$rg_home/repos' \
        '$sess_id'

    ES_PASSWORD='$ES_PASSWORD' PATH='$rg_home/bin:$PATH' bash \
        scripts/start_frg.sh \
        '$rg_home/repos' \
        '$sess_id' \
        '$frg'

    mkdir --parents '$repo_log_dir'
"
