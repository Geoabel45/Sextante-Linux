#!/usr/bin/env bash
set -euo pipefail

TARGET="/mnt"
PROJECT="/opt/sextanteproj"

OFFICIAL_LIST="$PROJECT/packages/oficiales.txt"
AUR_LIST="$PROJECT/packages/aur.txt"

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "          INSTALANDO SISTEMA"
echo "=========================================="

# ---------------------------------------------------------
# 1. Verificaciones
# ---------------------------------------------------------

if ! mountpoint -q "$TARGET"; then
    echo "ERROR: $TARGET no está montado."
    exit 1
fi

if [[ ! -f "$OFFICIAL_LIST" ]]; then
    echo "ERROR: No existe $OFFICIAL_LIST"
    exit 1
fi

echo "[1/6] Preparando lista de paquetes..."

# Eliminar comentarios, espacios y líneas vacías.
mapfile -t OFFICIAL_PACKAGES < <(
    sed \
        -e 's/#.*$//' \
        -e '/^[[:space:]]*$/d' \
        -e 's/^[[:space:]]*//' \
        -e 's/[[:space:]]*$//' \
        "$OFFICIAL_LIST"
)

# Paquetes indispensables aunque no estén todavía
# correctamente incluidos en oficiales.txt
BASE_PACKAGES=(
    base
    linux
    linux-firmware
    grub
    efibootmgr
    networkmanager
    sudo
)

echo "Paquetes oficiales detectados: ${#OFFICIAL_PACKAGES[@]}"

# ---------------------------------------------------------
# 2. Instalar sistema
# ---------------------------------------------------------

echo "[2/6] Instalando sistema base y paquetes oficiales..."

pacstrap -K "$TARGET" \
    "${BASE_PACKAGES[@]}" \
    "${OFFICIAL_PACKAGES[@]}"

# ---------------------------------------------------------
# 3. Generar fstab
# ---------------------------------------------------------

echo "[3/6] Generando fstab..."

genfstab -U "$TARGET" > "$TARGET/etc/fstab"

# ---------------------------------------------------------
# 4. Verificaciones básicas
# ---------------------------------------------------------

echo "[4/6] Verificando kernel..."

if [[ ! -f "$TARGET/boot/vmlinuz-linux" ]]; then
    echo "ERROR: No se encontró vmlinuz-linux."
    exit 1
fi

echo "[5/6] Verificando sistema instalado..."

if [[ ! -x "$TARGET/usr/bin/pacman" ]]; then
    echo "ERROR: pacman no existe en el sistema destino."
    exit 1
fi

# ---------------------------------------------------------
# 5. Información AUR
# ---------------------------------------------------------

if [[ -f "$AUR_LIST" ]]; then
    AUR_COUNT="$(
        sed \
            -e 's/#.*$//' \
            -e '/^[[:space:]]*$/d' \
            "$AUR_LIST" |
        wc -l
    )"

    echo "Paquetes AUR pendientes: $AUR_COUNT"
else
    echo "AVISO: No existe packages/aur.txt"
fi

# ---------------------------------------------------------
# 6. Final
# ---------------------------------------------------------

echo "[6/6] Instalación base completada."

echo
echo "=========================================="
echo "       SISTEMA SEXTANTE INSTALADO"
echo "=========================================="
echo
echo "Destino: $TARGET"
echo
echo "Siguiente etapa:"
echo "  configure-system.sh"
