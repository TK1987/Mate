#!/bin/bash

INSTALLS='gimp k3b okular samba caja-share nmap cifs-utils'
APPDIR='/usr/share/applications'
AUTOSTART="plank tilda"
GITREPO='github.com/tk1987/bash/raw/master'
BACKGROUNDS='/usr/share/backgrounds'
BACKGROUNDIMAGE='smoking_mate.jpg'
UPGRADEPATH='/usr/local/sbin'
PLANKTHEMES='/usr/share/plank/themes'
DESKTOPTHEMES='/usr/share/themes'
GLIB='/usr/share/glib-2.0/schemas'
OVERRIDES="20_mate-ubuntu.gschema.override 30_ubuntu-mate.gschema.override 40_ubuntu-mate-live.gschema.override"


# Richte upgrade-script ein
	wget -P $UPGRADEPATH $GITREPO/upgrade.sh
	chmod $UPGRADEPATH/upgrade.sh
	ln -s $UPGRADEPATH/upgrade.sh /etc/cron.daily
	systemctl disable unattend-upgrades.service

# Installiere Programme und Update das System
	apt-get install -y $INSTALLS
	upgrade.sh

# Schreibe Aliase und Funktionen
	cat <<-EoF >> /etc/skel/.bash_aliases
	alias cls='echo -en "\0033\0143"'
	alias upgrade='sudo upgrade.sh'
	EoF
	sed -i "s/^#EXTRA_GROUPS=.*/EXTRA_GROUPS='sambashare lpadmin users cdrom audio video plugdev'/; s/^#ADD_EXTRA_GROUPS.*/ADD_EXTRA_GROUPS=1/" /etc/adduser.conf
	cat <<-EoF >> /etc/sudoers
	%users ALL=(ALL) NOPASSWD: $UPGRADEPATH/upgrade.sh
	EoF

# Hintergund einrichten
	wget -P $BACKGROUNDS $GITREPO/backgrounds/$BACKGROUNDIMAGE
	for FILE in $OVERRIDES;do sed -i "s#^picture-filename=.*#picture-filename=$BACKGROUNDS/$BACKGROUNDIMAGE# ; s#^background=.*#background=$BACKGROUNDS/$BACKGROUNDIMAGE#" $GLIB/$FILE;done
	
# Erstelle Plank-Theme
	mkdir -p $PLANKTHEMES/TK87
	cat <<-EoF > $PLANKTHEMES/TK87/dock.theme
		[PlankTheme]
		#The roundness of the top corners.
		TopRoundness=50
		#The roundness of the bottom corners.
		BottomRoundness=50
		#The thickness (in pixels) of lines drawn.
		LineWidth=-5
		#The color (RGBA) of the outer stroke.
		OuterStrokeColor=0;;0;;0;;255
		#The starting color (RGBA) of the fill gradient.
		FillStartColor=10;;10;;10;;225
		#The ending color (RGBA) of the fill gradient.
		FillEndColor=50;;50;;50;;225
		#The color (RGBA) of the inner stroke.
		InnerStrokeColor=0;;0;;0;;255

		[PlankDockTheme]
		#The padding on the left/right dock edges, in tenths of a percent of IconSize.
		HorizPadding=4
		#The padding on the top dock edge, in tenths of a percent of IconSize.
		TopPadding=-5
		#The padding on the bottom dock edge, in tenths of a percent of IconSize.
		BottomPadding=2
		#The padding between items on the dock, in tenths of a percent of IconSize.
		ItemPadding=3
		#The size of item indicators, in tenths of a percent of IconSize.
		IndicatorSize=10
		#The size of the icon-shadow behind every item, in tenths of a percent of IconSize.
		IconShadowSize=1
		#The height (in percent of IconSize) to bounce an icon when the application sets urgent.
		UrgentBounceHeight=1.6666666666666667
		#The height (in percent of IconSize) to bounce an icon when launching an application.
		LaunchBounceHeight=0.625
		#The opacity value (0 to 1) to fade the dock to when hiding it.
		FadeOpacity=1
		#The amount of time (in ms) for click animations.
		ClickTime=300
		#The amount of time (in ms) to bounce an urgent icon.
		UrgentBounceTime=600
		#The amount of time (in ms) to bounce an icon when launching an application.
		LaunchBounceTime=600
		#The amount of time (in ms) for active window indicator animations.
		ActiveTime=300
		#The amount of time (in ms) to slide icons into/out of the dock.
		SlideTime=300
		#The time (in ms) to fade the dock in/out on a hide (if FadeOpacity is < 1).
		FadeTime=250
		#The time (in ms) to slide the dock in/out on a hide (if FadeOpacity is 1).
		HideTime=250
		#The size of the urgent glow (shown when dock is hidden), in tenths of a percent of IconSize.
		GlowSize=30
		#The total time (in ms) to show the hidden-dock urgent glow.
		GlowTime=10000
		#The time (in ms) of each pulse of the hidden-dock urgent glow.
		GlowPulseTime=2000
		#The hue-shift (-180 to 180) of the urgent indicator color.
		UrgentHueShift=150
		#The time (in ms) to move an item to its new position or its addition/removal to/from the dock.
		ItemMoveTime=450
		#Whether background and icons will unhide/hide with different speeds. The top-border of both will leave/hit the screen-edge at the same time.
		CascadeHide=true
		EoF

# Erstelle Desktop-Theme
	mkdir -p $DESKTOPTHEMES/TK87
	cat <<-EoF > $DESKTOPTHEMES/TK87/index.theme
		[Desktop Entry]
		Name=TK87
		Type=X-GNOME-Metatheme
		Comment=
	
		[X-GNOME-Metatheme]
		GtkTheme=BlackMATE
		MetacityTheme=Ambiant-MATE-Dark
		IconTheme=ubuntu-mono-dark
		CursorTheme=mate
		CursorSize=24
		EoF

# Setze Autostart-Programme
	for APP in $AUTOSTART;do cp $APPDIR/$APP.desktop /etc/xdg/autostart/;done

