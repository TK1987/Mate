#!/bin/bash

# Konfigurationsdateien
FILES=(
  raw.github.com/tk1987/bash/master/upgrade.sh
  raw.github.com/tk1987/mate/master/apt.lst
)

# Wenn Fehler auftritt, Skript beenden
set -e

mkdir -p $HOME/mate-conf
cd $HOME/mate-conf
cat << -- > sudo_askpass.sh && chmod +x sudo_askpass.sh && export SUDO_ASKPASS=$PWD/sudo_askpass.sh
#!/bin/bash
whiptail --passwordbox "\n[sudo] Passwort für \${USER}: " 9 0 3>&1 1>&2 2>&3
--
sudo -A cp sudo_askpass.sh /usr/local/sbin/
if grep -q "SUDO_ASKPASS=" $HOME/.bashrc;then
  sed -i -E "s#.*(SUDO_ASKPASS=).*#export \1/usr/local/sbin/sudo_askpass.sh#" $HOME/.bashrc
else
  echo "export SUDO_ASKPASS=/usr/local/sbin/sudo_askpass.sh" >> $HOME/.bashrc
fi
if grep -q "SUDO_ASKPASS=" /etc/skel/.bashrc;then
  sudo -A sed -i -E "s#.*(SUDO_ASKPASS=).*#export \1/usr/local/sbin/sudo_askpass.sh#" /etc/skel/.bashrc
else
  sudo -A bash -c 'echo "export SUDO_ASKPASS=/usr/local/sbin/sudo_askpass.sh" >> /etc/skel/.bashrc'
fi

# Konfigurationsdateien herunterladen
wget -c --quiet --show-progress ${FILES[@]}

# Resume Variable für Swap setzen
for swap in $(lsblk -lno uuid,fstype |awk '$2 ~ "^swap" {print "RESUME=UUID="$1}');do
  sudo -A bash -c "echo '$swap' > /etc/initramfs-tools/conf.d/resume"
done
tput civis

# Apport deaktivieren
sudo -A sed -i -E 's#^(enabled=).*$#\10#' /etc/default/apport

# Nano anpassen - Zeilennummern anzeigen, Tabsize=2, Tabs in Leerzeichen umwandeln
sudo -A sed -i -E -e 's/^ *# *(set *(linenumbers|tabsize|tabstospaces))/\1/g' -e 's/(set *tabsize )*[0-9]+/\12/g' /etc/nanorc

# Konfigurationsdateien an bestimmungsorte schieben
chmod +x upgrade.sh
sudo -A mv upgrade.sh /usr/local/sbin/
sudo -A ln -s --force /usr/local/sbin/upgrade.sh /etc/cron.daily/01_upgrade
sudo -A systemctl disable --now unattended-upgrades.service update-notifier-download.timer update-notifier-motd.timer apt-daily-upgrade.{service,timer} 2>/dev/null

# Lightdm Gastzugang deaktivieren
if grep -iqE '^(greeter-)?allow-guest' /etc/lightdm/lightdm.conf; then
  sudo -A sed -i -E 's#^((greeter-)?allow-guest=).*#\1false#g' /etc/lightdm/lightdm.conf
else
  sudo -A bash -c ">>/etc/lightdm/lightdm.conf echo -en 'allow-guest=false\ngreeter-allow-guest=false\n'"
fi

# Sprachunterstüzung vollständig installieren
LANGS=$(check-language-support)

# Pakete installieren
if [ ! -f "apt.lst" ];then 
  return 1
fi
(sudo -A apt update && cat apt.lst |xargs sudo -A apt-get upgrade -y $LANGS ) &
PID=$!

gsettings set org.ayatana.indicator.session suppress-restart-menuitem 'false'
gsettings set org.ayatana.indicator.session suppress-logout-restart-shutdown 'true'

