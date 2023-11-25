#!/usr/bin/env bash

######################################################################
# @author      : Ruan E. Formigoni (ruanformigoni@gmail.com)
# @file        : build
# @created     : Friday Nov 24, 2023 19:06:13 -03
#
# @description : 
######################################################################

set -e

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

build_dir="$SCRIPT_DIR/build"

rm -rf "$build_dir"; mkdir "$build_dir"; cd "$build_dir"

# Fetch latest release
url_retroarch="https://buildbot.libretro.com/nightly/linux/x86_64/RetroArch.7z"
wget "$url_retroarch"
name_7z_file="$(basename "$url_retroarch")"

# Extract
7z x "$name_7z_file"

# Remove 7z file
rm "$name_7z_file"

# Move appimage to curr dir
mv "RetroArch-Linux-x86_64/RetroArch-Linux-x86_64.AppImage" .
appimage_retroarch="RetroArch-Linux-x86_64.AppImage"

# Move assets to curr dir
mv "RetroArch-Linux-x86_64/RetroArch-Linux-x86_64.AppImage.home" .
assets_retroarch="RetroArch-Linux-x86_64.AppImage.home"

# Remove extracted folder
rm -rf "$build_dir/RetroArch-Linux-x86_64/"

# Make executable
chmod +x "$build_dir/$appimage_retroarch"

# Extract appimage
"$build_dir/$appimage_retroarch" --appimage-extract

# Fetch container
if ! [ -f "$build_dir/arch.tar.xz" ]; then
  wget "https://gitlab.com/api/v4/projects/43000137/packages/generic/fim/continuous/arch.tar.xz"
fi

# Extract container
[ ! -f "$build_dir/arch.fim" ] || rm "$build_dir/arch.fim"
tar xf arch.tar.xz

# FIM_COMPRESSION_LEVEL
export FIM_COMPRESSION_LEVEL=6

# Resize
"$build_dir"/arch.fim fim-resize 3G

# Update
"$build_dir"/arch.fim fim-root fakechroot pacman -Syu --noconfirm

# Install dependencies
"$build_dir"/arch.fim fim-root fakechroot pacman -S libxkbcommon libxkbcommon-x11 \
  lib32-libxkbcommon lib32-libxkbcommon-x11 libsm lib32-libsm fontconfig \
  lib32-fontconfig noto-fonts --noconfirm

# Install video packages
"$build_dir"/arch.fim fim-root fakechroot pacman -S xorg-server mesa lib32-mesa \
  glxinfo pcre xf86-video-amdgpu vulkan-radeon lib32-vulkan-radeon \
  xf86-video-intel vulkan-intel lib32-vulkan-intel vulkan-tools --noconfirm

# Compress main image
"$build_dir"/arch.fim fim-compress

# Compress retroarch
"$build_dir"/arch.fim fim-exec mkdwarfs -i "$build_dir"/squashfs-root/usr -o "$build_dir/retroarch.dwarfs"

# Include retroarch
"$build_dir"/arch.fim fim-include-path "$build_dir"/retroarch.dwarfs "/retroarch.dwarfs"

# Compress assets
"$build_dir"/arch.fim fim-exec mkdwarfs -i "$build_dir/$assets_retroarch" -o "$build_dir/assets.dwarfs"

# Include assets
"$build_dir"/arch.fim fim-include-path "$build_dir/assets.dwarfs" "/assets.dwarfs"

# Include runner script
{ tee "$build_dir"/retroarch.sh | sed -e "s/^/-- /"; } <<-'EOL'
#!/bin/bash

export LD_LIBRARY_PATH="/retroarch/lib:$LD_LIBRARY_PATH"

DIR_CONFIG_RETROARCH="${XDG_CONFIG_HOME:-"$HOME/.config"}"

mkdir -p "$DIR_CONFIG_RETROARCH"

if ! [ -d "${DIR_CONFIG_RETROARCH}"/retroarch ]; then
  cp -r /assets/.config/retroarch "$DIR_CONFIG_RETROARCH"
fi

/retroarch/bin/retroarch "$@"
EOL
chmod +x "$build_dir"/retroarch.sh
"$build_dir"/arch.fim fim-root mkdir -p /fim/scripts
"$build_dir"/arch.fim fim-root cp "$build_dir"/retroarch.sh /fim/scripts/retroarch.sh

# Set default command
"$build_dir"/arch.fim fim-cmd /fim/scripts/retroarch.sh

# Set perms
"$build_dir"/arch.fim fim-perms-set wayland,x11,pulseaudio,gpu,session_bus,input,usb

# Rename
mv "$build_dir/arch.fim" retroarch-arch.fim


# // cmd: !./%
