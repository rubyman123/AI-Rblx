#!/bin/sh
# Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
# Usage:  ./build.sh BearBuddy          build + render + out/compare_BearBuddy.png
#         ./build.sh BearBuddy export   also bake the Roblox mesh: out/BearBuddy.fbx + textures
# Blender is found automatically (see kit/run.py).
HERE="$(cd "$(dirname "$0")" && pwd)"
[ -z "$1" ] && { echo "Usage: ./build.sh ModelId [export]"; exit 1; }
if [ "$2" = "export" ]; then python3 "$HERE/kit/run.py" export "$1"; else python3 "$HERE/kit/run.py" build "$1"; fi
