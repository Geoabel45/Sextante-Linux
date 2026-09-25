#!/usr/bin/env bash
set -euo pipefail

PROJECT="$HOME/SextanteLinux"
ISO="$PROJECT/build/sextantelinux-beta4-x86_64.iso"
DISK="$PROJECT/lab/sextante-branding-test.qcow2"
VARS="$PROJECT/lab/OVMF_VARS-branding.fd"

OVMF_CODE="/usr/share/edk2/x64/OVMF_CODE.4m.fd"
OVMF_TEMPLATE="/usr/share/edk2/x64/OVMF_VARS.4m.fd"

if [[ ! -f "$ISO" ]]; then
    echo "ERROR: No existe la ISO:"
    echo "$ISO"
    exit 1
fi

if [[ ! -f "$DISK" ]]; then
    echo "ERROR: No existe el disco virtual:"
    echo "$DISK"
    exit 1
fi

if [[ ! -f "$OVMF_CODE" || ! -f "$OVMF_TEMPLATE" ]]; then
    echo "ERROR: No se encontró OVMF."
    exit 1
fi

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
echo "=== Laboratorio Sextante Linux ==="
echo "ISO:   $ISO"
echo "Disco: $DISK"
echo

exec qemu-system-x86_64 \
    "${ACCEL[@]}" \
    -machine q35 \
    -m 4096 \
    -smp 4 \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$VARS" \
    -drive file="$DISK",format=qcow2,if=virtio \
    -drive id=cdrom,if=none,format=raw,readonly=on,file="$ISO" \
    -device ide-cd,drive=cdrom \
    -boot menu=on,order=d \
    -device virtio-vga \
    -display gtk \
    -usb \
    -device usb-tablet \
    -virtfs local,path="$PROJECT",mount_tag=sextanteproj,security_model=none,readonly=on \
    -nic user,model=virtio-net-pci \
    -no-reboot
    
