#!/usr/bin/env bash
set -euo pipefail

die() {
    echo
    echo "$1"
    echo
    exit 1
}

TARGET="${1:-}"

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "        PARTICIONADOR DE LABORATORIO"
echo "=========================================="
echo

# --------------------------------------------------
# Comprobaciones básicas
# --------------------------------------------------

[[ $EUID -eq 0 ]] || die "ERROR: Este script debe ejecutarse como root."

[[ -n "$TARGET" ]] || die "Uso: $0 /dev/disco"

[[ -b "$TARGET" ]] || die "ERROR: $TARGET no es un dispositivo de bloques."

TYPE=$(lsblk -dn -o TYPE "$TARGET" 2>/dev/null || true)

[[ "$TYPE" == "disk" ]] || die "ERROR: $TARGET no es un disco completo."

# --------------------------------------------------
# Detectar y proteger el disco del sistema actual
# --------------------------------------------------

ROOT_SOURCE=$(findmnt -no SOURCE / 2>/dev/null || true)
ROOT_DISK=""

if [[ "$ROOT_SOURCE" == /dev/* ]]; then

    ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SOURCE" 2>/dev/null | head -n1 || true)

    if [[ -z "$ROOT_DISK" ]]; then
        ROOT_DISK=$(lsblk -no NAME "$ROOT_SOURCE" 2>/dev/null | head -n1 || true)
    fi
fi

if [[ -n "$ROOT_DISK" && "$TARGET" == "/dev/$ROOT_DISK" ]]; then
    die "ERROR DE SEGURIDAD:
$TARGET contiene el sistema actualmente en ejecución.
Operación cancelada."
fi

# --------------------------------------------------
# Detectar medio Live si existe
# --------------------------------------------------

LIVE_SOURCE=$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null || true)
LIVE_DISK=""

if [[ "$LIVE_SOURCE" == /dev/* ]]; then

    LIVE_DISK=$(lsblk -no PKNAME "$LIVE_SOURCE" 2>/dev/null | head -n1 || true)

    if [[ -z "$LIVE_DISK" ]]; then
        LIVE_DISK=$(lsblk -no NAME "$LIVE_SOURCE" 2>/dev/null | head -n1 || true)
    fi
fi

if [[ -n "$LIVE_DISK" && "$TARGET" == "/dev/$LIVE_DISK" ]]; then
    die "ERROR DE SEGURIDAD:
$TARGET contiene el medio Live de Sextante.
Operación cancelada."
fi

# --------------------------------------------------
# Dependencias
# --------------------------------------------------

for cmd in wipefs sgdisk mkfs.fat mkfs.ext4 partprobe lsblk udevadm; do
    command -v "$cmd" >/dev/null 2>&1 ||
        die "ERROR: Falta la herramienta requerida: $cmd"
done

# --------------------------------------------------
# Tamaño mínimo
# --------------------------------------------------

SIZE_BYTES=$(lsblk -bdn -o SIZE "$TARGET" 2>/dev/null || echo 0)

if (( SIZE_BYTES < 10737418240 )); then
    die "ERROR: El disco debe tener al menos 10 GiB."
fi

SIZE=$(lsblk -dn -o SIZE "$TARGET" | xargs)
MODEL=$(lsblk -dn -o MODEL "$TARGET" 2>/dev/null | xargs || true)
TRAN=$(lsblk -dn -o TRAN "$TARGET" 2>/dev/null | xargs || true)

[[ -z "$MODEL" ]] && MODEL="Sin modelo"
[[ -z "$TRAN" ]] && TRAN="desconocido"

echo "Disco destino:"
echo
echo "  Dispositivo: $TARGET"
echo "  Tamaño:      $SIZE"
echo "  Modelo:      $MODEL"
echo "  Transporte:  $TRAN"
echo

echo "ADVERTENCIA:"
echo "TODO el contenido de $TARGET será eliminado."
echo

CONFIRM_TEXT="BORRAR $TARGET"

if [[ "${SEXTANTE_ASSUME_YES:-0}" == "1" ]]; then
    echo "Confirmación recibida desde el instalador gráfico."
else
    read -rp "Para continuar escribe exactamente: $CONFIRM_TEXT : " CONFIRM

    if [[ "$CONFIRM" != "$CONFIRM_TEXT" ]]; then
        die "Confirmación incorrecta. Operación cancelada."
    fi
fi

# --------------------------------------------------
# Nombres de particiones
# --------------------------------------------------

case "$TARGET" in
    /dev/nvme*|/dev/mmcblk*)
        EFI="${TARGET}p1"
        ROOT="${TARGET}p2"
        ;;
    *)
        EFI="${TARGET}1"
        ROOT="${TARGET}2"
        ;;
esac

echo
echo "[1/6] Desmontando particiones del destino..."

while read -r part; do
    [[ -n "$part" ]] || continue
    umount "$part" 2>/dev/null || true
done < <(lsblk -ln -o PATH "$TARGET" | tail -n +2)

echo "[2/6] Eliminando firmas antiguas..."

wipefs -a "$TARGET"
sgdisk --zap-all "$TARGET"

echo "[3/6] Creando tabla GPT..."

sgdisk -o "$TARGET"

echo "[4/6] Creando particiones..."

sgdisk \
    -n 1:0:+1G \
    -t 1:ef00 \
    -c 1:"SEXTANTE_EFI" \
    "$TARGET"

sgdisk \
    -n 2:0:0 \
    -t 2:8300 \
    -c 2:"SEXTANTE_ROOT" \
    "$TARGET"

partprobe "$TARGET"
udevadm settle

[[ -b "$EFI" ]] ||
    die "ERROR: No apareció la partición EFI $EFI"

[[ -b "$ROOT" ]] ||
    die "ERROR: No apareció la partición raíz $ROOT"

echo "[5/6] Formateando..."

mkfs.fat -F32 -n SEXT_EFI "$EFI"
mkfs.ext4 -F -L SEXTANTE_ROOT "$ROOT"

echo "[6/6] Verificando..."

echo
lsblk -o NAME,SIZE,FSTYPE,LABEL,PARTLABEL,TYPE "$TARGET"

echo
echo "=========================================="
echo "       PARTICIONADO COMPLETADO"
echo "=========================================="
echo
echo "EFI : $EFI"
echo "ROOT: $ROOT"
echo
