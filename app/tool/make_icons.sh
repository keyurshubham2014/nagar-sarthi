#!/bin/sh
# Regenerates the Android launcher icon and splash mark (black rounded square,
# white "N" in Plus Jakarta Sans 700). macOS only: needs Swift and CoreText.
set -e
cd "$(dirname "$0")/.."
bin=$(mktemp -d)/make_icon
xcrun swiftc -O -o "$bin" tool/make_icon.swift
res=android/app/src/main/res
for d in mdpi:1 hdpi:1.5 xhdpi:2 xxhdpi:3 xxxhdpi:4; do
  name=${d%%:*}; k=${d##*:}
  "$bin" assets/fonts/PlusJakartaSans.ttf "$res/mipmap-$name/ic_launcher.png" "$(echo "48*$k/1" | bc)" square
  "$bin" assets/fonts/PlusJakartaSans.ttf "$res/mipmap-$name/ic_launcher_foreground.png" "$(echo "108*$k/1" | bc)" fg
done