# Hintergrund setzen
if gsettings get org.mate.background picture-filename|grep -qi "green-wall";then
  IMG=$(find /usr/share/backgrounds -name '*andrew*.jpg')
  if [ ! -z "$IMG" ];then
    gsettings set org.mate.background picture-filename "$IMG"
    sudo -A sed -i -E "s#^(background=|picture-filename=).*#\1'$IMG'#" /usr/share/glib-2.0/schemas/*
  fi
fi

# Glib-Schemas aktualisieren
sudo -A glib-compile-schemas /usr/share/glib-2.0/schemas

# Theme setzen
gsettings set org.mate.interface gtk-theme "Yaru-dark"
gsettings set org.mate.interface icon-theme 'Yaru-dark'
gsettings set org.mate.Marco.general theme 'Yaru-dark'

# Persönlichen Ordner und gemountete Partitionen nicht auf Desktop anpinnen
gsettings set org.mate.caja.desktop home-icon-visible false
gsettings set org.mate.caja.desktop volumes-visible false

# Mate-Panel auf Größe=35 pixel setzen.
gsettings set org.mate.panel.toplevel:/org/mate/panel/toplevels/top/ size 35
gsettings set org.mate.panel.toplevel:/org/mate/panel/toplevels/bottom/ size 35

# Bildschirm nicht Sperren, wenn Bildschirmschoner aktiv
gsettings set org.mate.screensaver lock-enabled false

# Wenn Autologin für Benutzer aktiv, diesen zur Gruppe nopasswdlogin hinzufügen
if grep -qP "(?<=autologin-user=)${USER}" /etc/lightdm/lightdm.conf; then sudo -A usermod -aG nopasswdlogin $USER;fi

# Willkomennachricht beim start abschalten
echo -n '{"autostart": false, "hide_non_free": false}' > $HOME/.config/ubuntu-mate/welcome/preferences.json

# Icon-Theme setzen


# Hintergrund beim booten / herunterfahren setzen
sudo -A sed -i -E "s#^(Window.SetBackground[^ ]+ \()[^\)]+#\10, 0, 0#" /usr/share/plymouth/themes/ubuntu-mate-logo/ubuntu-mate-logo.script

# Hintergrund von Grub setzen
sudo -A sed -i -E "s#^(if background_color )[^;]+#\10,0,0#" /usr/share/plymouth/themes/ubuntu-mate-logo/ubuntu-mate-logo.grub

sudo -A bash -c '
umask 2227
cat << -- > /etc/sudoers.d/010_users
Cmnd_Alias POWER = /usr/sbin/reboot, /usr/sbin/poweroff, /usr/local/sbin/upgrade.sh
%users ALL=(ALL) NOPASSWD: POWER
--
'

sudo -A bash -c $'
cat << -- > /etc/profile.d/bash_aliases.sh
#!/bin/bash
alias cls="echo -en \'\\ec\'"
alias upgrade="sudo /usr/local/sbin/upgrade.sh"
alias poweroff="sudo /usr/sbin/poweroff"
alias reboot="sudo /usr/sbin/reboot"
--
'

# Füge Benutzer zur Gruppe users hinzu
sudo -A usermod -aG users $USER

# Setze für alle User, die neu angelegt werden Extragroups
sudo -A sed -i -E -e 's/^#?(EXTRA_GROUPS=).*/\1"dialout cdrom floppy audio video plugdev users sambashare sudo"/'\
  -e 's/#?(ADD_EXTRA_GROUPS=)/\1/'  /etc/adduser.conf

sudo -A update-initramfs -uk all > /dev/null
sudo -A update-grub > /dev/null

while ps -p $PID > /dev/null; do
  sleep 5
done
cd $HOME

# Konfigurationsordner löschen
rm -r $HOME/mate-conf

if whiptail --yesno "Der Computer muss neugestartet werden.\n\nJetzt neustarten?" 0 0 3>&1 1>&2 2>&3;then
  newgrp users <<< 'sudo /usr/sbin/reboot'
fi

tput cnorm