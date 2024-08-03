# HN2B (How Not To Build)

Speed up your Docker builds by not doing them in the first place. This project
provides a reusable implementation of a basic strategy that I have used in a few
different stand-alone projects at different times. The main concept is to
aggressively reuse Docker containers, with a few assumptions (and a few caveats)
about how they are used.

## Basic Strategy

1. Build a context.
2. Generate a tag from the context using a checksum.
3. Check if the image already exists.
4. Build it (or not).

## Assumptions

- Your image build is essentially idempotent.
- Your image (output) is essentially a function of the context (input).
- Any deviations from the above are negligible to your usage.

These assumptions do not need to be exactly true. For example, if you do an
`apt-get install` of some package, that is not idempotent because you could get
different versions of packages depending on when you run it. But if you don't
really care about that, you can ignore it. (See caveats below.)

If on the other hand, you build the exact same context relying on external
dependencies in your build to produce a different resulting container, this
strategy is not going to work for you.

## Caveats

Ideally, your image should be built once and pushed to some registry, then
everyone else just pulls the existing image. This would ensure everyone has the
exact same image for the given tag. But that's not always practical with
decentralized development.

If your image build is not exactly idempotent, you can end up with different
images being tagged with the same generated tag. Even though the context is the
same, external dependencies can drift. For example, `apt-get install` installing
packages of different versions.

If images are built around the same time, the problem is usually not so bad,
because the dependency drift is not too much. If the images are built years
apart, the drift may be drastic. This of course depends on how close your build
is to being idempotent.

## Usage

As a script:

``` text
$ ./hn2b.sh --help
Usage: hn2b.sh [-f | --file DOCKERFILE] [-b | --base BASE_IMAGE]
            [-a | --arg BUILD_ARG] [-s | --secret SECRET] [-p | --push]
            [-u | --user USER] [-r | --pass PASS] [-k | --no-cache]
            [-n | --name] [-l | --log] [-q | --quiet] [-x | --github ]
            [-h | --help]
            TARGET_IMAGE [CONTEXT_DIR]

Build (or not build) a Docker image named TARGET_IMAGE, i.e.,
'[REG/][NS/**/]REPO[:TAG]', using CONTEXT_DIR as the context.

    -f | --file DOCKERFILE  Dockerfile to use for the build
    -b | --base BASE_IMAGE  Base image to use for the build
    -a | --arg BUILD_ARG    A build argument, e.g., 'NAME=VALUE'
    -s | --secret SECRET    A secret argument, e.g., 'NAME=VALUE'
    -p | --push             Push the newly built container
    -u | --user USER        User to use during registry login
    -r | --pass PASS        Password or token to use during registry login
    -k | --no-cache         Build without using cache
    -n | --name             Display the name of the image only
    -l | --log              Display plain progress during build
    -q | --quiet            Display only essential information
    -x | --github           Operate in GitHub mode
    -h | --help             Display this help message
```

As a GitHub action:

``` text
- name: 'Build (Or Not Build) Image'
  uses: 'taughz/hn2b@main'
  with:
    image: 'registry.io/user/my-image:my-tag'
    context: 'dir/subdir'
    build-args: |
      FOO='${{ env.FOO }}'
      BAR='${{ env.BAR }}'
    registry-pass: '${{ secrets.TOKEN }}'
    push: true
```

## What's In A Name?

HN2B is a pun for anyone that looks at the caveats and thinks, "Why would you
ever want to do this?" The best answer I can give is, sometimes simple solutions
beat complex ones, even when the complex ones are better.
