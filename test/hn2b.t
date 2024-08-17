# hn2b.t

# Copyright (c) 2024 Tim Perkins

This is a test of the 'hn2b.sh' script. It uses the Python testing tool 'prysk'
(which is an updated 'cram'). To run this test, you should 'pip install prysk'
and then do 'prysk hn2b.t'. The expected results can be updated by running the
command 'prysk hn2b.t -i'.

Make the current directory the repo root:

  $ cd "$TESTDIR/.."

Usage should print if no arguments are given:

  $ ./hn2b.sh
  Usage: hn2b.sh [-f | --file DOCKERFILE] [-b | --base BASE_IMAGE]
              [-a | --arg BUILD_ARG] [-s | --secret SECRET] [-o | --skip-pull]
              [-p | --push] [-u | --user USER] [-r | --pass PASS]
              [-k | --no-cache] [-n | --name] [-l | --log] [-q | --quiet]
              [-x | --github ] [-h | --help]
              TARGET_IMAGE [CONTEXT_DIR]
  
  Build (or not build) a Docker image named TARGET_IMAGE, i.e.,
  '[REG/][NS/**/]REPO[:TAG]', using CONTEXT_DIR as the context.
  
      -f | --file DOCKERFILE  Dockerfile to use for the build
      -b | --base BASE_IMAGE  Base image to use for the build
      -a | --arg BUILD_ARG    A build argument, e.g., 'NAME=VALUE'
      -s | --secret SECRET    A secret argument, e.g., 'NAME=VALUE'
      -o | --skip-pull        Just exit instead of pulling remote images
      -p | --push             Push the newly built container
      -u | --user USER        User to use during registry login
      -r | --pass PASS        Password or token to use during registry login
      -k | --no-cache         Build without using cache
      -n | --name             Display the name of the image only
      -l | --log              Display plain progress during build
      -q | --quiet            Display only essential information
      -x | --github           Operate in GitHub mode
      -h | --help             Display this help message
  [1]





Using the '--help' option should also show usage:

  $ ./hn2b.sh --help
  Usage: hn2b.sh [-f | --file DOCKERFILE] [-b | --base BASE_IMAGE]
              [-a | --arg BUILD_ARG] [-s | --secret SECRET] [-o | --skip-pull]
              [-p | --push] [-u | --user USER] [-r | --pass PASS]
              [-k | --no-cache] [-n | --name] [-l | --log] [-q | --quiet]
              [-x | --github ] [-h | --help]
              TARGET_IMAGE [CONTEXT_DIR]
  
  Build (or not build) a Docker image named TARGET_IMAGE, i.e.,
  '[REG/][NS/**/]REPO[:TAG]', using CONTEXT_DIR as the context.
  
      -f | --file DOCKERFILE  Dockerfile to use for the build
      -b | --base BASE_IMAGE  Base image to use for the build
      -a | --arg BUILD_ARG    A build argument, e.g., 'NAME=VALUE'
      -s | --secret SECRET    A secret argument, e.g., 'NAME=VALUE'
      -o | --skip-pull        Just exit instead of pulling remote images
      -p | --push             Push the newly built container
      -u | --user USER        User to use during registry login
      -r | --pass PASS        Password or token to use during registry login
      -k | --no-cache         Build without using cache
      -n | --name             Display the name of the image only
      -l | --log              Display plain progress during build
      -q | --quiet            Display only essential information
      -x | --github           Operate in GitHub mode
      -h | --help             Display this help message



Use the '--name' option to display the image name and exit.

  $ ./hn2b.sh --name hn2b-test test/image
  hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c

Just in case the image has been left around, force it's removal now:

  $ docker rmi -f hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c > /dev/null 2>&1

Build the base image. Then try building it again. The second time, it should not
actually build, but reuse the container that was just built:

  $ ./hn2b.sh -q hn2b-test test/image
  sha256:[a-z0-9]{64} (re)
  Built: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c

  $ ./hn2b.sh -q hn2b-test test/image
  Has: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c

Even if the container is already built, using the '--no-cache' option should
force it to rebuild:

  $ ./hn2b.sh -q --no-cache hn2b-test test/image
  sha256:[a-z0-9]{64} (re)
  Built: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c

It should also be possible to use the current directory as the context:

  $ (cd test/image; ../../hn2b.sh --name hn2b-test)
  hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c

  $ (cd test/image; ../../hn2b.sh -q hn2b-test)
  Has: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c

The user can choose to build against a different Dockerfile in the context, and
doing so should cause the tag to change:

  $ docker rmi -f hn2b-test:hn2b-edfef6d2d81cdd42c46038af5836def0 > /dev/null 2>&1
  $ ./hn2b.sh -q --file Dockerfile.alt hn2b-test test/image
  sha256:[a-z0-9]{64} (re)
  Built: hn2b-test:hn2b-edfef6d2d81cdd42c46038af5836def0

Adding a base image should cause the tag to change:

  $ docker rmi -f hn2b-test:hn2b-87868d1fbb2b16d9eb62ed70361ac6df > /dev/null 2>&1
  $ ./hn2b.sh -q --base ubuntu:22.04 hn2b-test test/image
  sha256:[a-z0-9]{64} (re)
  Built: hn2b-test:hn2b-87868d1fbb2b16d9eb62ed70361ac6df

Adding build args should cause the tag to change:

  $ docker rmi -f hn2b-test:hn2b-aa0ba9e3c5a3f69b7515e9cea8f3547d > /dev/null 2>&1
  $ ./hn2b.sh -q --arg "FOO=2" --arg "BAR=3" hn2b-test test/image
  sha256:[a-z0-9]{64} (re)
  Built: hn2b-test:hn2b-aa0ba9e3c5a3f69b7515e9cea8f3547d

