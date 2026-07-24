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

# The HN2B script
HN2B ?= hn2b.sh

# Various tools used by this Makefile
SHELLCHECK ?= shellcheck
DOCKER ?= docker
REGCTL ?= regctl
PRYSK ?= prysk
PIP ?= pip

# Options to change the behavior
IGNORE_MISSING_REGCTL ?= 0
INSTALL_PRYSK ?= 0
PIP_INSTALL_FLAGS ?= --break-system-packages

# Usage: $(call truthy,VALUE)
#
# Converts a "truthy" string to an number, either 0 or 1.
truthy = $(shell case "$(1)" in ([Yy]|[Yy][Ee][Ss]|[Tt]|[Tt][Rr][Uu][Ee]|1) echo 1 ;; (*) echo 0 ;; esac)

# Normalize some of the options
override IGNORE_MISSING_REGCTL := $(call truthy,$(IGNORE_MISSING_REGCTL))
override INSTALL_PRYSK := $(call truthy,$(INSTALL_PRYSK))

.PHONY: all
all:
> @echo "Nothing to do, try 'make check' or 'make test'" >&2

.PHONY: check
check: lint test

.PHONY: lint_check_reqs
lint_check_reqs:
> @if ! command -v $(SHELLCHECK) > /dev/null; then
>     echo "Linting requires ShellCheck to be installed!" >&2
>     exit 1
> fi

.PHONY: lint
lint: $(HN2B) lint_check_reqs
> $(SHELLCHECK) $<

.PHONY: test_check_reqs
test_check_reqs:
> @if ! command -v $(DOCKER) > /dev/null; then
>     echo "Testing requires Docker to be installed!" >&2
>     exit 1
> fi
> @if ! command -v $(REGCTL) > /dev/null && [ "$(IGNORE_MISSING_REGCTL)" -eq 0 ]; then
>     echo "Testing requires Regctl to be installed! Set IGNORE_MISSING_REGCTL=1 to continue anyway." >&2
>     exit 1
> fi
> @if ! command -v $(PRYSK) > /dev/null; then
>     if [ "$(INSTALL_PRYSK)" -ne 0 ]; then
>         $(PIP) install $(PIP_INSTALL_FLAGS) prysk
>     else
>         echo "Testing requires Prysk to be installed! Set INSTALL_PRYSK=1 to install it with Pip." >&2
>         exit 1
>     fi
> fi

.PHONY: test
test: test/hn2b.t test_check_reqs
> $(PRYSK) $<
