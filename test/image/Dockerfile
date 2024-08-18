ARG BASE_IMAGE="ubuntu:24.04"

FROM $BASE_IMAGE

ARG BASE_IMAGE
ENV BASE_IMAGE=$BASE_IMAGE

ARG FOO=0
ENV FOO=$FOO

ARG BAR=0
ENV BAR=$BAR

RUN printenv | tee /env.txt

COPY test.txt /test.txt
COPY .hidden.txt /.hidden.txt
COPY subdir /subdir
COPY .subdir /.subdir
COPY side_file.txt /side_file.txt
COPY side_dir /side_dir
