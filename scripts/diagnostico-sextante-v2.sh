#!/usr/bin/env bash

# ============================================================
# Sextante Linux - Diagnóstico previo a compilación V2
# ============================================================

PROJECT="/home/geoabel/SextanteLinux"
ISO="$PROJECT/iso"
AIROOT="$ISO/airootfs"
PKG="$ISO/packages.x86_64"
CAL="$AIROOT/etc/calamares"
HOMEISO="$AIROOT/home/sextante"
REPORTDIR="$PROJECT/diagnosticos"
DATE="$(date +%Y%m%d-%H%M%S)"
REPORT="$REPORTDIR/diagnostico-v2-$DATE.txt"

PASS=0
WARN=0
FAIL=0

mkdir -p "$REPORTDIR"

exec > >(tee "$REPORT") 2>&1

pass() {
    echo "[PASS] $*"
    PASS=$((PASS + 1))
}

warn() {
    echo "[WARN] $*"
    WARN=$((WARN + 1))
}

fail() {
    echo "[FAIL] $*"
    FAIL=$((FAIL + 1))
}

section() {
    echo
    echo "========== $* =========="
}

package_exists() {
    grep -qx "$1" "$PKG" 2>/dev/null
}

echo "============================================================"
echo " SEXTANTE LINUX - PREFLIGHT V2"
echo "============================================================"
echo "Fecha:    $(date)"
echo "Proyecto: $PROJECT"
echo "Reporte:  $REPORT"

# ------------------------------------------------------------
section "1. ESTRUCTURA DEL PROYECTO"

for path in \
    "$PROJECT" \
    "$ISO" \
    "$AIROOT" \
    "$PROJECT/scripts" \
    "$PROJECT/config" \
    "$PROJECT/packages"
do
    if [[ -e "$path" ]]; then
        pass "$path"
    else
        fail "No existe: $path"
    fi
done

[[ -f "$ISO/profiledef.sh" ]] \
    && pass "profiledef.sh" \
    || fail "Falta profiledef.sh"

[[ -f "$PKG" ]] \
    && pass "packages.x86_64" \
    || fail "Falta packages.x86_64"

# ------------------------------------------------------------
section "2. HERRAMIENTAS DEL HOST"

for cmd in bash pacman mkarchiso grub-mkconfig grep awk sed find; do
    if command -v "$cmd" >/dev/null 2>&1; then
        pass "$cmd"
    else
        fail "No disponible en host: $cmd"
    fi
done

# ------------------------------------------------------------
section "3. CALAMARES"

if [[ -d "$CAL" ]]; then
    pass "Directorio Calamares"
else
    fail "No existe configuración Calamares"
fi

for file in \
    "$CAL/settings.conf" \
    "$CAL/modules/unpackfs.conf" \
    "$CAL/modules/bootloader.conf" \
    "$CAL/modules/shellprocess-mkinitcpio.conf"
do
    if [[ -f "$file" ]]; then
        pass "$(basename "$file")"
    else
        fail "Falta $file"
    fi
done

# ------------------------------------------------------------
section "4. UNPACKFS"

UNPACK="$CAL/modules/unpackfs.conf"

if grep -q 'airootfs\.sfs' "$UNPACK" 2>/dev/null; then
    pass "unpackfs utiliza airootfs.sfs"
else
    fail "unpackfs no referencia airootfs.sfs"
fi

if grep -q 'destination: ""' "$UNPACK" 2>/dev/null; then
    pass "Destino raíz de unpackfs correcto"
else
    fail "Destino raíz de unpackfs no detectado"
fi

if grep -q 'destination: "/boot/vmlinuz-linux"' "$UNPACK" 2>/dev/null; then
    fail "unpackfs todavía intenta copiar manualmente vmlinuz-linux"
else
    pass "unpackfs no contiene copia problemática de vmlinuz"
fi

