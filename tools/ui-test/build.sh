#!/bin/zsh
# Compiles the small helper tools used to drive and inspect the island from the terminal into .build/ui-test/.
# Dev tooling only: not part of the app, not shipped. Usage: see README.md in this folder.
set -euo pipefail
cd "${0:A:h}"
OUT="../../.build/ui-test"
mkdir -p "$OUT"
for src in move click hold drag scroll lum export-frames contact-sheet backdrop make-gif; do
  swiftc -O "$src.swift" -o "$OUT/$src" 2>&1 | grep -E "error" || true
done
echo "built into .build/ui-test: $(ls $OUT | tr '\n' ' ')"
