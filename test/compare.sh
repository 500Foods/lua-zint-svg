#!/bin/bash
# Build vendored zint 2.16.0 if needed, then compare bin/lua-zint to it.
# The system zint is an older release and is not the oracle.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export ZINT="${ZINT:-$ROOT/vendor/zint/build/frontend/zint}"
export LUA_ZINT="${LUA_ZINT:-$ROOT/bin/lua-zint}"
export LC_ALL=C

if [ ! -x "$ZINT" ]; then
  cmake -S "$ROOT/vendor/zint" -B "$ROOT/vendor/zint/build" \
    -DZINT_USE_QT=OFF -DZINT_USE_PNG=OFF -DZINT_USE_GS1SE=OFF \
    -DZINT_SHARED=ON -DCMAKE_BUILD_TYPE=Release
  cmake --build "$ROOT/vendor/zint/build" --target zint -j
fi

"$ZINT" --version
cd "$ROOT/test/harnesses"
bash flags.sh
bash colourdiff.sh
bash upca.sh
bash ean13.sh
bash isbn.sh
bash ean8.sh
bash upce.sh
bash c25inter.sh
bash nve18.sh
bash dbar.sh
bash dbaromn.sh
bash dmatrix.sh
bash code128ab.sh
bash flat.sh
bash pdf417.sh
bash maxicode.sh
bash aztec.sh
bash imail.sh
bash fuzz.sh "${FUZZ_ROUNDS:-5}"
bash stressqr.sh "${STRESS_ROUNDS:-1}"
