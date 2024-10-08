#!/bin/bash

# Copyright (c) 2024 Tim Perkins

# Permission is hereby granted, free of charge, to any person obtaining a copy of
# this software and associated documentation files (the “Software”), to deal in
# the Software without restriction, including without limitation the rights to
# use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
# the Software, and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:

# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.

# THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
# FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
# COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
# IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
# CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

set -o errexit
set -o nounset
set -o pipefail
IFS=$'\n\t'

ARCH=$(dpkg --print-architecture)
REGCTL_URL="https://github.com/regclient/regclient/releases/latest/download/regctl-linux-$ARCH"

# Usage: show_usage
#
# Prints help message for this script.
show_usage() {
    cat <<EOF >&2
Usage: $(basename "$0") [-f | --file DOCKERFILE] [-b | --base BASE_IMAGE]
            [-a | --arg BUILD_ARG] [-s | --secret SECRET] [-j | --only-pull]
            [-o | --skip-pull] [-p | --push] [-u | --user USER] [-r | --pass PASS]
            [-k | --no-cache] [-n | --name] [-l | --log] [-q | --quiet]
            [-x | --github ] [-z | --script] [-h | --help]
            TARGET_IMAGE [CONTEXT_DIR]

Build (or not build) a Docker image named TARGET_IMAGE, i.e.,
'[REG/][NS/**/]REPO[:TAG]', using CONTEXT_DIR as the context.

    -f | --file DOCKERFILE  Dockerfile to use for the build
    -b | --base BASE_IMAGE  Base image to use for the build
    -a | --arg BUILD_ARG    A build argument, e.g., 'NAME=VALUE'
    -s | --secret SECRET    A secret argument, e.g., 'NAME=VALUE'
    -j | --only-pull        Only pull the image, don't build
    -o | --skip-pull        Just exit instead of pulling remote images
    -p | --push             Push the newly built container
    -u | --user USER        User to use during registry login
    -r | --pass PASS        Password or token to use during registry login
    -k | --no-cache         Build without using cache
    -n | --name             Display the name of the image only
    -l | --log              Display plain progress during build
    -q | --quiet            Display only essential information
    -x | --github           Operate in GitHub mode
    -z | --script           Operate in script mode
    -h | --help             Display this help message
EOF
}

# Usage: group ARGS
#
# Start an ouptut group if in GitHub mode.
group() {
    if [ "$github_mode" -ne 0 ]; then
        echo "::group::$*" >&2
    fi
}

# Usage: endgroup
#
# End an ouptut group if in GitHub mode.
endgroup() {
    if [ "$github_mode" -ne 0 ]; then
        echo "::endgroup::" >&2
    fi
}

# Usage: err_echo ARGS
#
# Same as echo, but for error messages.
err_echo() {
    if [ "$github_mode" -eq 0 ]; then
        echo -n "ERROR: " >&2
    else
        echo -n "::error::" >&2
    fi
    echo "$@" >&2
}

# Usage: warn_echo ARGS
#
# Same as echo, but for warning messages.
warn_echo() {
    if [ "$github_mode" -eq 0 ]; then
        echo -n "WARNING: " >&2
    else
        echo -n "::warning::" >&2
    fi
    echo "$@" >&2
}

# Usage: remove_empty ARRAYREF
#
# Remove empty elements from the given array.
remove_empty() {
    declare -n arrayref=$1
    local array=()
    local element
    for element in "${arrayref[@]}"; do
        if echo "$element" | grep -q '^[[:space:]]*$'; then
            continue
        fi
        array+=("$element")
    done
    arrayref=("${array[@]}")
}

# Usage: truthy_to_num STR [DEFAULT]
#
# Converts a "truthy" string to an number, either 0 or 1.
truthy_to_num() {
    case "$1" in
        [Yy]|[Yy][Ee][Ss]|[Tt]|[Tt][Rr][Uu][Ee]|1) echo 1;;
        [Nn]|[Nn][Oo]|[Ff]|[Fs][Aa][Ll][Ss][Ee]|0) echo 0;;
        *) truthy_to_num "${2:-0}" 0;;
    esac
}

# Usage: num_to_bool
#
# Converts a number to a "true" or "false" sting.
num_to_bool() {
    if [ "${1:-0}" -ne 0 ]; then
        echo "true"
    else
        echo "false"
    fi
}