Adding secrets should NOT cause the tag to change:

  $ export SECRET1="MyPassword"
  $ export SECRET2="Hunter2"
  $ ./hn2b.sh -q --secret "id=SECRET1" --secret "id=SECRET2" hn2b-test test/image
  Has: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c

Use GitHub mode to pass argument through environment variables:

  $ export TARGET_IMAGE="hn2b-test"
  $ export CONTEXT_DIR="$PWD/test/image"
  $ ./hn2b.sh -q --github
  ::group::Make the context
  ::endgroup::
  ::group::Generate the tag
  ::endgroup::
  GENERATED_IMAGE=hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c
  ::group::Check if the image exists
  ::endgroup::
  ::group::Build (or not build) the image
  Has: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c
  ::endgroup::
  HAD_IMAGE=true
  HAD_REMOTE_IMAGE=(true|false) (re)
  WAS_PULLED=false
  WAS_BUILT=false

The user can disable caching:

  $ export NO_CACHE=yes
  $ ./hn2b.sh -q --github
  ::group::Make the context
  ::endgroup::
  ::group::Generate the tag
  ::endgroup::
  GENERATED_IMAGE=hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c
  ::group::Check if the image exists
  ::endgroup::
  ::group::Build (or not build) the image
  sha256:[a-z0-9]{64} (re)
  Built: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c
  ::endgroup::
  HAD_IMAGE=true
  HAD_REMOTE_IMAGE=(true|false) (re)
  WAS_PULLED=false
  WAS_BUILT=true
  $ unset NO_CACHE

The user can just get the image name. Notice that the outputs are always false,
because the script does not actually check for the image:

  $ export NAME_ONLY=yes
  $ ./hn2b.sh -q --github
  ::group::Make the context
  ::endgroup::
  ::group::Generate the tag
  ::endgroup::
  GENERATED_IMAGE=hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c
  HAD_IMAGE=false
  HAD_REMOTE_IMAGE=false
  WAS_PULLED=false
  WAS_BUILT=false
  $ unset NAME_ONLY

The user can choose another Dockerfile:

  $ export DOCKERFILE=Dockerfile.alt
  $ ./hn2b.sh -q --github
  ::group::Make the context
  ::endgroup::
  ::group::Generate the tag
  ::endgroup::
  GENERATED_IMAGE=hn2b-test:hn2b-edfef6d2d81cdd42c46038af5836def0
  ::group::Check if the image exists
  ::endgroup::
  ::group::Build (or not build) the image
  Has: hn2b-test:hn2b-edfef6d2d81cdd42c46038af5836def0
  ::endgroup::
  HAD_IMAGE=true
  HAD_REMOTE_IMAGE=(true|false) (re)
  WAS_PULLED=false
  WAS_BUILT=false
  $ unset DOCKERFILE

The user can choose a base image:

  $ export BASE_IMAGE="ubuntu:22.04"
  $ ./hn2b.sh -q --github
  ::group::Make the context
  ::endgroup::
  ::group::Generate the tag
  ::endgroup::
  GENERATED_IMAGE=hn2b-test:hn2b-87868d1fbb2b16d9eb62ed70361ac6df
  ::group::Check if the image exists
  ::endgroup::
  ::group::Build (or not build) the image
  Has: hn2b-test:hn2b-87868d1fbb2b16d9eb62ed70361ac6df
  ::endgroup::
  HAD_IMAGE=true
  HAD_REMOTE_IMAGE=(true|false) (re)
  WAS_PULLED=false
  WAS_BUILT=false
  $ unset BASE_IMAGE

The user can add build arguments:

  $ cat <<EOF > /tmp/build_args.txt
  > FOO=2
  > BAR=3
  > EOF
  $ BUILD_ARGS=$(cat /tmp/build_args.txt)
  $ export BUILD_ARGS
  $ ./hn2b.sh -q --github
  ::group::Make the context
  ::endgroup::
  ::group::Generate the tag
  ::endgroup::
  GENERATED_IMAGE=hn2b-test:hn2b-aa0ba9e3c5a3f69b7515e9cea8f3547d
  ::group::Check if the image exists
  ::endgroup::
  ::group::Build (or not build) the image
  Has: hn2b-test:hn2b-aa0ba9e3c5a3f69b7515e9cea8f3547d
  ::endgroup::
  HAD_IMAGE=true
  HAD_REMOTE_IMAGE=(true|false) (re)
  WAS_PULLED=false
  WAS_BUILT=false
  $ unset BUILD_ARGS

The user can add secrets:

  $ cat <<EOF > /tmp/secrets.txt
  > id=SECRET1
  > id=SECRET2
  > EOF
  $ SECRETS=$(cat /tmp/secrets.txt)
  $ export SECRETS
  $ ./hn2b.sh -q --github
  ::group::Make the context
  ::endgroup::
  ::group::Generate the tag
  ::endgroup::
  GENERATED_IMAGE=hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c
  ::group::Check if the image exists
  ::endgroup::
  ::group::Build (or not build) the image
  Has: hn2b-test:hn2b-538561f04d0e981c78972410ec0f217c
  ::endgroup::
  HAD_IMAGE=true
  HAD_REMOTE_IMAGE=(true|false) (re)
  WAS_PULLED=false
  WAS_BUILT=false
  $ unset SECRETS
