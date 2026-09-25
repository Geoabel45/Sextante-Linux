#!/usr/bin/env bash
set -euo pipefail

TARGET="/mnt"

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "           CREAR USUARIO"
echo "=========================================="

if [[ $# -lt 1 ]]; then
    echo "Uso:"
    echo "  $0 usuario"
    exit 1
fi

USERNAME="$1"
PASSWORD_MODE="${2:-}"

if ! [[ "$USERNAME" =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "ERROR: Nombre de usuario inválido."
    exit 1
fi

if arch-chroot "$TARGET" id "$USERNAME" &>/dev/null; then
    echo "El usuario $USERNAME ya existe."
else
    echo "Creando usuario $USERNAME..."

    arch-chroot "$TARGET" useradd \
        -m \
        -G wheel \
        -s /bin/bash \
        "$USERNAME"
fi

echo

if [[ "$PASSWORD_MODE" == "--stdin-password" ]]; then
    if ! IFS= read -r PASSWORD; then
        echo "ERROR: No se recibió la contraseña."
        exit 1
    fi

    if [[ -z "$PASSWORD" ]]; then
        echo "ERROR: La contraseña no puede estar vacía."
        exit 1
    fi

    printf '%s:%s\n' "$USERNAME" "$PASSWORD" |
        arch-chroot "$TARGET" chpasswd

    unset PASSWORD
else
    echo "Introduce la contraseña para $USERNAME:"
    arch-chroot "$TARGET" passwd "$USERNAME"
fi

cat > "$TARGET/etc/sudoers.d/10-wheel" <<EOF
%wheel ALL=(ALL:ALL) ALL
EOF

chmod 440 "$TARGET/etc/sudoers.d/10-wheel"

arch-chroot "$TARGET" visudo \
    -cf /etc/sudoers.d/10-wheel

echo
echo "=========================================="
echo "       USUARIO CREADO CORRECTAMENTE"
echo "=========================================="
echo
echo "Usuario: $USERNAME"