# Usage: stat_name_xf
#
# For the given file, output the name and either an "x" if the file is
# exectable, or "f" if it is not.
stat_name_xf() {
    echo "$1:$(stat -c '%A' "$1" | cut -c 4 | tr '-' 'f')"
}

# Usage: md5sum_dir_contents DIR
#
# Get the combined MD5 sum of every file in a directory.
md5sum_dir_contents() {
    local target_dir=$1
    local target_files stat_file
    readarray -t target_files < <(cd "$target_dir" && find . -type f | LC_ALL=C sort)
    # Enumerate file names and permissions (like exectable bit)
    stat_file=$(mktemp)
    local target_file
    for target_file in "${target_files[@]}"; do
        (cd "$target_dir" && stat_name_xf "$target_file") >> $stat_file
    done
    # Hash everything, including the generated file
    target_files+=($stat_file)
    (cd "$target_dir" && cat "${target_files[@]}") | md5sum - | cut -d ' ' -f 1
}

# Default options
target_image=""
context_dir=$PWD
dockerfile="Dockerfile"
base_image=""
build_args=()
secrets=()
only_pull=0
skip_pull=0
do_push=0
registry_user=${REGISTRY_USER:-}
registry_pass=${REGISTRY_PASS:-}
no_cache=0
show_name=0
show_log=0
quiet_mode=0
github_mode=0
script_mode=0

# Convert long options to short options, preserving order
for arg in "${@}"; do
    case "${arg}" in
        "--file") set -- "${@}" "-f";;
        "--base") set -- "${@}" "-b";;
        "--arg") set -- "${@}" "-a";;
        "--secret") set -- "${@}" "-s";;
        "--only-pull") set -- "${@}" "-j";;
        "--skip-pull") set -- "${@}" "-o";;
        "--push") set -- "${@}" "-p";;
        "--user") set -- "${@}" "-u";;
        "--pass") set -- "${@}" "-r";;
        "--no-cache") set -- "${@}" "-k";;
        "--name") set -- "${@}" "-n";;
        "--log") set -- "${@}" "-l";;
        "--quiet") set -- "${@}" "-q";;
        "--github") set -- "${@}" "-x";;
        "--script") set -- "${@}" "-z";;
        "--help") set -- "${@}" "-h";;
        *) set -- "${@}" "${arg}";;
    esac
    shift
done

# Parse short options using getopts
while getopts "f:b:a:s:jopu:r:knlqxzh" arg &> /dev/null; do
    case "${arg}" in
        "f") dockerfile=$OPTARG;;
        "b") base_image=$OPTARG;;
        "a") build_args+=("$OPTARG");;
        "s") secrets+=("$OPTARG");;
        "j") only_pull=1;;
        "o") skip_pull=1;;
        "p") do_push=1;;
        "u") registry_user=$OPTARG;;
        "r") registry_pass=$OPTARG;;
        "k") no_cache=1;;
        "n") show_name=1;;
        "l") show_log=1;;
        "q") quiet_mode=1;;
        "x") github_mode=1;;
        "z") script_mode=1;;
        "h") show_usage; exit 0;;
        "?") show_usage; exit 1;;
    esac
done

# Shift positional arguments into place
shift $((OPTIND - 1))

