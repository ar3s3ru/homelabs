MAKEFLAGS    += -s --always-make -C
SHELL        := bash
.SHELLFLAGS  := -Eeuo pipefail -c

# Get the path to this Makefile and directory
MAKEFILE_DIR := $(patsubst %/,%,$(dir $(abspath $(lastword $(MAKEFILE_LIST)))))
