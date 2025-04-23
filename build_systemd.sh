#!/bin/bash

base_path="$(realpath $(dirname $0))"
cd $base_path
. ./common.sh

print_help() {
  echo "Usage: ./build_systemd.sh arch"
}

assert_root
assert_deps "debootstrap"
assert_args "$1"

arch="$1"

#the debian unstable patch looks like it will probably work on modern systemd, need to test
./build_package.sh $arch \
  pkg_source="https://github.com/systemd/systemd" \
  patches=patches/systemd_arch.patch
