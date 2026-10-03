#!/bin/sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
compiler=$(xcrun --find swift)
host_libs=$(dirname "$(dirname "$compiler")")/lib/swift/host

exec "$compiler" -I "$host_libs" -L "$host_libs" \
    -Xlinker -rpath -Xlinker "$host_libs" \
    "$script_dir/MultilineConditionalBodies.swift" "$@"
