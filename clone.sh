#!/bin/sh

# Copyright 2017 Sean Kelleher. All rights reserved.

# `$0 <git-host> <user> <project> <user-pass-env-var> <log>` bare clones the
# `<user>/<project>` repository from `<git-host>` using the `username:password`
# pair found in the environment variable named `<user-pass-env-var>`.
#
# The environment variable named `<user-pass-env-var>` is used to push updates
# back to the remote repository whenever updates are pushed to the cloned
# repository. Errors encountered when pushing updates to the remote repository
# are appended to `<log>`.

set -o errexit

if [ $# -ne 6 ] ; then
    echo "usage: $0 <git-host> <user> <project> <es-password-env-var> <log> <pass-file>" >&2
    exit 1
fi

git_host=$1
user=$2
project=$3
es_password_env_var=$4
log=$5
pass_file=$6

user_pass=$(
    bash \
        "$(dirname $0)/es-get.sh" \
        ${!es_password_env_var} \
        "$pass_file" \
        "$project"
)

url="$git_host/$user/$project.git"

git \
    clone \
    -v \
    --bare \
    "https://$user_pass@$url" \
    "$project" \
    2>&1 \
    | sed "s/\$user_pass/___:___/" \
    &> "$log"

cat <<-EOF > "$project/hooks/post-update"
#!/bin/sh

if [ -z "\$$es_password_env_var" ] ; then
    echo '\`\$$es_password_env_var\` is empty' > '$log'
    exit 1
fi

user_pass=\$(
    bash \\
        "$(dirname $0)/es-get.sh" \\
        \$$es_password_env_var \\
        "$pass_file" \\
        "$project"
)

git \\
    push \\
    "https://\$user_pass@$url" \\
    master \\
    2>&1 \\
    | sed "s/\$user_pass/___:___/" \\
    >> '$log'
EOF
chmod +x $project/hooks/post-update
