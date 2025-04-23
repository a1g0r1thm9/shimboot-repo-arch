#!/bin/bash

base_path="$(realpath $(dirname $0))"
cd $base_path
. ./common.sh

print_help() {
  echo "Usage: ./build_package_chroot.sh arch"
  echo "Valid named arguments (specify with 'key=value'):"
  echo "  pkg_source  - Package source location (git)"
  echo "  patches     - Patch files (relative to the repo dir)"
}

assert_root
assert_args "$1"
parse_args "$@"

arch="$1"

source_type="git"
pkg_source="${args['pkg_source']}"
patches="${args['patches']}"

build_dir="$base_path/build"
source_dir="$build_dir/pkg"

#pacman needs sources, using old reliable arizona.edu
echo "Server = http://mirror.arizona.edu/archlinux/core/os/86_64/" > /etc/pacman.d/mirrorlist
echo "Server = http://mirror.arizona.edu/archlinux/extra/os/86_64/" >> /etc/pacman.d/mirrorlist

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

#gotta move that gear up!
ninja -C build
