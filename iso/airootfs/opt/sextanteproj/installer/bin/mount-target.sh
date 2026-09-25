#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "Uso: $0 /dev/disco"
    exit 1
fi

DISK="$1"

case "$DISK" in
    *[0-9])
        EFI="${DISK}p1"
        ROOT="${DISK}p2"
        ;;
    *)
        EFI="${DISK}1"
        ROOT="${DISK}2"
        ;;
esac

echo "Disco: $DISK"
echo "EFI  : $EFI"
echo "ROOT : $ROOT"

if [[ ! -b "$EFI" ]]; then
    echo "ERROR: No existe $EFI"
    exit 1
fi

if [[ ! -b "$ROOT" ]]; then
    echo "ERROR: No existe $ROOT"
    exit 1
fi

if mountpoint -q /mnt; then
    echo "Desmontando /mnt previamente..."
    umount -R /mnt
fi

echo "Montando ROOT..."
mount "$ROOT" /mnt

mkdir -p /mnt/boot/efi

echo "Montando EFI..."
mount "$EFI" /mnt/boot/efi

echo
echo "Montajes:"
findmnt /mnt
findmnt /mnt/boot/efi
