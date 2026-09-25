#!/usr/bin/env bash

VERSION="0.1"
MODE="DRY-RUN"
ALLOW_LIVE=false

# ------------------------------------------
# Opciones de desarrollo
# ------------------------------------------

if [[ "${1:-}" == "--dev-allow-live" ]]; then
    ALLOW_LIVE=true
    shift
fi

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v$VERSION"
echo "             MOTOR $MODE"
echo "=========================================="
echo

# ------------------------------------------
# Recibir disco destino
# ------------------------------------------

if [[ $# -ne 1 ]]; then
    echo "Uso normal:"
    echo "  $0 /dev/disco"
    echo
    echo "Modo laboratorio:"
    echo "  $0 --dev-allow-live /dev/disco"
    exit 1
fi

TARGET="$1"
# ------------------------------------------
# Validaciones básicas
# ------------------------------------------

if [[ ! -b "$TARGET" ]]; then
    echo "ERROR: $TARGET no es un dispositivo válido."
    exit 1
fi

TYPE=$(lsblk -dn -o TYPE "$TARGET")

if [[ "$TYPE" != "disk" ]]; then
    echo "ERROR: $TARGET no es un disco completo."
    exit 1
fi

SIZE_BYTES=$(lsblk -bdn -o SIZE "$TARGET")

if (( SIZE_BYTES < 10737418240 )); then
    echo "ERROR: El disco debe tener al menos 10 GiB."
    exit 1
fi

# ------------------------------------------
# Protección del sistema actual
# ------------------------------------------

ROOT_SOURCE=$(findmnt -no SOURCE /)

ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SOURCE" 2>/dev/null | head -n1)

if [[ -n "$ROOT_DISK" && "$TARGET" == "/dev/$ROOT_DISK" ]]; then
    echo "ERROR DE SEGURIDAD:"
    echo "$TARGET contiene el sistema actualmente en ejecución."
    echo "Instalación cancelada."
    exit 1
fi

# ------------------------------------------
# Protección de Sextante Live
# ------------------------------------------

while IFS= read -r label; do

    if [[ "$ALLOW_LIVE" == false ]] &&
       [[ "$label" == SEXTANTE_* || "$label" == "ARCHISO_EFI" ]]; then

        echo "ERROR DE SEGURIDAD:"
        echo "$TARGET contiene Sextante Live."
        echo "Instalación cancelada."
        exit 1
    fi

done < <(lsblk -nr -o LABEL "$TARGET")
# ------------------------------------------
# Determinar nombres de particiones
# ------------------------------------------

if [[ "$TARGET" =~ (nvme|mmcblk) ]]; then
    EFI="${TARGET}p1"
    ROOT="${TARGET}p2"
else
    EFI="${TARGET}1"
    ROOT="${TARGET}2"
fi

echo "Disco destino:"
lsblk -d -o NAME,SIZE,MODEL,TRAN "$TARGET"

echo
echo "=========================================="
echo "        PLAN DE INSTALACIÓN"
echo "=========================================="

echo
echo "1. Crear tabla GPT"
echo "   $TARGET"

echo
echo "2. Crear partición EFI"
echo "   $EFI"
echo "   Tamaño: 1 GiB"
echo "   Sistema: FAT32"

echo
echo "3. Crear partición raíz"
echo "   $ROOT"
echo "   Tamaño: resto del disco"
echo "   Sistema: ext4"

echo
echo "4. Montar sistema"
echo "   $ROOT -> /mnt"
echo "   $EFI  -> /mnt/boot"

echo
echo "5. Copiar Sextante Linux"
echo "   Live -> /mnt"

echo
echo "6. Generar fstab"
echo "   genfstab -U /mnt"

echo
echo "7. Configurar sistema"
echo "   hostname"
echo "   locale"
echo "   zona horaria"
echo "   usuario"
echo "   contraseña"

echo
echo "8. Instalar GRUB"
echo "   grub-install --target=x86_64-efi"
echo "   grub-mkconfig -o /boot/grub/grub.cfg"

echo
echo "9. Verificar instalación"
echo "   kernel"
echo "   initramfs"
echo "   grub.cfg"
echo "   EFI"

echo
echo "=========================================="
echo "             DRY-RUN COMPLETO"
echo "=========================================="
echo
echo "NO SE HA MODIFICADO NINGÚN DISCO."
