#!/usr/bin/env bash
set -euo pipefail

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "        Selección segura de disco"
echo "=========================================="
echo

# --------------------------------------------------
# Detectar sistema actual
# --------------------------------------------------

ROOT_SOURCE=$(findmnt -no SOURCE / 2>/dev/null || true)
ROOT_DISK=""

# En un sistema instalado normal, / debería venir de /dev/...
# En Archiso Live puede venir de airootfs/overlay.
if [[ "$ROOT_SOURCE" == /dev/* ]]; then

    ROOT_DISK=$(lsblk -no PKNAME "$ROOT_SOURCE" 2>/dev/null | head -n1 || true)

    if [[ -z "$ROOT_DISK" ]]; then
        ROOT_DISK=$(lsblk -no NAME "$ROOT_SOURCE" 2>/dev/null | head -n1 || true)
    fi
fi

echo "Sistema actual:"
echo "  Raíz:  ${ROOT_SOURCE:-desconocida}"

if [[ -n "$ROOT_DISK" ]]; then
    echo "  Disco: /dev/$ROOT_DISK"
    echo
    echo "PROTEGIDO: /dev/$ROOT_DISK"
else
    echo "  Modo Live: raíz sin disco físico asociado"
fi

echo

# --------------------------------------------------
# Detectar discos completos mayores de 1 GiB
# --------------------------------------------------

mapfile -t DISKS < <(
    lsblk -bdn -o NAME,SIZE,TYPE |
    awk '$3=="disk" && $2>1073741824 {print $1}'
)

AVAILABLE=()

echo "Discos detectados:"
echo

# --------------------------------------------------
# Clasificar discos
# --------------------------------------------------

for disk in "${DISKS[@]}"; do

    DEVICE="/dev/$disk"

    size=$(lsblk -dn -o SIZE "$DEVICE" 2>/dev/null | xargs || true)
    model=$(lsblk -dn -o MODEL "$DEVICE" 2>/dev/null | xargs || true)
    tran=$(lsblk -dn -o TRAN "$DEVICE" 2>/dev/null | xargs || true)

    [[ -z "$model" ]] && model="Sin modelo"
    [[ -z "$tran" ]] && tran="desconocido"

    LIVE_DISK=false

    # Detectar si el disco contiene una partición del Live de Sextante.
    while IFS= read -r label; do

        if [[ "$label" == SEXTANTE_* || "$label" == "ARCHISO_EFI" ]]; then
            LIVE_DISK=true
            break
        fi

    done < <(lsblk -nr -o LABEL "$DEVICE" 2>/dev/null || true)

    # Disco del sistema actualmente ejecutándose.
    if [[ -n "$ROOT_DISK" && "$disk" == "$ROOT_DISK" ]]; then

        printf "  [PROTEGIDO-SISTEMA] /dev/%s - %s - %s - %s\n" \
            "$disk" "$size" "$model" "$tran"

    # Medio Live.
    elif [[ "$LIVE_DISK" == true ]]; then

        printf "  [PROTEGIDO-LIVE]    /dev/%s - %s - %s - %s\n" \
            "$disk" "$size" "$model" "$tran"

    # Disco disponible.
    else

        AVAILABLE+=("$disk")

        printf "  [%d] /dev/%s - %s - %s - %s\n" \
            "${#AVAILABLE[@]}" "$disk" "$size" "$model" "$tran"

    fi

done

echo

# --------------------------------------------------
# Si no existen discos seguros, detenerse
# --------------------------------------------------

if (( ${#AVAILABLE[@]} == 0 )); then

    echo "No hay ningún disco disponible para instalar Sextante."
    echo
    echo "El instalador se detiene de forma segura."
    exit 1
fi

# --------------------------------------------------
# Selección
# --------------------------------------------------

read -rp "Seleccione el número del disco destino: " choice

if [[ ! "$choice" =~ ^[0-9]+$ ]]; then
    echo "ERROR: Debe introducir un número."
    exit 1
fi

if (( choice < 1 || choice > ${#AVAILABLE[@]} )); then
    echo "ERROR: Selección fuera de rango."
    exit 1
fi

TARGET="/dev/${AVAILABLE[$((choice-1))]}"

echo
echo "------------------------------------------"
echo "Disco destino seleccionado:"
echo

lsblk -d -o NAME,SIZE,MODEL,TRAN "$TARGET"

echo
echo "TARGET=$TARGET"
echo
