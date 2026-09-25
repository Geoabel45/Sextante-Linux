#!/usr/bin/env bash
set -euo pipefail

PROJECT="$HOME/SextanteLinux"
DISK="$PROJECT/lab/sextante-branding-test.qcow2"
VARS="$PROJECT/lab/OVMF_VARS-branding-installed.fd"

OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_TEMPLATE="/usr/share/edk2/x64/OVMF_VARS.4m.fd"

if [[ ! -f "$DISK" ]]; then
    echo "ERROR: No existe el disco virtual:"
    echo "$DISK"
    exit 1
fi

if [[ ! -f "$OVMF_CODE" || ! -f "$OVMF_TEMPLATE" ]]; then
    echo "ERROR: No se encontró OVMF."
    exit 1
fi

# Crear variables UEFI independientes para esta prueba.
if [[ ! -f "$VARS" ]]; then
    cp "$OVMF_TEMPLATE" "$VARS"
fi

if [[ -e /dev/kvm && -r /dev/kvm && -w /dev/kvm ]]; then
    echo "Aceleración: KVM"
    ACCEL=(-enable-kvm -cpu host)
else
    echo "Aceleración: TCG"
    ACCEL=(-accel tcg -cpu max)
fi

echo
echo "=========================================="
echo "   SEXTANTE LINUX - PRUEBA DE ARRANQUE"
echo "=========================================="
echo
echo "Disco:"
echo "  $DISK"
echo
echo "ISO Live: NO CONECTADA"
echo

exec qemu-system-x86_64 \
    "${ACCEL[@]}" \
    -machine q35 \
    -m 4096 \
    -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$VARS" \
    -drive file="$DISK",format=qcow2,if=virtio \
    -boot menu=on,order=c \
    -device virtio-vga \
    -display gtk \
    -usb \
    -device usb-tablet \
    -nic user,model=virtio-net-pci \
    -no-reboot