# ------------------------------------------------------------
section "5. KERNEL / INITRAMFS"

if package_exists "linux"; then
    pass "Paquete linux incluido"
else
    fail "Paquete linux NO incluido"
fi

if package_exists "linux-firmware"; then
    pass "linux-firmware incluido"
else
    warn "linux-firmware no aparece"
fi

MKCONF="$CAL/modules/shellprocess-mkinitcpio.conf"

if grep -q '/usr/lib/modules' "$MKCONF" 2>/dev/null; then
    pass "mkinitcpio localiza kernel en /usr/lib/modules"
else
    fail "No se detecta localización del kernel"
fi

if grep -q '/boot/vmlinuz-linux' "$MKCONF" 2>/dev/null; then
    pass "Se prepara /boot/vmlinuz-linux"
else
    fail "No se prepara /boot/vmlinuz-linux"
fi

if grep -q 'mkinitcpio -p linux' "$MKCONF" 2>/dev/null; then
    pass "Generación de initramfs configurada"
else
    fail "No se detecta mkinitcpio -p linux"
fi

# ------------------------------------------------------------
section "6. GRUB"

GRUBFILE="$AIROOT/etc/default/grub"

if package_exists "grub"; then
    pass "GRUB incluido"
else
    fail "GRUB no está en packages.x86_64"
fi

if package_exists "efibootmgr"; then
    pass "efibootmgr incluido"
else
    fail "efibootmgr no incluido"
fi

if [[ -f "$GRUBFILE" ]]; then
    pass "/etc/default/grub presente"
else
    fail "/etc/default/grub ausente"
fi

if grep -q 'GRUB_DISTRIBUTOR="Sextante Linux"' "$GRUBFILE" 2>/dev/null; then
    pass "GRUB_DISTRIBUTOR = Sextante Linux"
else
    warn "Branding GRUB no detectado"
fi

if grep -q 'quiet splash' "$GRUBFILE" 2>/dev/null; then
    pass "GRUB configurado con quiet splash"
else
    warn "quiet splash no encontrado"
fi

if grep -q 'efiBootLoader: "grub"' "$CAL/modules/bootloader.conf" 2>/dev/null; then
    pass "Calamares configurado para GRUB"
else
    fail "Calamares no parece configurado para GRUB"
fi

# ------------------------------------------------------------
section "7. ORDEN DE INSTALACIÓN"

SETTINGS="$CAL/settings.conf"

line_unpack="$(grep -n -- '- unpackfs' "$SETTINGS" | head -1 | cut -d: -f1)"
line_mk="$(grep -n -- 'shellprocess@mkinitcpio' "$SETTINGS" | head -1 | cut -d: -f1)"
line_grub="$(grep -n -- '- bootloader' "$SETTINGS" | head -1 | cut -d: -f1)"
line_clean="$(grep -n -- 'shellprocess@cleanup' "$SETTINGS" | head -1 | cut -d: -f1)"

if [[ -n "$line_unpack" && -n "$line_mk" && -n "$line_grub" ]] &&
   (( line_unpack < line_mk && line_mk < line_grub )); then
    pass "Orden unpackfs -> mkinitcpio -> bootloader"
else
    fail "Orden de kernel/GRUB incorrecto o incompleto"
fi

if [[ -n "$line_clean" && -n "$line_grub" ]] &&
   (( line_grub < line_clean )); then
    pass "Cleanup posterior a bootloader"
else
    warn "No se confirma cleanup posterior a GRUB"
fi

# ------------------------------------------------------------
section "8. USUARIO LIVE"

if grep -q '^sextante:x:1000:1000:' "$AIROOT/etc/passwd" 2>/dev/null; then
    pass "Usuario sextante UID/GID 1000"
else
    fail "Usuario Live sextante incorrecto"
fi

if grep -q 'User=sextante' "$AIROOT/etc/sddm.conf.d/autologin.conf" 2>/dev/null; then
    pass "SDDM Autologin = sextante"
