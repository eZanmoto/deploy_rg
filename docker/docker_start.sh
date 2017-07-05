#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <frg> <priv_key> <cert> <cont-name> <https-port> <gitd-port> <wall-port>`
# starts a docker-based RepoGate deployment in a container. See `README.md` for
# details.

set -o errexit

if [ $# -ne 7 ] ; then
    echo "usage: $0 <frg> <priv_key> <cert> <cont-name> <https-port> <gitd-port> <wall-port>" >&2
    exit 1
fi

frg=$1
priv_key=$2
cert=$3
cont_name=$4
https_port=$5
gitd_port=$6
wall_port=$7

if [ ! -e "$priv_key" ] ; then
    if [ -e "$cert" ] ; then
        echo "'$priv_key' exists but '$cert' doesn't" >&2
        exit 1
    fi

    # https://www.ibm.com/support/knowledgecenter/en/SSWHYP_4.0.0/com.ibm.apimgmt.cmc.doc/task_apionprem_gernerate_self_signed_openSSL.html
    openssl \
        req \
        -newkey rsa:2048 \
        -nodes \
        -keyout "$priv_key" \
        -x509 \
        -days 365 \
        -out "$cert"
elif [ ! -e "$cert" ] ; then
    echo "'$cert' exists but '$priv_key' doesn't" >&2
    exit 1
fi

img_name=repogate/deploy
# https://stackoverflow.com/a/30543453/497142
if [ "$(docker images -q $img_name 2> /dev/null)" = "" ]; then
     docker build -t "$img_name" - < docker/Dockerfile.deploy
fi

echo -n "Please enter a master password: "
ES_PASSWORD="$(python get_pass.py)"

# We use the container name here as a "mutex".
docker \
    create \
    --interactive \
    --name="$cont_name" \
    --publish=$https_port:8080 \
    --publish=$wall_port:9000 \
    --publish=$gitd_port:9418 \
    --tty \
    --workdir='/home/repogate/deploy_rg' \
    "$img_name" \
    bash \
        -c \
        "
            set -o errexit

            # We run a 'sudo' command once to skip the warning that appears
            # before the first 'sudo' run.
            sudo true &>/dev/null

            sudo chown -R repogate:repogate /home/repogate/deploy_rg

            sess_id=\$(date '+%Y%m%d_%H%M%S')

            ES_PASSWORD='$ES_PASSWORD' bash \
                install_start.sh \
                \"\$PWD/frg\" \
                \"\$sess_id\"

            var_dir=\"/var/tmp/node/\$sess_id\"
            mkdir \
                --parents \
                /var/tmp/repo_update \
                \"\$var_dir\"
            ES_PASSWORD='$ES_PASSWORD' node \
                index.js \
                2>&1 \
                | tee \"\$var_dir/log\"
        "

docker cp . "$cont_name":/home/repogate/deploy_rg
docker cp "$frg" "$cont_name":/home/repogate/deploy_rg
docker cp "$priv_key" "$cont_name":/home/repogate/deploy_rg/privkey.pem
docker cp "$cert" "$cont_name":/home/repogate/deploy_rg/cert.pem

echo "Starting container..."
docker start "$cont_name" &

echo "Waiting for port $https_port to handle requests..."
echo "https://127.0.0.1:$https_port"
while ! curl -ksf "https://127.0.0.1:$https_port/" >/dev/null ; do
    sleep 1
done

echo "Ready."
