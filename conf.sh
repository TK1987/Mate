#!/bin/bash

# Konfigurationsdateien
FILES=(
  raw.github.com/tk1987/bash/master/upgrade.sh
  raw.github.com/tk1987/mate/master/apt.lst
  raw.github.com/tk1987/mate/master/40_plank.gschema.override
  raw.github.com/tk1987/mate/master/tk87_dock.theme
)

# Wenn Fehler auftritt, Skript beenden
set -e

mkdir -p $HOME/mate-conf
cd $HOME/mate-conf

# Konfigurationsdateien herunterladen
wget -c --quiet --show-progress ${FILES[@]}

# Resume Variable für Swap setzen
sudo bash -c $'lsblk -lno uuid,fstype |awk \'$2 ~ "^swap" {print "RESUME=UUID="$1}\' >> /etc/initramfs-tools/conf.d/resume'

# Apport deaktivieren
sudo sed -i -E 's#^(enabled=).*$#\10#' /etc/default/apport

# Konfigurationsdateien an bestimmungsorte schieben
chmod +x upgrade.sh
sudo mv upgrade.sh /usr/local/sbin/
sudo ln -s --force /usr/local/sbin/upgrade.sh /etc/cron.daily/01_upgrade
sudo mkdir -p /usr/share/plank/themes/TK87
sudo mv tk87_dock.theme /usr/share/plank/themes/TK87/dock.theme
sudo mv 40_plank.gschema.override /usr/share/glib-2.0/schemas/
sudo systemctl disable unattended-upgrades.service update-notifier-download.timer update-notifier-motd.timer 2>/dev/null

# Sprachunterstüzung vollständig installieren
LANGS=$(check-language-support)

# Pakete installieren
if [ ! -f "apt.lst" ];then 
  return 1
fi
(sudo apt update && cat apt.lst |xargs sudo apt-get upgrade -y $LANGS ) &
PID=$!

# Panel-Theme setzen
gsettings set org.mate.panel default-layout 'ubuntu-mate'
if [ -z "$DISPLAY" ];then
  export DISPLAY=:0.0
fi
xhost +si:localuser:$( whoami ) >&/dev/null && { 
  mate-panel --reset
}

# Hintergrund setzen
for IMG in $(find /usr/share/backgrounds/|grep andrew|head -n 1);do
  gsettings set org.mate.background picture-filename "$IMG"
  sudo sed -i -E "s#^(background=|picture-filename=).*#\1'$IMG'#" /usr/share/glib-2.0/schemas/*  
done

# Glib-Schemas aktualisieren
sudo glib-compile-schemas /usr/share/glib-2.0/schemas

# GTK-Theme setzen
for THEME in $(ls -d1 /usr/share/themes/*|grep -ioP "blackmate$|yaru-dark$"|head -n 1);do
  gsettings set org.mate.interface gtk-theme "$THEME"
done

# Fenster-Theme setzen
for THEME in $(ls -d1 /usr/share/themes/*|grep -ioP "bluementa$|yaru-dark$"|head -n 1);do
  gsettings set org.mate.Marco.general theme "$THEME"
done

# Persönlichen Ordner und gemountete Partitionen nicht auf Desktop anpinnen
gsettings set org.mate.caja.desktop home-icon-visible false
gsettings set org.mate.caja.desktop volumes-visible false

# Mate-Panel auf Größe=35 pixel setzen.
gsettings set org.mate.panel.toplevel:/org/mate/panel/toplevels/top/ size 35
gsettings set org.mate.panel.toplevel:/org/mate/panel/toplevels/bottom/ size 35

# Bildschirm nicht Sperren, wenn Bildschirmschoner aktiv
gsettings set org.mate.screensaver lock-enabled false

# Willkomennachricht beim start abschalten
echo -n '{"autostart": false, "hide_non_free": false}' > $HOME/.config/ubuntu-mate/welcome/preferences.json

# Icon-Theme setzen
if [ -d /usr/share/icons/Yaru-dark ];then
  gsettings set org.mate.interface icon-theme 'Yaru-dark'
else
  sudo sed -i -E "s#^(Inherits=).*#\1Humanity-Dark,Adwaita,hicolor,mate,Yaru#" /usr/share/icons/ubuntu-mono-dark/index.theme
  sudo gtk-update-icon-cache /usr/share/icons/ubuntu-mono-dark/
  gsettings set org.mate.interface icon-theme 'ubuntu-mono-dark'
fi

# Hintergrund beim booten / herunterfahren setzen
sudo sed -i -E "s#^(Window.SetBackground[^ ]+ \()[^\)]+#\10, 0, 0#" /usr/share/plymouth/themes/ubuntu-mate-logo/ubuntu-mate-logo.script

# Hintergrund von Grub setzen
sudo sed -i -E "s#^(if background_color )[^;]+#\10,0,0#" /usr/share/plymouth/themes/ubuntu-mate-logo/ubuntu-mate-logo.grub

sudo bash -c '
umask 2227
cat << -- > /etc/sudoers.d/010_users
Cmnd_Alias POWER = /usr/sbin/reboot, /usr/sbin/poweroff, /usr/local/sbin/upgrade.sh
%users ALL=(ALL) NOPASSWD: POWER
--
'

sudo bash -c '
cat << -- > /etc/profile.d/bash_aliases.sh
#!/bin/bash
alias cls="clear"
alias upgrade="sudo /usr/local/sbin/upgrade.sh"
alias poweroff="sudo /usr/sbin/poweroff"
alias reboot="sudo /usr/sbin/reboot"
--
'

# Füge Benutzer zur Gruppe users hinzu
sudo usermod -aG users $USER

# Setze für alle User, die neu angelegt werden Extragroups
sudo sed -i -E -e 's/^#?(EXTRA_GROUPS=).*/\1"dialout cdrom floppy audio video plugdev users sambashare sudo"/'\
  -e 's/#?(ADD_EXTRA_GROUPS=)/\1/'  /etc/adduser.conf

# Profile neu laden
. /etc/profile

set +e
while ps -p $PID >/dev/null; do
  sleep 5
done

# Konfigurationsordner löschen
rm -R $HOME/mate-conf
