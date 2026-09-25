#!/usr/bin/env bash
set -euo pipefail

TARGET="/mnt"

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "          INSTALANDO GRUB"
echo "=========================================="

if ! mountpoint -q "$TARGET"; then
    echo "ERROR: $TARGET no está montado."
    exit 1
fi

if ! mountpoint -q "$TARGET/boot/efi"; then
    echo "ERROR: $TARGET/boot/efi no está montado."
    exit 1
fi

echo "[1/5] Verificando GRUB..."

if ! arch-chroot "$TARGET" pacman -Q grub &>/dev/null; then
    echo "ERROR: GRUB no está instalado."
    exit 1
fi

echo "[2/5] Instalando cargador UEFI..."

arch-chroot "$TARGET" grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id="Sextante Linux"

echo "Instalando cargador UEFI de respaldo..."

arch-chroot "$TARGET" grub-install \
    --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --removable \
    --no-nvram

echo "[3/5] Configurando nombre de distribución..."

if grep -q '^GRUB_DISTRIBUTOR=' "$TARGET/etc/default/grub"; then
    sed -i \
        's/^GRUB_DISTRIBUTOR=.*/GRUB_DISTRIBUTOR="Sextante"/' \
        "$TARGET/etc/default/grub"
else
    echo 'GRUB_DISTRIBUTOR="Sextante"' >> "$TARGET/etc/default/grub"
fi

echo "[4/5] Generando grub.cfg..."

arch-chroot "$TARGET" grub-mkconfig \
    -o /boot/grub/grub.cfg

echo "[5/5] Verificando..."

if [[ ! -f "$TARGET/boot/grub/grub.cfg" ]]; then
    echo "ERROR: No se generó grub.cfg."
    exit 1
fi

if [[ ! -f "$TARGET/boot/efi/EFI/Sextante Linux/grubx64.efi" ]]; then
    echo "ERROR: No se encontró el cargador UEFI de Sextante."
    exit 1
fi

if [[ ! -f "$TARGET/boot/efi/EFI/BOOT/BOOTX64.EFI" ]]; then
    echo "ERROR: No se creó el cargador UEFI de respaldo BOOTX64.EFI."
    exit 1
fi

echo "OK: cargador UEFI de Sextante encontrado."
echo "OK: cargador UEFI fallback EFI/BOOT/BOOTX64.EFI encontrado."

echo
echo "=========================================="
echo "          GRUB INSTALADO"
echo "=========================================="
