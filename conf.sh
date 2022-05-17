#!/bin/bash

# Konfigurationsdateien
FILES=(
  raw.github.com/tk1987/bash/master/upgrade.sh
  raw.github.com/tk1987/mate/master/apt.lst
  raw.github.com/tk1987/mate/master/40_plank.gschema.override
  raw.github.com/tk1987/mate/master/tk87_dock.theme
  raw.github.com/tk1987/mate/master/tk87_panel.layout
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
sudo -A bash -c $'lsblk -lno uuid,fstype |awk \'$2 ~ "^swap" {print "RESUME=UUID="$1}\' >> /etc/initramfs-tools/conf.d/resume'
tput civis

# Apport deaktivieren
sudo -A sed -i -E 's#^(enabled=).*$#\10#' /etc/default/apport

# Konfigurationsdateien an bestimmungsorte schieben
chmod +x upgrade.sh
sudo -A mv upgrade.sh /usr/local/sbin/
sudo -A ln -s --force /usr/local/sbin/upgrade.sh /etc/cron.daily/01_upgrade
sudo -A mkdir -p /usr/share/plank/themes/TK87
sudo -A mv tk87_dock.theme /usr/share/plank/themes/TK87/dock.theme
sudo -A mv 40_plank.gschema.override /usr/share/glib-2.0/schemas/
sudo -A systemctl disable unattended-upgrades.service update-notifier-download.timer update-notifier-motd.timer 2>/dev/null
sudo -A mv tk87_panel.layout /usr/share/mate-panel/layouts/tk87.layout
sudo -A bash -c "echo 'plank' > /usr/share/mate-panel/layouts/tk87.dock"

# Sprachunterstüzung vollständig installieren
LANGS=$(check-language-support)

# Pakete installieren
if [ ! -f "apt.lst" ];then 
  return 1
fi
(sudo -A apt update && cat apt.lst |xargs sudo -A apt-get upgrade -y $LANGS ) &
PID=$!

sudo -A bash -c '
  mkdir -p /etc/skel/.config/plank/dock1/launchers
  cp /usr/share/ubuntu-mate/settings-overlay/config/plank/dock1/launchers/firefox_firefox.dockitem /etc/skel/.config/plank/dock1/launchers/firefox_firefox.dockitem
  cp /usr/share/ubuntu-mate/settings-overlay/config/plank/dock1/launchers/trash.dockitem /etc/skel/.config/plank/dock1/launchers/trash.dockitem
  for app in thunderbird libreoffice-calc libreoffice-writer libreoffice-impress caja gimp smplayer mate-calc;do
    echo -e "[PlankDockItemPreferences]\nLauncher=file:///usr/share/applications/${app}.desktop" > /etc/skel/.config/plank/dock1/launchers/${app}.dockitem
  done
'

if [[ $(date -r $HOME/.config/plank/dock1/launchers "+%y%m%d") == $(date "+%y%m%d") ]];then
  rm -r $HOME/.config/plank/dock1/launchers
  cp -r /etc/skel/.config/plank/dock1/launchers $HOME/.config/plank/dock1/
  gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ dock-items "['firefox_firefox.dockitem', 'thunderbird.dockitem', 'libreoffice-calc.dockitem', 'libreoffice-writer.dockitem', 'libreoffice-impress.dockitem', 'caja.dockitem', 'gimp.dockitem', 'smplayer.dockitem', 'mate-calc.dockitem', 'matecc.dockitem', 'trash.dockitem']" 
fi
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ theme "'TK87'"
gsettings set org.mate.session.required-components dock "plank"
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ hide-mode 'none'
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ alignment 'fill'
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ zoom-percent '110'
gsettings set net.launchpad.plank.dock.settings:/net/launchpad/plank/docks/dock1/ items-alignment 'start'


# Hintergrund setzen
for IMG in $(find /usr/share/backgrounds/|grep andrew|head -n 1);do
  gsettings set org.mate.background picture-filename "$IMG"
  sudo -A sed -i -E "s#^(background=|picture-filename=).*#\1'$IMG'#" /usr/share/glib-2.0/schemas/*  
done

# Glib-Schemas aktualisieren
sudo -A glib-compile-schemas /usr/share/glib-2.0/schemas

# GTK-Theme setzen
for THEME in $(ls -d1 /usr/share/themes/*|grep -ioP "blackmate$|yaru-dark$"|head -n 1);do
  gsettings set org.mate.interface gtk-theme "$THEME"
done

# Panel-Theme setzen
gsettings set org.mate.panel default-layout 'tk87'
export DISPLAY=:0.0
xhost +si:localuser:$( whoami ) >&/dev/null && {
  mate-panel --reset
  killall mate-panel
}

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

# Wenn Autologin für Benutzer aktiv, diesen zur Gruppe nopasswdlogin hinzufügen
if grep -qP "(?<=autologin-user=)${USER}" /etc/lightdm/lightdm.conf; then sudo -A usermod -aG nopasswdlogin $USER;fi

# Willkomennachricht beim start abschalten
echo -n '{"autostart": false, "hide_non_free": false}' > $HOME/.config/ubuntu-mate/welcome/preferences.json

# Icon-Theme setzen
if [ -d /usr/share/icons/Yaru-dark ];then
  gsettings set org.mate.interface icon-theme 'Yaru-dark'
else
  sudo -A sed -i -E "s#^(Inherits=).*#\1Humanity-Dark,Adwaita,hicolor,mate,Yaru#" /usr/share/icons/ubuntu-mono-dark/index.theme
  sudo -A gtk-update-icon-cache /usr/share/icons/ubuntu-mono-dark/
  gsettings set org.mate.interface icon-theme 'ubuntu-mono-dark'
fi

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

sudo -A bash -c '
cat << -- > /etc/skel/.bash_aliases
alias cls="echo -en \'\\ec\'"
alias upgrade="sudo /usr/local/sbin/upgrade.sh"
alias poweroff="sudo /usr/sbin/poweroff"
alias reboot="sudo /usr/sbin/reboot"
--
'
cp /etc/skel/.bash_aliases $HOME/.bash_aliases
. $HOME/.bash_aliases

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