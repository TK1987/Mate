#!/bin/bash

# Wenn Fehler auftritt, Skript beenden
set -e

# Resume Variable für Swap setzen
lsblk -lno uuid,fstype |awk '$2 ~ "^swap" {print "RESUME=UUID="$1}'| sudo tee /etc/initramfs-tools/conf.d/resume

# Apport deaktivieren
sudo sed -iE 's#^(enabled=).*$#\10#' /etc/default/apport

# Pakete installieren
if [ ! -f "apt.lst" ];then echo -e "\e[31mPaketliste wurde nicht gefunden\e[0m";exit 1;fi
(sudo apt update && cat apt.lst |xargs sudo apt-get upgrade -y) &
PID=$!

# Panel-Theme setzen
gsettings set org.mate.panel default-layout 'ubuntu-mate'
mate-panel --reset

# Hintergrund setzen
for PIC in $(find /usr/share/backgrounds/|grep andrew);do
  gsettings set org.mate.background picture-filename "$PIC"
done

# GTK-Theme setzen
for THEME in $(ls -d /usr/share/themes/*|grep -ioP "blackmate");do
  gsettings set org.mate.interface gtk-theme "$GTK"
done

# Fenster-Theme setzen
for THEME in $(ls -d /usr/share/themes/*|grep -ioP "bluementa");do
  gsettings set org.mate.Marco.general theme "$THEME"
fi

while ps -p $PID >/dev/null; do
  sleep 10
done
