#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <frg> <priv-key> <cert> <test-proj-host-user> <test-proj-host>
# <test-proj-user> <test-proj-name>` starts and tests a docker-based RepoGate
# deployment in a container. See `README.md` for details.

set -o errexit

if [ $# -ne 7 ] ; then
    echo "usage: $0 <frg> <priv-key> <cert> <test-proj-host-user> <test-proj-host> <test-proj-user> <test-proj-name>" >&2
    exit 1
fi

frg=$1
priv_key=$2
cert=$3
test_proj_host_user=$4
test_proj_host=$5
test_proj_user=$6
test_proj_name=$7
sess_id=debug

echo -n "Please enter password for 'https://$test_proj_host_user@$test_proj_host': "
test_proj_host_pass="$(python get_pass.py)"

cont_name=repogate_deploy
trap '
    echo "Stopping container..."
    echo "Stopped container $(docker stop $cont_name)"
    docker logs $cont_name | sed "s/^/[logs][*]/"
    echo "Removing container..."
    echo "Removed container $(docker rm $cont_name)"
' EXIT

https_port=10001
gitd_port=10002
wall_port=10003
bash \
    docker/docker_start.sh \
    "$frg" \
    "$priv_key" \
    "$cert" \
    "$cont_name" \
    "$https_port" \
    "$gitd_port" \
    "$wall_port"

function matchFirstLink() {
    link=$(curl -ksSL "$1" \
        | grep '<a href' \
        | sed -e 's|.*href="\([^"]*\)".*|\1|')
    match "$1$link" "$2"
}

function match() {
    echo -n "Checking '$1'... "
    output=$(curl -ksSL $3 "$1")
    # See 'https://stackoverflow.com/a/8550395/497142' for details on using
    # `paste` with `read`.
    # See 'https://stackoverflow.com/a/2188223/497142' for details on using
    # braces to run a sequence of commands in the current shell context.
    # We use a hacky combination of `return 1`, `&& echo "PASS" || true` to
    # short-circuit the loop.
    paste -d"\n" <(echo "$2") <(echo "$output") \
        | while read -r tgt && read -r src ; do
            grep -z "^$tgt$" <(echo -n "$src") >/dev/null \
                || {
                    printf "FAIL\n    Unexpected output for '$1':\n"
                    printf "    ('$src' !~ '$tgt')\n"
                    sed 's/^/        /' <(echo "$output")
                    return 1
                }
        done \
        && echo "PASS" \
        || true
}

match \
    "https://127.0.0.1:$https_port/" \
    '<a href="projects">Projects</a><ul><li><a href="gitd">Git Logs</a></li><li><a href="wall">Wall Logs</a></li><li><a href="lab">Lab Logs</a></li><li><a href="node">Node Logs</a></li></ul>'

match \
    "https://127.0.0.1:$https_port/gitd" \
    '<ul><li><a href="?sess_id=[0-9]*_[0-9]*">[0-9]*_[0-9]*</a></li></ul>'

matchFirstLink \
    "https://127.0.0.1:$https_port/gitd" \
    '<pre>\[[0-9]*\] Ready to rumble
</pre>'

match \
    "https://127.0.0.1:$https_port/wall" \
    '<ul><li><a href="?sess_id=[0-9]*_[0-9]*">[0-9]*_[0-9]*</a></li></ul>'

matchFirstLink \
    "https://127.0.0.1:$https_port/wall" \
    '<pre>Listening
</pre>'

match \
    "https://127.0.0.1:$https_port/lab" \
    '<ul><li><a href="?sess_id=[0-9]*_[0-9]*">[0-9]*_[0-9]*</a></li></ul>'

matchFirstLink \
    "https://127.0.0.1:$https_port/lab" \
    '<pre>Listening
</pre>'

match \
    "https://127.0.0.1:$https_port/projects" \
    '<a href="projects/add">Add</a><ul></ul>' \

match \
    "https://127.0.0.1:$https_port/projects/add" \
    "<script>document.location=\"/projects?name=$test_proj_name\";</script>" \
    "--data username=$test_proj_host_user&password=$test_proj_host_pass&host=$test_proj_host&user=$test_proj_user&project=$test_proj_name"

match \
    "https://127.0.0.1:$https_port/projects" \
    "<a href=\"projects/add\">Add</a><ul><li><a href=\"?name=$test_proj_name\">$test_proj_name</a></li></ul>"

match \
    "https://127.0.0.1:$https_port/projects?name=$test_proj_name" \
    "<p><a href=\"projects/logs?name=$test_proj_name\">Logs</a></p><p><a href=\"projects/delete?name=$test_proj_name\">Delete</a></p>"

match \
    "https://127.0.0.1:$https_port/projects/logs" \
    "<ul><li><a href=\"?name=$test_proj_name\">$test_proj_name</a></li></ul>"

match \
    "https://127.0.0.1:$https_port/projects/logs?name=$test_proj_name" \
    "<pre>Cloning into bare repository '$test_proj_name'...
POST git-upload-pack ([0-9]* bytes)
</pre>"

match \
    "https://127.0.0.1:$https_port/projects/delete" \
    "<ul><li><a href=\"?name=$test_proj_name\">$test_proj_name</a></li></ul>"

match \
    "https://127.0.0.1:$https_port/projects/delete?name=$test_proj_name" \
    '<script>document.location="/projects";</script>'

match \
    "https://127.0.0.1:$https_port/projects" \
    '<a href="projects/add">Add</a><ul></ul>'

match \
    "https://127.0.0.1:$https_port/node" \
    '<ul><li><a href="?sess_id=[0-9]*_[0-9]*">[0-9]*_[0-9]*</a></li></ul>'

matchFirstLink \
    "https://127.0.0.1:$https_port/node" \
    '<pre></pre>'

match \
    "https://127.0.0.1:$https_port/projects/add" \
    "<script>document.location=\"/projects?name=$test_proj_name\";</script>" \
    "--data username=$test_proj_host_user&password=$test_proj_host_pass&host=$test_proj_host&user=$test_proj_user&project=$test_proj_name"

var_dir="/var/tmp/repos/$sess_id"

# TODO Remove.
rm -rf "$var_dir"

src_repo="$var_dir/1"
mkdir --parent "$src_repo"
echo -n 'Cloning from container... '
git clone git://127.0.0.1:$gitd_port/"$test_proj_name" "$src_repo" \
    &>/dev/null \
    && echo 'PASS' \
    || echo 'FAIL'
(
    cd "$src_repo"
    expr $(cat VERSION) + 1 > VERSION
    git add .
    git commit -m $(cat VERSION) \
        &>/dev/null
    echo -n 'Pushing changes with `frg`... '
    PATH="$rg_home/bin:$PATH" \
        "$frg" \
        push \
        --proj="$test_proj_name" \
        --wall=127.0.0.1:$wall_port \
        2>&1 | sed -e 's/^/[push][*]/' \
        &>/dev/null \
        && echo 'PASS' \
        || echo 'FAIL'
)

echo -n 'Cloning from origin... '
tgt_repo="$var_dir/2"
git \
    clone \
    "https://$test_proj_host_user:$test_proj_host_pass@$test_proj_host/$test_proj_user/$test_proj_name.git" \
    "$tgt_repo" \
    &>/dev/null \
    && echo 'PASS' \
    || echo 'FAIL'

echo -n 'Asserting that changes were pushed successfully... '
diff \
    "$src_repo" \
    "$tgt_repo" \
    &>/dev/null \
    && echo 'PASS' \
    || echo 'FAIL'

matchFirstLink \
    "https://127.0.0.1:$https_port/gitd" \
    "<pre>\\[[0-9]*\\] Ready to rumble
\\[[0-9]*\\] Connection from .*:.*
\\[[0-9]*\\] Extended attributes ([0-9]* bytes) exist <host=.*:.*>
\\[[0-9]*\\] Request upload-pack for ./$test_proj_name.
\\[[0-9]*\\] \\[[0-9]*\\] Disconnected
</pre>"

matchFirstLink \
    "https://127.0.0.1:$https_port/wall" \
    "<pre>Listening
.* .* (req 0) accepted client connection from 'tcp:.*:.*' to 'tcp:.*:9000'
.* .* (req 0) client is running version 1 of the rg protocol
.* .* (req 0) client pushing to '$test_proj_name' project
.* .* (req 0) found project
.* .* (req 0) created temporary repo '/var/tmp/frg/.*/wall/tmp/clones/.*'
.* .* (req 0) cloned repo locally
.* .* (req 0) got changes from client
.* .* (req 0) connected to lab at 'tcp:127.0.0.1:9001' from 'tcp:.*:.*'
.* .* (req 0) lab is running version 1 of the rg protocol
.* .* (req 0) cloned updated repository to lab
.* .* (req 0) streamed output to lab
.* .* (req 0) sent test result '' to client
.* .* (req 0) committed changes
.* .* (req 0) sent commit result 'pushed' to client
.* .* (req 0) done
</pre>"

matchFirstLink \
    "https://127.0.0.1:$https_port/lab" \
    "<pre>Listening
.* .* (req 0) accepted connection from 'tcp:.*:.*' to 'tcp:127.0.0.1:9001'
.* .* (req 0) wall is running version 1 of the rg protocol
.* .* (req 0) cloned repo
.* .* (req 0) opened repo
.* .* (req 0) got repo root
.* .* (req 0) read execution environment: 'local'
.* .* (req 0) confirmed 'local' as a valid execution environment
.* .* (req 0) read environment specification: ''
.* .* (req 0) read test specification
.* .* (req 0) opened output stream
.* .* (req 0) finished running tests with result ''
.* .* (req 0) done
</pre>"

match \
    "https://127.0.0.1:$https_port/projects/logs?name=$test_proj_name" \
    "<pre>Cloning into bare repository '$test_proj_name'...
POST git-upload-pack ([0-9]* bytes)
To https://___:___@$test_proj_host/$test_proj_user/$test_proj_name.git
   .*\\.\\..*  master -> master
</pre>"

match \
    "https://127.0.0.1:$https_port/projects/delete?name=$test_proj_name" \
    '<script>document.location="/projects";</script>'

matchFirstLink \
    "https://127.0.0.1:$https_port/node" \
    '<pre></pre>'
