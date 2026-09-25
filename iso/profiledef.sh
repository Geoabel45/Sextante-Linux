#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="sextantelinux"
iso_label="SEXTANTE_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Sextante Linux"
iso_application="Sextante  Linux Live/Installation Media"
iso_version="1.0"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86,arm64' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/home/sextante"]="1000:1000:755"
  ["/usr/local/bin/sextante-plasma-setup"]="0:0:755"
  ["/usr/local/bin/sextante-installer"]="0:0:755"

  ["/usr/local/bin/sextante-installer"]="0:0:755"

  # Instalador propio de Sextante Linux
  ["/opt/sextanteproj/installer/install.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/detect-disks.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/configure-system.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/create-user.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/install-grub.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/partition-disk.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/install-system.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/select-disk.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/install-branding.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/mount-target.sh"]="0:0:755"
  ["/opt/sextanteproj/installer/bin/install-engine.sh"]="0:0:755"

)
