#!/usr/bin/env bash
set -euo pipefail

TARGET="/mnt"
HOSTNAME="sextante"
KEYBOARD="${1:-latam}"

case "$KEYBOARD" in
    latam)
        CONSOLE_KEYMAP="la-latin1"
        XKB_LAYOUT="latam"
        ;;
    es)
        CONSOLE_KEYMAP="es"
        XKB_LAYOUT="es"
        ;;
    us)
        CONSOLE_KEYMAP="us"
        XKB_LAYOUT="us"
        ;;
    *)
        echo "ERROR: Distribución de teclado no válida: $KEYBOARD"
        exit 1
        ;;
esac
echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "        CONFIGURANDO SISTEMA"
echo "=========================================="

# ---------------------------------------------------------
# 1. Verificar sistema destino
# ---------------------------------------------------------

if ! mountpoint -q "$TARGET"; then
    echo "ERROR: $TARGET no está montado."
    exit 1
fi

if [[ ! -x "$TARGET/usr/bin/pacman" ]]; then
    echo "ERROR: No se encontró un sistema Arch válido en $TARGET."
    exit 1
fi

# ---------------------------------------------------------
# 2. Zona horaria
# ---------------------------------------------------------

echo "[1/8] Configurando zona horaria..."

arch-chroot "$TARGET" ln -sf \
    /usr/share/zoneinfo/America/Mexico_City \
    /etc/localtime

arch-chroot "$TARGET" hwclock --systohc

# ---------------------------------------------------------
# 3. Idioma
# ---------------------------------------------------------

echo "[2/8] Configurando idioma..."

sed -i \
    's/^#es_MX.UTF-8 UTF-8/es_MX.UTF-8 UTF-8/' \
    "$TARGET/etc/locale.gen"

sed -i \
    's/^#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' \
    "$TARGET/etc/locale.gen"

arch-chroot "$TARGET" locale-gen

cat > "$TARGET/etc/locale.conf" <<EOF
LANG=es_MX.UTF-8
EOF

cat > "$TARGET/etc/vconsole.conf" <<EOF
KEYMAP=$CONSOLE_KEYMAP
EOF

# Configuración de teclado para Plasma
mkdir -p "$TARGET/etc/skel/.config"

cat > "$TARGET/etc/skel/.config/kxkbrc" <<EOF
[Layout]
LayoutList=$XKB_LAYOUT
Use=true
EOF

# ---------------------------------------------------------
# 4. Hostname
# ---------------------------------------------------------

echo "[3/8] Configurando hostname..."

echo "$HOSTNAME" > "$TARGET/etc/hostname"

cat > "$TARGET/etc/hosts" <<EOF
127.0.0.1 localhost
::1       localhost
127.0.1.1 ${HOSTNAME}.localdomain ${HOSTNAME}
EOF

# ---------------------------------------------------------
# 5. Red
# ---------------------------------------------------------

echo "[4/8] Habilitando NetworkManager..."

arch-chroot "$TARGET" systemctl enable NetworkManager

# ---------------------------------------------------------
# 6. Entorno gráfico
# ---------------------------------------------------------

echo "[5/8] Configurando modo gráfico..."

arch-chroot "$TARGET" systemctl set-default graphical.target

if arch-chroot "$TARGET" pacman -Q sddm &>/dev/null; then
    echo "[6/8] Habilitando SDDM..."
    arch-chroot "$TARGET" systemctl enable sddm
else
    echo "[6/8] AVISO: SDDM no está instalado."
fi

# ---------------------------------------------------------
# 7. Initramfs
# ---------------------------------------------------------

echo "[7/8] Configurando initramfs..."

MKINIT="$TARGET/etc/mkinitcpio.conf"

if [[ ! -f "$MKINIT" ]]; then
    echo "ERROR: No existe $MKINIT"
    exit 1
fi

echo "Configurando módulos para almacenamiento USB..."

if grep -q '^MODULES=' "$MKINIT"; then
    sed -i \
        's/^MODULES=.*/MODULES=(usb_storage uas)/' \
        "$MKINIT"
else
    echo 'MODULES=(usb_storage uas)' >> "$MKINIT"
fi

# ---------------------------------------------------------
# Limpiar posibles restos de ArchISO
# ---------------------------------------------------------

echo "Eliminando posibles configuraciones residuales de ArchISO..."

rm -f "$TARGET/etc/mkinitcpio.conf.d/archiso.conf"

# ---------------------------------------------------------
# Verificar preset normal de Linux
# ---------------------------------------------------------

LINUX_PRESET="$TARGET/etc/mkinitcpio.d/linux.preset"

if [[ ! -f "$LINUX_PRESET" ]]; then
    echo "ERROR: No existe $LINUX_PRESET"
    exit 1
fi

# Una instalación normal debe utilizar el preset default.
# Si por alguna razón existe un preset heredado de ArchISO,
# se reemplaza por uno normal.

if grep -q "PRESETS=('archiso')" "$LINUX_PRESET"; then

    echo "Detectado preset residual de ArchISO."
    echo "Restaurando preset normal de Linux..."

    cat > "$LINUX_PRESET" <<'EOF'
PRESETS=('default')

ALL_kver="/boot/vmlinuz-linux"

default_image="/boot/initramfs-linux.img"
EOF

fi

# ---------------------------------------------------------
# Regenerar initramfs DENTRO del sistema instalado
# ---------------------------------------------------------

echo "Regenerando initramfs del sistema destino..."

arch-chroot "$TARGET" mkinitcpio -P

# ---------------------------------------------------------
# Verificar resultado
# ---------------------------------------------------------

if [[ ! -f "$TARGET/boot/initramfs-linux.img" ]]; then
    echo "ERROR: No se generó /boot/initramfs-linux.img"
    exit 1
fi

echo "Initramfs generado correctamente."

# ---------------------------------------------------------
# 8. Verificación final
# ---------------------------------------------------------

echo "[8/8] Verificando configuración..."

echo
echo "Hostname:"
cat "$TARGET/etc/hostname"

echo
echo "Locale:"
cat "$TARGET/etc/locale.conf"

echo
echo "Target de arranque:"
arch-chroot "$TARGET" systemctl get-default

echo
echo "Módulos de initramfs:"
grep '^MODULES=' "$TARGET/etc/mkinitcpio.conf"

echo
echo "Preset de mkinitcpio:"
cat "$TARGET/etc/mkinitcpio.d/linux.preset"

echo
echo "=========================================="
echo "       CONFIGURACION COMPLETADA"
echo "=========================================="
