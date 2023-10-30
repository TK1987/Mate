#!/bin/bash

# Wenn Fehler auftritt, Skript beenden
set -e

tput civis

cat << -- >> /etc/bash.bashrc
for SH in /etc/profile.d/*.sh;do
  source \$SH
done

export SUDO_ASKPASS='/usr/local/sbin/sudo_askpass.sh'
shopt -s nocaseglob
--

# Groß- und Kleinschreibung bei Bash-Autovervollständigung nicht berücksichtigen
perl -pi -e 's/^#(force_color_prompt)/\1/' /etc/skel/.bashrc
echo "set completion-ignore-case on" >> /etc/inputrc

# Apport deaktivieren
sed -i -E 's#^(enabled=).*$#\10#' /etc/default/apport

# Nano anpassen - Zeilennummern anzeigen, Tabsize=2, Tabs in Leerzeichen umwandeln
sed -i -E -e 's/^ *# *(set *(linenumbers|tabsize|tabstospaces))/\1/g' -e 's/(set *tabsize )*[0-9]+/\12/g' /etc/nanorc

# plymouth theme aktivieren
update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth /usr/share/plymouth/themes/tk87/tk87.plymouth 160

systemctl disable unattended-upgrades.service update-notifier-download.timer update-notifier-motd.timer apt-daily-upgrade.{service,timer} 2>/dev/null

# Paketliste laden
APT="$(wget -qcO- https://raw.github.com/tk1987/mate/master/apt.lst|xargs) $(check-language-support|xargs) /tmp/teamviewer_amd64.deb"

# Teamviewer herunterladen
wget --show-progress -qcP /tmp https://download.teamviewer.com/download/linux/teamviewer_amd64.deb

# Powershell herunterladen
source /etc/os-release
if wget -qcO /dev/null https://packages.microsoft.com/config/ubuntu/$VERSION_ID;then
  wget --show-progress -qcP /tmp https://packages.microsoft.com/config/ubuntu/$VERSION_ID/packages-microsoft-prod.deb
  apt install -y /tmp/packages-microsoft-prod.deb
  APT="$APT powershell"
else
  URL=$(wget -qcO- https://api.github.com/repos/powershell/powershell/releases/latest | grep -ioP '(?<="browser_download_url": ")[^"]+amd64.deb')
  if [ ! -z "$URL" ];then
    wget -qcO /tmp/powershell.deb $URL
    APT="$APT /tmp/powershell.deb"
  fi
fi

# Pakete installieren
if [ -z "$APT" ];then
  return 1
fi
add-apt-repository -y universe
add-apt-repository -y ppa:unit193/encryption
apt -y full-upgrade $APT
apt autoremove -y --purge evolution* deja-dup*

# Glib-Schemas setzen
glib-compile-schemas /usr/share/glib-2.0/schemas

# Setze für alle User, die neu angelegt werden Extragroups
sed -i -E -e 's/^#?(EXTRA_GROUPS=).*/\1"dialout cdrom floppy audio video plugdev users sambashare sudo"/' -e 's/#?(ADD_EXTRA_GROUPS=)/\1/'  /etc/adduser.conf

tput cnorm
