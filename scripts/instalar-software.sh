#!/bin/bash

set -e

echo "======================================"
echo "     Instalador de SextanteLinux"
echo "======================================"

PAQUETES=(
    base-devel
    git
    htop
    dolphin
    nano
    libreoffice-fresh
    libreoffice-fresh-es
    okular
    qgis
    gdal
    proj
    geos
    postgresql
    postgis
)

PAQUETES_AUR=(
    grass
    brave-bin
)

echo "======================================"
echo " Actualizando el sistema"
echo "======================================"

sudo pacman -Syu

echo "======================================"
echo " Instalando paquetes oficiales"
echo "======================================"

for paquete in "${PAQUETES[@]}"; do
    if pacman -Q "$paquete" &>/dev/null; then
        echo "[OK] $paquete ya está instalado."
    else
        echo "[+] Instalando $paquete..."
        sudo pacman -S --needed "$paquete"
    fi
done

echo "======================================"
echo " Comprobando yay"
echo "======================================"

if command -v yay &>/dev/null; then
    echo "[OK] yay está instalado."
else
    echo "[AVISO] yay no está instalado."
    echo "Los paquetes AUR serán omitidos."
fi

if command -v yay &>/dev/null; then

    echo "======================================"
    echo " Instalando paquetes AUR"
    echo "======================================"

    for paquete in "${PAQUETES_AUR[@]}"; do
        if pacman -Q "$paquete" &>/dev/null; then
            echo "[OK] $paquete ya está instalado."
        else
            echo "[AUR] Instalando $paquete..."
            yay -S --needed "$paquete"
        fi
    done



echo "======================================"
echo " SextanteLinux: instalación terminada"
echo "======================================"
fi

echo "======================================"
echo " Configurando PostgreSQL"
echo "======================================"

if [ ! -d "/var/lib/postgres/data/base" ]; then
    echo "[+] Inicializando PostgreSQL..."
    sudo -iu postgres initdb --locale=C.UTF-8 --encoding=UTF8 -D /var/lib/postgres/data
fi

echo "[+] Habilitando PostgreSQL..."
sudo systemctl enable postgresql.service

echo "[+] Iniciando PostgreSQL..."
sudo systemctl start postgresql.service

echo "[+] Comprobando PostGIS..."

sudo -iu postgres psql -d postgres -c "CREATE EXTENSION IF NOT EXISTS postgis;"

echo "[OK] PostgreSQL y PostGIS configurados."

echo "======================================"
echo " SextanteLinux: instalación terminada"
echo "======================================"