else
    fail "Autologin de sextante no detectado"
fi

if [[ -d "$HOMEISO" ]]; then
    OWNER="$(stat -c '%u:%g' "$HOMEISO")"

    if [[ "$OWNER" == "1000:1000" ]]; then
        pass "/home/sextante propietario 1000:1000"
    else
        fail "/home/sextante propietario $OWNER; esperado 1000:1000"
    fi
else
    fail "/home/sextante no existe"
fi

BADOWNER="$(find "$HOMEISO" -xdev ! -uid 1000 -print -quit 2>/dev/null)"

if [[ -z "$BADOWNER" ]]; then
    pass "Contenido de HOME pertenece a UID 1000"
else
    fail "Archivo con propietario incorrecto: $BADOWNER"
fi

# ------------------------------------------------------------
section "9. LANZADORES KDE"

DESKTOP="$HOMEISO/Desktop"

for desktop in \
    qgis.desktop \
    grass.desktop \
    librecad.desktop \
    sextante-installer.desktop
do
    FILE="$DESKTOP/$desktop"

    if [[ ! -f "$FILE" ]]; then
        warn "No existe $desktop"
        continue
    fi

    if [[ -x "$FILE" ]]; then
        pass "$desktop ejecutable"
    else
        fail "$desktop no tiene permiso de ejecución"
    fi
done

# ------------------------------------------------------------
section "10. APLICACIONES"

for pkg in \
    qgis \
    grass \
    libreoffice-fresh \
    libreoffice-fresh-es \
    freecad \
    librecad \
    gdal \
    proj
do
    if package_exists "$pkg"; then
        pass "$pkg incluido"
    else
        fail "$pkg NO incluido"
    fi
done

# ------------------------------------------------------------
section "11. PAQUETES RETIRADOS"

if grep -qiE 'pgadmin|gvsig' "$PKG"; then
    fail "pgAdmin/gvSIG todavía aparecen en packages.x86_64"
else
    pass "pgAdmin y gvSIG ausentes de packages.x86_64"
fi

if find "$AIROOT" -iname '*gvsig*' -print -quit 2>/dev/null | grep -q .; then
    fail "Quedan archivos residuales de gvSIG en airootfs"
else
    pass "Sin residuos de gvSIG"
fi

# ------------------------------------------------------------
section "12. PLYMOUTH / BRANDING"

if package_exists "plymouth"; then
    pass "Plymouth incluido"
else
    warn "Plymouth no incluido"
fi

if [[ -d "$CAL/branding/sextantelinux" ]]; then
    pass "Branding Calamares Sextante Linux"
else
    fail "Branding Calamares no encontrado"
fi

if find "$AIROOT" -iname '*sextante*' -print -quit 2>/dev/null | grep -q .; then
    pass "Recursos Sextante encontrados"
else
    warn "No se encontraron recursos Sextante"
fi

# ------------------------------------------------------------
section "13. OCTOPI"

if package_exists "octopi"; then
    warn "Octopi incluido; revisar si realmente queremos mantenerlo"
else
    pass "Octopi ausente (ISO más ligera)"
fi

# ------------------------------------------------------------
section "RESULTADO"

echo "PASS=$PASS"
echo "WARN=$WARN"
echo "FAIL=$FAIL"
echo

if (( FAIL > 0 )); then
    echo "RESULTADO: NO COMPILAR"
    echo "Hay $FAIL error(es) crítico(s)."
    EXIT=2
elif (( WARN > 0 )); then
    echo "RESULTADO: REVISAR ANTES DE COMPILAR"
    echo "No hay errores críticos, pero existen $WARN advertencia(s)."
    EXIT=1
else
    echo "RESULTADO: APTO PARA COMPILAR"
    EXIT=0
fi

echo
echo "Reporte:"
echo "$REPORT"
echo "============================================================"

exit "$EXIT"
