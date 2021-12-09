#!/bin/bash

if [ "$EUID" != 0 ];then SU=sudo;fi

mainmenu () {
  local SEL=$( whiptail --menu "Hauptmenü" 0 0 0 --ok-button Ok --cancel-button Beenden \
    1. "Aktualisieren / Pakete installieren" \
    2. "Computerkonfiguration" \
    3. "Benutzerkonfiguration" \
    4. "Fremdsystem reparieren (chroot)" \
    3>&1 1>&2 2>&3
  )
  case ${SEL:0:1} in 1) update;; 2) cconfig;; 3) uconfig;; 4) chrootfs;; esac
}

update () {
  aptls=$( whiptail --checklist "Pakete installieren: " 0 0 0 --ok-button Start --cancel-button Abbruch \
    "gparted"              "Paritionierungswerkzeug"                           on  \
    "samba"                "Netzwerkfreigaben "                                on  \
    "p7zip-full"           "Paketverwaltung"                                   on  \
    "oxygen-icon-theme"    "Symbolthema"                                       on  \
    "breeze-gtk-theme"     "Fensterthema"                                      on  \
    "console-data"         "Sprachpakete für Konsole"                          on  \
    "keepassxc"            "Passwortmanager"                                   on  \
    "qemu-user-static"     "Chroot auf in anderen Architekturen ermöglichen"   off \
    "git"                  "Github verwaltung"                                 off \
    "openssh-server"       "Fernverwaltungsserver "                            off \
    "imagemagick"          "Bildbearbeitungs-Konsolen-Tools"                   off \
    "xrdp"                 "Remotedesktop-Server"                              off \
    "rdesktop"             "Remotedesktop-Client"                              off \
    3>&1 1>&2 2>&3 | xargs
  )
  if [ ! -z "$aptls" ];then
    $SU apt update
    $SU apt full-upgrade -y $aptls
  fi
  mainmenu
}

cconfig () {
  cconf=$( whiptail --checklist "Computerkonfiguration " 0 0 0 --ok-button Ok --cancel-button Abbruch \
    "upgrade"              "Aktualisierungsskript hinzufügen"                  on  \
    "autoupdate"           "Automatische updates per Skript aktivieren"        on  \
    "noapport"             "Apport deaktivieren"                               on  \
    "supower"              "Sudoerseintrag für Gruppe Users anlegen"           on  \
    "console2german"       "Deutsche Sprache auf Konsole einstellen"           on  \
    3>&1 1>&2 2>&3 | xargs
  )
  mainmenu
}

uconfig () {
  uconf=$( whiptail --checklist "Benutzerkonfiguration " 0 0 0 --ok-button Ok --cancel-button Abbruch \
    "add2users"            "Benutzer zu users hinzufügen"                 on  \
    "add2samba"            "Benutzer zu Gruppe Sambashare hinzufügen"     on  \
    "oxygen"               "Oxygen als Symbolthema einstellen"            on  \
    "breeze"               "Breeze-Dark als Fensterthema einstellen"      on  \
    "autologin"            "Benutzer automatisch in GUI einloggen"        off \
    "ttyautologin"         "Benutzer automatisch in Konsole einloggen"    off \
    3>&1 1>&2 2>&3 | xargs
  )
  mainmenu
}

chrootfs () {
  local IFS=$'\n'
  local DEV=$(lsblk -lno fstype,name,size,mountpoint |grep ^ext.|awk '$4 ~ "/(media|mnt)|^$" {printf "/dev/%-20s\n%8s\n",$2,$3}')
  local SEL=$( whiptail --menu "Gerät für Chroot auswählen: " 0 0 0 --ok-button Ok --cancel-button Abbruch ${DEV[@]} 3>&1 1>&2 2>&3 )
  echo $SEL
}

mainmenu
