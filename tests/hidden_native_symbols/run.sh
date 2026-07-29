#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cargo build --manifest-path "$root/Cargo.toml" --target-dir "$tmp/baseline"
cargo build \
	--manifest-path "$root/Cargo.toml" \
	--features hidden-native-symbols \
	--target-dir "$tmp/hidden"

baseline_archive="$(find "$tmp/baseline" -path '*/out/lib/libmcl.a' -print -quit)"
hidden_archive="$(find "$tmp/hidden" -path '*/out/lib/libmcl.a' -print -quit)"
include="$root/mcl/include"
common_flags=(-DMCL_FP_BIT=384 -DMCL_FR_BIT=256 -I"$include")

c++ -O2 -rdynamic "${common_flags[@]}" \
	"$root/tests/hidden_native_symbols/host.cpp" \
	"$baseline_archive" -ldl -pthread -o "$tmp/host"

c++ -O2 -fPIC -shared -fvisibility=hidden "${common_flags[@]}" \
	"$root/tests/hidden_native_symbols/plugin.cpp" \
	"$hidden_archive" -pthread -o "$tmp/plugin-hidden.so"

if nm -D --defined-only "$tmp/plugin-hidden.so" |
	grep -Eq '_ZGVN3mcl|_ZN3mcl2fp2OpD[012]Ev'; then
	echo "MCL global state is visible in plugin-hidden.so" >&2
	exit 1
fi
"$tmp/host" "$tmp/plugin-hidden.so"

c++ -O2 -fPIC -shared -fvisibility=hidden "${common_flags[@]}" \
	"$root/tests/hidden_native_symbols/plugin.cpp" \
	"$hidden_archive" -Wl,--exclude-libs,ALL -pthread \
	-o "$tmp/plugin-isolated.so"

mapfile -t exports < <(nm -D --defined-only "$tmp/plugin-isolated.so" | awk '{print $3}')
if [[ "${#exports[@]}" -ne 1 || "${exports[0]}" != "mcl_plugin_init" ]]; then
	printf 'unexpected plugin exports:\n%s\n' "${exports[*]}" >&2
	exit 1
fi
"$tmp/host" "$tmp/plugin-isolated.so"
