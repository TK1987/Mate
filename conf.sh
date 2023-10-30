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

# Lightdm Gastzugang deaktivieren
if grep -iqE '^(greeter-)?allow-guest' /etc/lightdm/lightdm.conf; then
  sed -i -E 's#^((greeter-)?allow-guest=).*#\1false#g' /etc/lightdm/lightdm.conf
else
  bash -c ">>/etc/lightdm/lightdm.conf echo -en 'allow-guest=false\ngreeter-allow-guest=false\n'"
fi

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
cat << -- > /usr/share/glib-2.0/schemas/40_plank.override
[net.launchpad.plank]
enabled_docks=['dock1']

[net.launchpad.plank.dock.settings]
alignment='fill'
dock-items=['desktop.dockitem', 'firefox_firefox.dockitem', 'caja-browser.dockitem', 'matecc.dockitem', 'mate-system-monitor.dockitem', 'mate-terminal.dockitem', 'mate-calc.dockitem', 'clock.dockitem', 'trash.dockitem']
hide-mode='none'
icon-size=38
items-alignment='start'
position='left'
theme='Mutiny-dark'
zoom-enabled=false
--
perl -pi -e "s/(\[org.mate.session\])/\1\nrequired-components-list=['windowmanager', 'panel', 'filemanager', 'dock']/g" /usr/share/glib-2.0/schemas/10_mate-common.gschema.override
perl -pi -e  "s/^(default-layout=).*/\1'mutiny'/" /usr/share/glib-2.0/schemas/30_ubuntu-mate.gschema.override
perl -pi -e 'BEGIN{undef $/;} s|(\[org.ayatana.indicator.session\]).*?(?=\n\n)|\1\nsuppress-restart-menuitem=false\nsuppress-logout-restart-shutdown=true|smg' /usr/share/glib-2.0/schemas/30_ubuntu-mate.gschema.override
perl -pi -e "s/^((?:gtk|icon)-theme=).*/\1'Yaru-dark'/g" /usr/share/glib-2.0/schemas/20_mate-ubuntu.gschema.override
perl -pi -e "s/^(home-icon-visible=).*/\1false\nvolumes-visible=false/" /usr/share/glib-2.0/schemas/10_mate-common.gschema.override
perl -pi -e "s/(\[org.mate.screensaver\])/\1\nlock-enabled=false/g" /usr/share/glib-2.0/schemas/10_mate-common.gschema.override
perl -pi -e "s/^(lock-enabled=).*/\1false/" /usr/share/glib-2.0/schemas/10_mate-common.gschema.override
perl -pi -e "s#(picture-filename=|background=).*#\1'/usr/share/backgrounds/ubuntu-mate-common/ubuntu-tk87_blue.jpg'#g" /usr/share/glib-2.0/schemas/{30_ubuntu-mate.gschema.override,20_mate-ubuntu.gschema.override}
bash -c "cat << -- >> /usr/share/glib-2.0/schemas/30_ubuntu-mate.gschema.override

[org.mate.panel.toplevel]
expand=true
screen=0
size=36
--
"
glib-compile-schemas /usr/share/glib-2.0/schemas

# Setze für alle User, die neu angelegt werden Extragroups
sed -i -E -e 's/^#?(EXTRA_GROUPS=).*/\1"dialout cdrom floppy audio video plugdev users sambashare sudo"/' -e 's/#?(ADD_EXTRA_GROUPS=)/\1/'  /etc/adduser.conf

tput cnorm
