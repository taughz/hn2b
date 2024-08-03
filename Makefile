# Makefile

# Copyright (c) 2024 Tim Perkins

SHELL := /bin/bash
.ONESHELL:
.SHELLFLAGS := -o errexit -o nounset -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error Please use a version of Make supporting .RECIPEPREFIX)
endif
.RECIPEPREFIX = >

# Make sure all is the default goal
.DEFAULT_GOAL := all

.PHONY: all
all:
> @echo "Nothing to do, try 'make test'" >&2

.PHONY: test_check_reqs
test_check_reqs:
> @if ! command -v docker > /dev/null; then
>     echo "Testing requires Docker to be installed!" >&2
>     exit 1
> fi
> if ! command -v regctl > /dev/null; then
>     echo "Testing requires Regctl to be installed!" >&2
>     exit 1
> fi

.PHONY: test_check_prysk
test_check_prysk:
> @if ! pip list | grep prysk > /dev/null; then
>     pip install prysk
> fi

.PHONY: test
test: test_check_reqs test_check_prysk
> prysk test/hn2b.t
