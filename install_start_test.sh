#!/bin/bash

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <frg> <sess-id> <test_proj_host_user> <test_proj_host> <test_proj_user>
# <test_proj_name>` installs, starts and tests a RepoGate deployment.

# FIXME The password read from the user is passed as a command-line argument to
# scripts. It would be better to use a combination of Python's `getpass` and
# `expect` to pass the passwords to each script so that passwords aren't exposed
# by passing `-x` to this script.

set -o errexit

if [ $# -ne 6 ] ; then
    echo "usage: $0 <frg> <sess-id> <test_proj_host_user> <test_proj_host> <test_proj_user> <test_proj_name>" >&2
    exit 1
fi

frg=$1
sess_id=$2
test_proj_host_user=$3
test_proj_host=$4
test_proj_user=$5
test_proj_name=$6

bash install.sh repogate

echo -n "Please enter a master password: "
ES_PASSWORD="$(python get_pass.py)"

echo -n "Please enter password for 'https://$test_proj_host_user@$test_proj_host': "
test_proj_host_userpass="$test_proj_host_user:$(python get_pass.py)"

rg_home='/home/repogate'
test_repo_log_dir='/var/tmp/repo_update/test'

su - repogate bash -c "
    set -o errexit

    cd '$rg_home'
    echo '$sess_id' > cur_sess.txt

    bash \
        scripts/start_ro_gitd.sh \
        '$rg_home/repos' \
        '$sess_id'

    ES_PASSWORD='$ES_PASSWORD' PATH='$rg_home/bin:$PATH' bash \
        '$rg_home/scripts/start_frg.sh' \
        '$rg_home/repos' \
        '$sess_id' \
        '$frg'

    mkdir --parents '$test_repo_log_dir'

    bash \
        '$rg_home/scripts/es-add.sh' \
        '$ES_PASSWORD' \
        '$rg_home/repos_pass.aes' \
        '$test_proj_name' \
        '$test_proj_host_userpass'

    cd '$rg_home/repos'

    ES_PASSWORD='$ES_PASSWORD' bash \
        '$rg_home/scripts/clone.sh' \
        '$test_proj_host' \
        '$test_proj_user' \
        '$test_proj_name' \
        ES_PASSWORD \
        '$test_repo_log_dir/$sess_id.log' \
        '$rg_home/repos_pass.aes'
"

trap "
    # FIXME This is a hacky way of terminating the processes started in
    # 'follow.sh' because it can kill more than just those processes.
    pkill tail
" EXIT

names=('lab ' 'wall' 'gitd')
dirs=("frg/$sess_id/lab" "frg/$sess_id/wall" "gitd/$sess_id")
for i in $(seq 0 2); do
    tail -f "/var/tmp/${dirs[$i]}/log" | sed "s/^/[${names[$i]}] /" &
done
tail -f "$test_repo_log_dir/$sess_id.log" | sed "s/^/[proj] /" &

var_dir="/var/tmp/repos/$sess_id"
src_repo="$var_dir/1"
mkdir --parent "$src_repo"
git clone git://127.0.0.1/"$test_proj_name" "$src_repo"
(
    cd "$src_repo"
    expr $(cat VERSION) + 1 > VERSION
    git add .
    git commit -m $(cat VERSION)
    PATH="$rg_home/bin:$PATH" \
            "$frg" \
            push \
            --proj="$test_proj_name" \
            --wall=127.0.0.1:9000 \
            2>&1 | sed -e 's/^/[push] /'
)

tgt_repo="$var_dir/2"
git \
    clone \
    "https://$test_proj_host_userpass@$test_proj_host/$test_proj_user/$test_proj_name.git" \
    "$tgt_repo"

diff \
    "$src_repo" \
    "$tgt_repo"
