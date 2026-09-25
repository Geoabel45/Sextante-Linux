#!/usr/bin/env bash
set -euo pipefail

PROJECT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DEST="$PROJECT/iso/airootfs/opt/sextanteproj"

echo "Sincronizando instalador de Sextante..."

rm -rf "$DEST"

mkdir -p \
    "$DEST/installer" \
    "$DEST/packages"

cp -a "$PROJECT/installer/." "$DEST/installer/"

cp "$PROJECT/packages/oficiales.txt" \
   "$DEST/packages/oficiales.txt"

if [[ -f "$PROJECT/packages/aur.txt" ]]; then
    cp "$PROJECT/packages/aur.txt" \
       "$DEST/packages/aur.txt"
fi

# No incluir archivos de respaldo, desarrollo ni cachés
find "$DEST/installer" -type f \
    \( -name '*.bak*' -o -name '*.sho' -o -name '*.pyc' \) \
    -delete

find "$DEST" -type d -name '__pycache__' \
    -prune -exec rm -rf {} +

echo "OK: instalador sincronizado en /opt/sextanteproj"