if [ $github_mode -eq 0 ]; then
    # There are one or two positional arguments
    if [ $# -lt 1 -o $# -gt 2 ]; then
        show_usage
        exit 1
    fi
    # Get positional arguments
    target_image=$1
    [ $# -ge 2 ] && context_dir=$2
else
    # There are no positional arguments
    if [ $# -gt 0 ]; then
        show_usage
        exit 1
    fi
    # Get arguments from the environment in GitHub mode
    if [ -z "${TARGET_IMAGE:-}" ]; then
        show_usage
        exit 1
    fi
    target_image=$TARGET_IMAGE
    [ -n "${CONTEXT_DIR:-}" ] && context_dir=$CONTEXT_DIR
    [ -n "${DOCKERFILE:-}" ] && dockerfile=$DOCKERFILE
    [ -n "${BASE_IMAGE:-}" ] && base_image=$BASE_IMAGE
    if [ -n "${BUILD_ARGS:-}" ]; then
        readarray -t build_args <<< "$BUILD_ARGS"
    fi
    if [ -n "${SECRETS:-}" ]; then
        readarray -t secrets <<< "$SECRETS"
    fi
    only_pull=$(truthy_to_num "${ONLY_PULL:-}")
    skip_pull=$(truthy_to_num "${SKIP_PULL:-}")
    do_push=$(truthy_to_num "${DO_PUSH:-}")
    [ -n "${REGISTRY_USER:-}" ] && registry_user=$REGISTRY_USER
    [ -n "${REGISTRY_PASS:-}" ] && registry_pass=$REGISTRY_PASS
    no_cache=$(truthy_to_num "${NO_CACHE:-}")
    show_name=$(truthy_to_num "${NAME_ONLY:-}")
fi

remove_empty build_args
remove_empty secrets

# Turn script mode on for GitHub
if [ $github_mode -ne 0 ]; then
    script_mode=1
fi

# Check for Docker (unless we just need the name)
if ! command -v docker &> /dev/null && [ $show_name -eq 0 ]; then
    err_echo "The command 'docker' must be in PATH!"
    exit 1
fi

# Check for Regctl (unless we just need the name)
if ! command -v regctl &> /dev/null && [ $show_name -eq 0 ]; then
    if ! command -v curl &> /dev/null; then
        err_echo "The command 'curl' must be in PATH!"
        exit 1
    fi
    REGCTL_BIN=$HOME/.local/bin/regctl
    mkdir -p $(dirname $REGCTL_BIN)
    curl -fsSL "$REGCTL_URL" > $REGCTL_BIN
    chmod +x $REGCTL_BIN
    if ! echo $PATH | grep -q $(dirname $REGCTL_BIN); then
        PATH="$(dirname $REGCTL_BIN):$PATH"
    fi
fi

####################
# MAKE THE CONTEXT #
####################

group "Make the context"

if [ ! -d $context_dir ]; then
    err_echo "The context must be a directory!"
    exit 1
fi

if [ ! -f "$context_dir/$dockerfile" ]; then
    err_echo "The Dockerfile must be a file in the context directory!"
    exit 1
fi

context_tarball=$(mktemp)
(cd $context_dir && tar --create --dereference -f $context_tarball .)

# Add things to the context, so they influence tag generation
tmp_context_dir=$(mktemp -d)
echo "$dockerfile" > "$tmp_context_dir/.dockerfile"
if [ -n "$base_image" ]; then
    echo $base_image > "$tmp_context_dir/.base_image"
fi
if [ ${#build_args[@]} -gt 0 ]; then
    for ba in "${build_args[@]}"; do
        echo "$ba"
    done | LC_ALL=C sort > "$tmp_context_dir/.build_args"
fi
(cd $tmp_context_dir && tar --append -f $context_tarball .)

endgroup

##################
# GENERATE A TAG #
##################

group "Generate the tag"

tmp_context_dir=$(mktemp -d)
(cd $tmp_context_dir && tar --extract -f $context_tarball)
generated_tag="hn2b-$(md5sum_dir_contents $tmp_context_dir)"
target_repo=$(echo $target_image | cut -d ':' -f 1)
generated_image="$target_repo:$generated_tag"

endgroup

# Always output the image in script mode
if [ $script_mode -ne 0 ]; then
    echo "GENERATED_IMAGE=$generated_image"
fi

# Exit if we are only showing the name
if [ $show_name -ne 0 ]; then
    if [ $script_mode -ne 0 ]; then
        echo "HAD_IMAGE=$(num_to_bool 0)"
        echo "HAD_REMOTE_IMAGE=$(num_to_bool 0)"
        echo "WAS_PULLED=$(num_to_bool 0)"
        echo "WAS_BUILT=$(num_to_bool 0)"
    else
        echo $generated_image
    fi
    exit 0
fi

###################
# CHECK THE IMAGE #
###################

group "Check if the image exists"

# Assume the registry is the first element of the namespace
has_registry=1
registry=$(echo $target_image | cut -s -d '/' -f 1)

# Make sure this is actually a registry and not just part of the namespace by
# checking for a '.' character, such as in 'ghcr.io', etc
if ! echo $registry | grep -q '[.]'; then
    has_registry=0
    registry=""
fi

# Pushing does not make sense if there's no registry
if [ $has_registry -eq 0 -a $do_push -ne 0 ]; then
    err_echo "Can not push if there is no registry!" >&2
    exit 1
fi

has_image=0
if docker image ls -q $generated_image | grep -q '.'; then
    has_image=1
fi

has_remote_image=0
if [ $has_registry -ne 0 ]; then
    if [ -n "$registry_user" -a -n "$registry_pass" ]; then
        regctl registry login $registry --user $registry_user --pass $registry_pass >&2
        docker login --username $registry_user --password $registry_pass $registry >&2
    fi
    repo_tags=$(regctl tag ls $target_repo)
    if echo "$repo_tags" | grep -q $generated_tag; then
        has_remote_image=1
    fi
fi

endgroup

##################
# BUILD AND PUSH #
##################

group "Build (or not build) the image"

# Always rebuild if not caching, unless skipping pull
rebuild=$no_cache
if [ $only_pull -ne 0 -o $skip_pull -ne 0 ]; then
    rebuild=0
fi

# No-op if we already have the image
if [ $rebuild -eq 0 -a $has_image -ne 0 ]; then
    echo "Has: $generated_image" >&2
    endgroup
    if [ $script_mode -ne 0 ]; then
        echo "HAD_IMAGE=$(num_to_bool $has_image)"
        echo "HAD_REMOTE_IMAGE=$(num_to_bool $has_remote_image)"
        echo "WAS_PULLED=$(num_to_bool 0)"
        echo "WAS_BUILT=$(num_to_bool 0)"
    fi
    exit 0
fi

arg_quiet=""
if [ $quiet_mode -ne 0 ]; then
    arg_quiet="--quiet"
fi

# Pull the image if available
if [ $rebuild -eq 0 -a $has_remote_image -ne 0 -o $only_pull -ne 0 ]; then
    if [ $has_remote_image -ne 0 ]; then
        if [ $skip_pull -eq 0 ]; then
            docker pull $arg_quiet $generated_image  >&2
            echo "Has: $generated_image" >&2
        else
            echo "Remote: $generated_image" >&2
        fi
    else
        echo "Missing: $generated_image" >&2
    fi
    endgroup
    if [ $script_mode -ne 0 ]; then
        echo "HAD_IMAGE=$(num_to_bool $has_image)"
        echo "HAD_REMOTE_IMAGE=$(num_to_bool $has_remote_image)"
        echo "WAS_PULLED=$(num_to_bool $((! skip_pull)))"
        echo "WAS_BUILT=$(num_to_bool 0)"
    fi
    exit 0
fi

args_base_image=()
if [ -n "$base_image" ]; then
    args_base_image=("--build-arg" "BASE_IMAGE=$base_image")
fi

args_build_args=()
for ba in "${build_args[@]}"; do
    args_build_args+=("--build-arg" "$ba")
done

# Add this special build argument which does not participate in the context,
# because it is the tag computed from the context
args_hn2b_tag=("--build-arg" "HN2B_TAG=$generated_tag")

args_secrets=()
for sc in "${secrets[@]}"; do
    args_secrets+=("--secret" "$sc")
done

args_misc=()
if [ $no_cache -ne 0 ]; then
    args_misc=("--no-cache")
fi

if [ $show_log -ne 0 ]; then
    export BUILDKIT_PROGRESS="plain"
fi

docker build --load $arg_quiet "${args_base_image[@]}" "${args_build_args[@]}" \
    "${args_hn2b_tag[@]}" "${args_secrets[@]}" "${args_misc[@]}" \
    --tag $generated_image --file $dockerfile - < $context_tarball >&2
echo "Built: $generated_image" >&2

if [ $do_push -ne 0 ]; then
    docker push $arg_quiet $generated_image >&2
    echo "Pushed: $generated_image" >&2
fi

# Tag the image if there was a tag supplied
if echo $target_image | grep -q ':'; then
    docker tag $generated_image $target_image >&2
    echo "Tagged: $target_image" >&2
    if [ $do_push -ne 0 ]; then
        docker push $arg_quiet $target_image >&2
        echo "Pushed: $target_image" >&2
    fi
fi

endgroup

if [ $script_mode -ne 0 ]; then
    echo "HAD_IMAGE=$(num_to_bool $has_image)"
    echo "HAD_REMOTE_IMAGE=$(num_to_bool $has_remote_image)"
    echo "WAS_PULLED=$(num_to_bool 0)"
    echo "WAS_BUILT=$(num_to_bool 1)"
fi

exit 0
