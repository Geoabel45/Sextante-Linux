#!/usr/bin/env bash
set -euo pipefail

TARGET="/mnt"
AIROOT=""
SDDM_SOURCE="/usr/share/sddm/themes/sextantelinux"
SDDM_CONF_SOURCE="/etc/sddm.conf.d/10-sextantelinux-theme.conf"
WALLPAPER_SOURCE="/usr/share/wallpapers/SextanteLinux"

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "          INSTALANDO BRANDING"
echo "=========================================="

if ! mountpoint -q "$TARGET"; then
    echo "ERROR: $TARGET no está montado."
    exit 1
fi

if [[ ! -d "$SDDM_SOURCE" ]]; then
    echo "ERROR: No existe el tema SDDM de Sextante."
    exit 1
fi

if [[ ! -f "$SDDM_CONF_SOURCE" ]]; then
    echo "ERROR: No existe la configuración SDDM de Sextante."
    exit 1
fi

if [[ ! -d "$WALLPAPER_SOURCE" ]]; then
    echo "ERROR: No existe el wallpaper de Sextante."
    exit 1
fi

echo "[1/5] Instalando tema SDDM..."

mkdir -p "$TARGET/usr/share/sddm/themes"
rm -rf "$TARGET/usr/share/sddm/themes/sextantelinux"
cp -a "$SDDM_SOURCE" "$TARGET/usr/share/sddm/themes/"

echo "[2/5] Configurando SDDM..."

mkdir -p "$TARGET/etc/sddm.conf.d"
cp -a "$SDDM_CONF_SOURCE" "$TARGET/etc/sddm.conf.d/10-sextantelinux-theme.conf"

echo "[3/5] Instalando wallpaper..."

mkdir -p "$TARGET/usr/share/wallpapers"
rm -rf "$TARGET/usr/share/wallpapers/SextanteLinux"
cp -a "$WALLPAPER_SOURCE" "$TARGET/usr/share/wallpapers/"

echo "[4/5] Instalando configuración de Plasma..."
# Instalar iconos personalizados de Sextante
echo "Instalando iconos personalizados..."

mkdir -p "$TARGET/usr/share/pixmaps/sextantelinux"
cp -a "$AIROOT/usr/share/pixmaps/sextantelinux/." \
    "$TARGET/usr/share/pixmaps/sextantelinux/"

# Iconos personalizados para Firefox y Tienda de aplicaciones
mkdir -p "$TARGET/usr/share/icons/sextante"
cp -a "$AIROOT/usr/share/icons/sextante/." \
    "$TARGET/usr/share/icons/sextante/"

# Instalar lanzadores personalizados de Sextante
echo "Instalando lanzadores personalizados..."

mkdir -p "$TARGET/usr/share/applications"

for desktop in \
    sextante-browser.desktop \
    sextante-files.desktop \
    sextante-terminal.desktop \
    sextante-settings.desktop
do
    if [[ ! -f "$AIROOT/usr/share/applications/$desktop" ]]; then
        echo "ERROR: No existe $desktop"
        exit 1
    fi

    cp -a \
        "$AIROOT/usr/share/applications/$desktop" \
        "$TARGET/usr/share/applications/"
done
mkdir -p "$TARGET/usr/local/bin"
cp -a "$AIROOT/usr/local/bin/sextante-plasma-setup" "$TARGET/usr/local/bin/"
chmod +x "$TARGET/usr/local/bin/sextante-plasma-setup"

mkdir -p "$TARGET/etc/skel/.config/autostart"
cp -a "$AIROOT/etc/skel/.config/kdeglobals" "$TARGET/etc/skel/.config/"
cp -a "$AIROOT/etc/skel/.config/plasmarc" "$TARGET/etc/skel/.config/"
cp -a "$AIROOT/etc/skel/.config/autostart/sextante-plasma-setup.desktop" "$TARGET/etc/skel/.config/autostart/"

echo "[5/5] Verificando branding..."

if [[ ! -f "$TARGET/usr/share/sddm/themes/sextantelinux/wallpaperprincipal.svg" ]]; then
    echo "ERROR: No se instaló wallpaperprincipal.svg en SDDM."
    exit 1
fi

if [[ ! -f "$TARGET/usr/share/sddm/themes/sextantelinux/logo.png" ]]; then
    echo "ERROR: No se instaló el logo de Sextante en SDDM."
    exit 1
fi

if [[ ! -f "$TARGET/usr/share/wallpapers/SextanteLinux/contents/images/wallpaperprincipal.svg" ]]; then
    echo "ERROR: No se instaló el wallpaper principal de Plasma."
    exit 1
fi

if [[ ! -x "$TARGET/usr/local/bin/sextante-plasma-setup" ]]; then
    echo "ERROR: No se instaló sextante-plasma-setup."
    exit 1
fi

if [[ ! -f "$TARGET/etc/skel/.config/autostart/sextante-plasma-setup.desktop" ]]; then
    echo "ERROR: No se instaló el autostart de Plasma."
    exit 1
fi
if [[ ! -f "$TARGET/usr/share/pixmaps/sextantelinux/menu-inicio.svg" ]]; then
    echo "ERROR: No se instalaron los iconos personalizados."
    exit 1
fi

for desktop in \
    sextante-browser.desktop \
    sextante-files.desktop \
    sextante-terminal.desktop \
    sextante-settings.desktop
do
    if [[ ! -f "$TARGET/usr/share/applications/$desktop" ]]; then
        echo "ERROR: No se instaló $desktop"
        exit 1
    fi
done

echo "Iconos y lanzadores personalizados instalados correctamente."
echo
echo "=========================================="
echo "       BRANDING SEXTANTE INSTALADO"
echo "=========================================="
