#!/usr/bin/env bash

set -u

echo "=========================================="
echo "       SEXTANTE LINUX INSTALLER v0.1"
echo "          Detector de discos"
echo "=========================================="
echo

echo "Discos físicos detectados:"
echo

lsblk -d \
    -o NAME,SIZE,MODEL,TRAN,TYPE \
    -e 7,11 \
    | awk 'NR==1 || $NF=="disk"'

echo
echo "------------------------------------------"
echo "Este módulo es SOLO LECTURA."
echo "No se ha modificado ningún disco."
echo "------------------------------------------"
