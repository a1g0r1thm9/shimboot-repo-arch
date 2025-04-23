#!/bin/bash

base_path="$(realpath $(dirname $0))"
cd $base_path
. ./common.sh

print_help() {
  echo "Usage: ./build_package_chroot.sh distro_name release_name arch"
  echo "Valid named arguments (specify with 'key=value'):"
  echo "  pkg_source  - Package source location (git)"
  echo "  patches     - Patch files (relative to the repo dir)"
}

assert_root
assert_args "$3"
parse_args "$@"

distro_name="$1"
release_name="$2"
arch="$3"

source_type="git"
pkg_source="${args['pkg_source']}"
patches="${args['patches']}"

build_dir="$base_path/build"
source_dir="$build_dir/pkg"

#install build tools
pacman -Syu --noconfirm
pacman -S --noconfirm --needed base-devel git quilt meson ninja

#create a directory to put the package source in
rm -rf "$build_dir"
mkdir -p "$build_dir"
cd "$build_dir"

#download the package source
git clone --depth=1 "$pkg_source" "$source_dir"

#apply any needed patches
cd "$source_dir"
if [ "$patches" ]; then
  for patch in "$patches"; do
    patch_path="$base_path/$patch"
    quilt import $patch_path
  done
  quilt push
fi

#install build deps
pacman -S gperf libcap libgcrypt libseccomp util-linux cryptsetup xz \
  kmod acl pam python-docutils libidn2 libxcrypt gnutls dbus libmicrohttpd \
  libp11-kit libfido2 libbpf curl libcurl
#trust me, this is much easier than 'dpkg --add-architecture'           - some guy on r/unixporn, 201X
if [ "$arch" = "amd64" ]; then
  if grep -q "^\[multilib\]" "/etc/pacman.conf"; then
    echo "multilib already enabled"
  else
      #uncomment multilib block
      sed -i '/^\[multilib\]/,/^#Include/ s/^#//' "/etc/pacman.conf"
      pacman -Sy
  fi
fi

#build the package
ninja -C build
