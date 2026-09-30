#!/usr/bin/env bash
set -euo pipefail

INSTALLER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BIN="$INSTALLER_DIR/bin"

NONINTERACTIVE=false

if [[ "${1:-}" == "--non-interactive" ]]; then
    NONINTERACTIVE=true
    shift
fi

PASSWORD=""

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "=========================================="

if [[ $EUID -ne 0 ]]; then
    echo "ERROR: Ejecuta este instalador con sudo."
    exit 1
fi

if [[ $# -lt 3 ]]; then
    echo
    echo "Uso:"
    echo "  sudo $0 /dev/disco usuario"
    echo
    echo "Ejemplo en QEMU:"
    echo "  sudo $0 /dev/vda sextante"
    exit 1
fi

DISK="$1"
USERNAME="$2"
KEYMAP="$3"

if [[ ! -b "$DISK" ]]; then
    echo "ERROR: $DISK no es un dispositivo de bloque."
    exit 1
fi

echo
echo "Disco destino : $DISK"
echo "Usuario       : $USERNAME"
echo
echo "ADVERTENCIA:"
echo "TODO EL CONTENIDO DE $DISK SERA ELIMINADO."
echo

if [[ "$NONINTERACTIVE" == true ]]; then
    if ! IFS= read -r PASSWORD; then
        echo "ERROR: No se recibió la contraseña."
        exit 1
    fi

    if [[ -z "$PASSWORD" ]]; then
        echo "ERROR: La contraseña no puede estar vacía."
        exit 1
    fi
else
    read -r -p "Escribe INSTALAR para continuar: " CONFIRM

    if [[ "$CONFIRM" != "INSTALAR" ]]; then
        echo "Instalación cancelada."
        exit 1
    fi
fi

echo
echo "=========================================="
echo "[1/7] PARTICIONANDO"
echo "=========================================="

if [[ "$NONINTERACTIVE" == true ]]; then
    SEXTANTE_ASSUME_YES=1 /usr/bin/bash "$BIN/partition-disk.sh" "$DISK"
else
    /usr/bin/bash "$BIN/partition-disk.sh" "$DISK"
fi

echo
echo "=========================================="
echo "[2/7] MONTANDO DESTINO"
echo "=========================================="

/usr/bin/bash "$BIN/mount-target.sh" "$DISK"

echo
echo "=========================================="
echo "[3/7] INSTALANDO SISTEMA"
echo "=========================================="

/usr/bin/bash "$BIN/install-system.sh"

echo
echo "=========================================="
echo "[4/7] CONFIGURANDO SISTEMA"
echo "=========================================="

/usr/bin/bash "$BIN/configure-system.sh" "$KEYMAP"

echo
echo "=========================================="
echo "[5/7] INSTALANDO BRANDING"
echo "=========================================="

/usr/bin/bash "$BIN/install-branding.sh"

echo
echo "=========================================="
echo "[6/7] CREANDO USUARIO"
echo "=========================================="

if [[ "$NONINTERACTIVE" == true ]]; then
    printf '%s\n' "$PASSWORD" | /usr/bin/bash "$BIN/create-user.sh" "$USERNAME" --stdin-password
    unset PASSWORD
else
   /usr/bin/bash "$BIN/create-user.sh" "$USERNAME"
fi

echo
echo "=========================================="
echo "[7/7] INSTALANDO GRUB"
echo "=========================================="

/usr/bin/bash "$BIN/install-grub.sh"

echo
echo "=========================================="
echo "       INSTALACION COMPLETADA"
echo "=========================================="

echo
echo "Sextante Linux ha sido instalado en:"
echo "  $DISK"
echo
echo "Usuario:"
echo "  $USERNAME"
echo
echo "Antes de reiniciar puedes verificar:"
echo
echo "  findmnt /mnt"
echo "  arch-chroot /mnt systemctl is-enabled NetworkManager"
echo "  arch-chroot /mnt systemctl is-enabled sddm"
echo
echo "Para finalizar:"
echo
echo "  umount -R /mnt"
echo "  reboot"
