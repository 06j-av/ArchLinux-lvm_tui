#!/bin/bash
clear

# Check if the user is running the script on a 64-bit UEFI system
whiptail --title "Just a couple things first..." --infobox "Checking hardware compatiblity..." 8 35
sleep 1 
if [[ "$(uname -m)" != "x86_64" && ! -e /sys/firmware/efi/fw_platform_size ]]; then
    whiptail --title "Error" --msgbox "Your system isn't using a 64-bit architecture AND not using UEFI firmware!" 0 5
    exit 2
elif [[ "$(uname -m)" != "x86_64" && -e /sys/firmware/efi/fw_platform_size ]]; then
    whiptail --title "Error" --msgbox "Your system isn't using a 64-bit architecture!" 0 5
    exit 2
elif [[ "$(uname -m)" = "x86_64" && ! -e /sys/firmware/efi/fw_platform_size ]]; then
    whiptail --title "Error" --msgbox "Your system isn't using UEFI firmware!" 0 5
    exit 2
fi

# Check for an internet connection
whiptail --title "Just a couple things first..." --infobox "Checking your internet connection..." 8 35 
sleep 1
internet=$(ping -c 3 archlinux.org >/dev/null 2>&1; echo $?)
if [ $internet -ne 0 ]; then
    whiptail --title "Error" --msgbox "There's something wrong with your internet connection. Try again later." 2 15
fi

welcomeText="Welcome to 06j-av's automated Arch Linux install script.

Ensure that you have made both your EFI partition and a 'Linux LVM' type 
partition.

This script is for 64-bit UEFI systems ONLY. LVM setup is included."
whiptail --title "Welcome to Arch Linux!" --msgbox "$welcomeText" 0 5

partconfig() {
	# Get a list of partitions using the 'lsblk' command
	partitions=$(lsblk -no NAME,FSTYPE,SIZE,PARTTYPENAME)
	efipart=$(whiptail --title "Select partitions..." --nocancel --inputbox "Which of these will be your EFI system partition?\nEnter the path to that partition below.\n\n$partitions" 0 0 3>&1 1>&2 2>&3)
	eraseefi=$(whiptail --title "Format?" --yesno "Do you want to format $efipart?\n\nIf you are dual booting, we highly suggest NOT formatting the partition." --defaultno --yes-button "Format" --no-button "Don't format" 0 0 3>&1 1>&2 2>&3; echo $?)
	rootpart=$(whiptail --title "Select partitions..." --nocancel --inputbox "You have selected $efipart as your EFI system partition.\n\nWhich of these will be your root partition?\nEnter the path to that partition below.\n\n$partitions" 0 0 3>&1 1>&2 2>&3)
	vgname=$(whiptail --title "Host configuration" --nocancel --inputbox "Name the volume group:" 0 0 3>&1 1>&2 2>&3)
	lvname=$(whiptail --title "Host configuration" --nocancel --inputbox "Name the root logical volume:" 0 0 3>&1 1>&2 2>&3)
	if [[ $eraseefi -eq 0 ]]; then
		partmenu="EFI: $efipart (Format); Root: $rootpart"
	else
		partmenu="EFI: $efipart (Don't format); Root: $rootpart"
	fi
	setpart=true
	main
}

kernelconfig() {
	linuxkernel=$(whiptail --title "Select a kernel" --nocancel --menu "Choose the kernel that you want to install." 20 70 4 3>&1 1>&2 2>&3 \
 	"linux" "The vanilla Linux kernel and modules" \
   	"linux-lts" "Long-term (LTS) Linux kernel")
    kernelmenu="Selected kernel: $linuxkernel"
    setkernel=true
    main
}

userconfig() {
	username=$(whiptail --title "Username & password" --nocancel --inputbox "Enter a username:" 0 0 3>&1 1>&2 2>&3)
	userpasswd=$(whiptail --passwordbox "Enter the password for $username:" 8 78 --title "Username & password" 3>&1 1>&2 2>&3)
	usermenu="Username: $username"
	setuser=true
	main
}

rootconfig() {
	rootpasswd=$(whiptail --title "Root password" --nocancel --passwordbox "Enter the password for root:" 8 78 3>&1 1>&2 2>&3)
	rootpassmenu="Root password set."
	setrootpasswd=true
	main
}

hostconfig() {
	nameofhost=$(whiptail --title "Host configuration" --nocancel --inputbox "What's going to be this system's hostname?" 0 0 3>&1 1>&2 2>&3)
	# Get the list of timezones
	timezones=$(timedatectl list-timezones)

	# Create an array from the list of timezones
	timezones_array=()
	while IFS= read -r line; do
    	timezones_array+=("$line" "")
	done <<< "$timezones"
	# Show the Whiptail menu and store the selected timezone
	timezone=$(whiptail --title "Host configuration" --menu --nocancel "What's your time zone?\n\nYou can use PgUp or PgDn to quickly scroll." 20 60 10 "${timezones_array[@]}" 3>&1 1>&2 2>&3)

	# Get the list of locales
	locales=$(cat /usr/share/i18n/SUPPORTED)

	# Create an array from the list of locales
	locales_array=()
	while IFS= read -r line; do
	    locales_array+=("$line" "")
	done <<< "$locales"
	# Show the Whiptail menu and store the selected timezone
	locale=$(whiptail --title "Host configuration" --menu --nocancel "What's your locale?\n\nYou can use PgUp or PgDn to quickly scroll." 20 60 10 "${locales_array[@]}" 3>&1 1>&2 2>&3)
	hostmenu="Hostname: $nameofhost; Time zone: $timezone; Locale: $locale"
	sethoststuf=true
	main
}

hwconfig() {
	# It's best to set the kernel first, so determine if the user did set the kernel
	if [[ $setkernel = false ]]; then
		whiptail --title "Come back to this later" --msgbox "You should probably set your specified kernel first, so come back when you've done that." 0 0
		main
	fi

	# Ask the user for their CPU type to determine the microcode package
	cpumake=$(whiptail --title "Hardware" --menu --nocancel "Select your CPU make:" 0 0 2 \
		"amd" "You have an AMD CPU." \
		"intel" "You have an Intel CPU." 3>&1 1>&2 2>&3)
	# Ask the user for their GPU type to determine the GPU driver package
	gputype=$(whiptail --title "Hardware" --yesno "Are you using an NVIDIA graphics card?" --yes-button "Yes" --no-button "No" 0 0 3>&1 1>&2 2>&3; echo $?)

	# Install the mesa open-source GPU driver if the user isn't using an NVIDIA GPU
	if [[ $gputype -eq 1 ]]; then
		gpupkg="mesa"
	fi

	# Determine/Ask the user for the recommended GPU driver package for their NVIDIA GPU
	if [[ "$linuxkernel" = "linux" && $gputype -eq 0 ]]; then
		nvidiatype=$(whiptail --title "Hardware" --yesno "We see that you've selected the 'linux' kernel.\n\nWe recommend installing the 'nvidia' GPU package." --defaultno --yes-button "Install 'nvidia'" --no-button "Install other..." 0 0 3>&1 1>&2 2>&3; echo $?)
		if [[ $nvidiatype -eq 0 ]]; then
			gpupkg="nvidia"
		fi
	elif [[ "$linuxkernel" = "linux-lts" && $gputype -eq 0 ]]; then
		nvidiatype=$(whiptail --title "Hardware" --yesno "We see that you've selected the 'linux-lts' kernel.\n\nWe recommend installing the 'nvidia-lts' GPU package." --defaultno --yes-button "Install 'nvidia-lts'" --no-button "Install other..." 0 0 3>&1 1>&2 2>&3; echo $?)
		if [[ $nvidiatype -eq 0 ]]; then
			gpupkg="nvidia-lts"
		fi
	fi
	if [[ $gputype -eq 0 && $nvidiatype -eq 1 ]]; then
		gpupkg=$(whiptail --title "Hardware" --menu --nocancel "Which package is appropriate for your GPU?" 0 0 3 \
		"nvidia" "NVIDIA for the 'linux' kernel" \
		"nvidia-lts" "NVIDIA for the 'linux-lts' kernel"\
		"nvidia-open" "Open source NVIDIA drivers" \
		"mesa" "Using the mesa drivers for other GPUs" 3>&1 1>&2 2>&3)
	fi
	hardwaremenu="CPU: $cpumake; GPU: $gpupkg"
	sethardware=true
	main
}

swapconfig() {
	swapspace=$(whiptail --title "Swap space" --menu --nocancel "How much swap space do you want?\n\nThis will be a file, not a partition." 15 50 4 3>&1 1>&2 2>&3 \
	"N/A" "No swap file" \
	"2G" "2G swap file" \
	"4G" "4G swap file" \
	"8G" "8G swap file")
	if [[ "$swapspace" = "N/A" ]]; then
		swapmenu="No swap space"
	else
		swapmenu="Swap space: $swapspace sized file"
	fi
	setswap=true
	main
}

desktopconfig() {
	desktop=$(whiptail --title "Desktop environment" --menu --nocancel "What desktop environment do you want?" 25 78 12 \
	"budgie" "Install the Budgie desktop environment" \
	"cinnamon" "Install the Cinnamon desktop environment" \
	"gnome" "Install the GNOME desktop environment" \
	"lxde" "Install the LXDE (with GTK 2) desktop environment" \
	"lxde-gtk3" "Install the LXDE (with GTK 3) desktop environment" \
	"lxqt" "Install the LXQt desktop environment" \
	"mate" "Install the MATE desktop environment" \
	"plasma" "Install the KDE Plasma desktop environment" \
	"xfce4" "Install the Xfce desktop environment" \
	"i3" "Install the i3 window manager" \
	"sway" "Install the Sway window manager" \
	"No DE" "Install nothing, minimal installation" 3>&1 1>&2 2>&3)
	if [[ "$desktop" != "No DE" ]]
	then
		displaymgr=$(whiptail --title "Display manager" --menu --nocancel "What display manager do you want?" 25 78 7 \
		"sddm" "Recommended for KDE & LXQt" \
		"ly" "Terminal display manager" \
		"gdm" "Recommended for GNOME" \
		"lightdm" "Cross-desktop display manager" \
		"lxdm" "LXDE display manager with GTK 2" \
		"lxdm-gtk3" "LXDE display manager with GTK 3" \
		"No DM" "Don't install a display manager" 3>&1 1>&2 2>&3)
		demenu="$desktop + $displaymgr"
	else
		demenu="$desktop"
	fi
	setdesktop=true
	main
}

installArch() {
	whiptail --title "Installing Arch Linux..." --infobox "Here we go!" 8 35
	sleep 3
	if [[ $eraseefi -eq 0 ]]; then
		whiptail --title "Partitioning & LVM setup" --infobox "Formatting the EFI System partition..." 8 35
		mkfs.fat -F 32 $efipart > /dev/null
	else
		whiptail --title "Partitioning & LVM setup" --infobox "The ESP has been untouched." 8 35
		sleep 2
	fi
	whiptail --title "Partitioning & LVM setup" --infobox "Creating physical volume $rootpart..." 8 35
	pvcreate $rootpart > /dev/null
	sleep 1
 
	whiptail --title "Partitioning & LVM setup" --infobox "Creating volume group $vgname..." 8 35
	vgcreate $vgname $rootpart > /dev/null
	sleep 1
 
	whiptail --title "Partitioning & LVM setup" --infobox "Creating logical volume $lvname" 8 35
	lvcreate -l 100%FREE $vgname -n $lvname > /dev/null
	sleep 1
 
	whiptail --title "Partitioning & LVM setup" --infobox "Finishing LVM setup..." 8 35
	modprobe dm_mod
	sleep 1
	vgchange -ay > /dev/null
	sleep 1
	lvmpath=/dev/$vgname/$lvname
 
	whiptail --title "Partitioning & LVM setup" --infobox "Formatting $lvmpath..." 8 35
	mkfs.ext4 $lvmpath > /dev/null
	sleep 1
 
	whiptail --title "Partitioning & LVM setup" --infobox "Mounting the file systems..." 8 35
	mount $lvmpath /mnt
	mount --mkdir $efipart /mnt/boot/efi
	sleep 1
 
	whiptail --title "Getting things ready..." --infobox "Building fstab file..." 8 35
	mkdir /mnt/etc
	genfstab -U /mnt >> /mnt/etc/fstab
	sleep 1
 
	whiptail --title "Getting things ready..." --infobox "Installing the base package..." 8 35
	pacstrap /mnt base libnewt --noconfirm --needed > /dev/null
	sleep 1
 
	whiptail --title "Getting things ready..." --infobox "Doing some other stuff..." 8 35
	mkdir /mnt/install
	echo $locale > /mnt/install/lang
	language=$(cat /mnt/install/lang | awk '{print $1}')
	sleep 1

	cat <<INSTALL > /mnt/install/install.sh
	whiptail --title "Installing Arch Linux..." --infobox "Installing the Linux kernel and other tools..." 8 35
	pacman -S $linuxkernel $linuxkernel-headers linux-firmware base-devel lvm2 git neofetch zip $cpumake-ucode neovim networkmanager wpa_supplicant wireless_tools netctl dialog bluez bluez-utils --noconfirm --needed > /dev/null

	whiptail --title "Installing Arch Linux..." --infobox "Enabling Network Manager..." 8 35
	systemctl enable NetworkManager > /dev/null
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Configuring the Linux initcpio..." 8 35
	cp -f /install/mkinit.conf /etc/mkinitcpio.conf > /dev/null
	mkinitcpio -P > /dev/null
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Setting the locale..." 8 35
	sed -i 's/#$locale/$locale/' /etc/locale.gen
	locale-gen > /dev/null
	echo 'LANG=$language' > /etc/locale.conf
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Configuring users..." 8 35
	useradd -m -g users -G wheel $username
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Setting passwords..." 8 35
	echo '$userpasswd' | passwd --stdin $username
	echo '$rootpasswd' | passwd --stdin root
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Configuring sudoers..." 8 35
	sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Installing and configuring GRUB..." 8 35
	pacman -S grub dosfstools os-prober mtools efibootmgr --noconfirm --needed > /dev/null
	grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck > /dev/null
	if [ -d /boot/grub/locale ]; then
		cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
		sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER="false"/' /etc/default/grub
		grub-mkconfig -o /boot/grub/grub.cfg
	else
		mkdir /boot/grub/locale
		cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
		sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER="false"/' /etc/default/grub
		grub-mkconfig -o /boot/grub/grub.cfg
	fi
	sleep 1

	if [[ "$swapspace" != "N/A" ]]
		whiptail --title "Installing Arch Linux..." --infobox "Configuring swap space..." 8 35
		mkswap -U clear --size $swapspace --file /swapfile
		swapon /swapfile
		echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
		mount -a
		swapon -a
	fi
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Setting the hostname..." 8 35
	echo "$nameofhost" > /etc/hostname
	echo -e "127.0.0.1	localhost\n127.0.1.1	$nameofhost" > /etc/hosts
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Setting the timezone..." 8 35
	ln -sf /usr/share/zoneinfo/$timezone /etc/localtime > /dev/null
	hwclock --systohc > /dev/null
	systemctl enable systemd-timesyncd > /dev/null
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Enabling the multilib repository..." 8 35
	echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
	pacman -Sy > /dev/null
	sleep 1

	if [[ $gputype -eq 0 ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Installing NVIDIA drivers..." 8 35
		pacman -S $gpupkg nvidia-utils --noconfirm --needed > /dev/null
		mkdir /etc/pacman.d/hooks
		cp /install/$gpupkg.hook /etc/pacman.d/hooks/
		sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"/' /etc/default/grub
		cp
		mkinitcpio -P > /dev/null
		grub-mkconfig -o /boot/grub/grub.cfg > /dev/null
	else
		whiptail --title "Installing Arch Linux..." --infobox "Installing the 'mesa' GPU driver..." 8 35
		pacman -S mesa --noconfirm --needed > /dev/null
	fi

	whiptail --title "Installing Arch Linux..." --infobox "Installing PipeWire..." 8 35
	pacman -S pipewire lib32-pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack lib32-pipewire-jack --noconfirm --needed > /dev/null

	if [[ "$desktop" != "No DE" && "$displaymgr" != "No DM" ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Installing PipeWire..." 8 35
		pacman -S xorg $desktop $displaymgr alacritty --noconfirm --needed > /dev/null
		systemctl enable $displaymgr
	elif [[ "$desktop" != "No DE" && "$displaymgr" = "No DM" ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Installing PipeWire..." 8 35
		pacman -S xorg $desktop alacritty --noconfirm --needed > /dev/null
	fi

	whiptail --title "Installing Arch Linux..." --infobox "Blacklisting the PC speaker..." 8 35
	echo -e "blacklist pcspkr\nblacklist snd_pcsp" > /etc/modprobe.d/nobeep.conf
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Clearing the pacman cache..." 8 35
	pacman -Scc --noconfirm > /dev/null
	rm -f /var/cache/pacman/pkg/*
	exit
INSTALL

	cat <<MKINIT > /mnt/install/mkinit.conf
# vim:set ft=sh
# MODULES
# The following modules are loaded before any boot hooks are
# run.  Advanced users may wish to specify all system modules
# in this array.  For instance:
#     MODULES=(usbhid xhci_hcd)
MODULES=()

# BINARIES
# This setting includes any additional binaries a given user may
# wish into the CPIO image.  This is run last, so it may be used to
# override the actual binaries included by a given hook
# BINARIES are dependency parsed, so you may safely ignore libraries
BINARIES=()

# FILES
# This setting is similar to BINARIES above, however, files are added
# as-is and are not parsed in any way.  This is useful for config files.
FILES=()

# HOOKS
# This is the most important setting in this file.  The HOOKS control the
# modules and scripts added to the image, and what happens at boot time.
# Order is important, and it is recommended that you do not change the
# order in which HOOKS are added.  Run 'mkinitcpio -H <hook name>' for
# help on a given hook.
# 'base' is _required_ unless you know precisely what you are doing.
# 'udev' is _required_ in order to automatically load modules
# 'filesystems' is _required_ unless you specify your fs modules in MODULES
# Examples:
##   This setup specifies all modules in the MODULES setting above.
##   No RAID, lvm2, or encrypted root is needed.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup will autodetect all modules for your system and should
##   work as a sane default
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup will generate a 'full' image which supports most systems.
##   No autodetection is done.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup assembles a mdadm array with an encrypted root file system.
##   Note: See 'mkinitcpio -H mdadm_udev' for more information on RAID devices.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup loads an lvm2 volume group.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This will create a systemd based initramfs which loads an encrypted root filesystem.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   NOTE: If you have /usr on a separate partition, you MUST include the
#    usr and fsck hooks.
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block lvm2 filesystems fsck)

# COMPRESSION
# Use this to compress the initramfs image. By default, zstd compression
# is used. Use 'cat' to create an uncompressed image.
#COMPRESSION="zstd"
#COMPRESSION="gzip"
#COMPRESSION="bzip2"
#COMPRESSION="lzma"
#COMPRESSION="xz"
#COMPRESSION="lzop"
#COMPRESSION="lz4"

# COMPRESSION_OPTIONS
# Additional options for the compressor
#COMPRESSION_OPTIONS=()

# MODULES_DECOMPRESS
# Decompress kernel modules during initramfs creation.
# Enable to speedup boot process, disable to save RAM
# during early userspace. Switch (yes/no).
#MODULES_DECOMPRESS="yes"
MKINIT

	cat <<MKINITNVIDIA > /mnt/install/mkinitnvidia.conf
# vim:set ft=sh
# MODULES
# The following modules are loaded before any boot hooks are
# run.  Advanced users may wish to specify all system modules
# in this array.  For instance:
#     MODULES=(usbhid xhci_hcd)
MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)

# BINARIES
# This setting includes any additional binaries a given user may
# wish into the CPIO image.  This is run last, so it may be used to
# override the actual binaries included by a given hook
# BINARIES are dependency parsed, so you may safely ignore libraries
BINARIES=()

# FILES
# This setting is similar to BINARIES above, however, files are added
# as-is and are not parsed in any way.  This is useful for config files.
FILES=()

# HOOKS
# This is the most important setting in this file.  The HOOKS control the
# modules and scripts added to the image, and what happens at boot time.
# Order is important, and it is recommended that you do not change the
# order in which HOOKS are added.  Run 'mkinitcpio -H <hook name>' for
# help on a given hook.
# 'base' is _required_ unless you know precisely what you are doing.
# 'udev' is _required_ in order to automatically load modules
# 'filesystems' is _required_ unless you specify your fs modules in MODULES
# Examples:
##   This setup specifies all modules in the MODULES setting above.
##   No RAID, lvm2, or encrypted root is needed.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup will autodetect all modules for your system and should
##   work as a sane default
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup will generate a 'full' image which supports most systems.
##   No autodetection is done.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup assembles a mdadm array with an encrypted root file system.
##   Note: See 'mkinitcpio -H mdadm_udev' for more information on RAID devices.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This setup loads an lvm2 volume group.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   This will create a systemd based initramfs which loads an encrypted root filesystem.
#    HOOKS=(base udev autodetect keyboard keymap consolefont modconf block encrypt lvm2 filesystems fsck)
#
##   NOTE: If you have /usr on a separate partition, you MUST include the
#    usr and fsck hooks.
HOOKS=(base udev autodetect keyboard keymap consolefont modconf block lvm2 filesystems fsck)

# COMPRESSION
# Use this to compress the initramfs image. By default, zstd compression
# is used. Use 'cat' to create an uncompressed image.
#COMPRESSION="zstd"
#COMPRESSION="gzip"
#COMPRESSION="bzip2"
#COMPRESSION="lzma"
#COMPRESSION="xz"
#COMPRESSION="lzop"
#COMPRESSION="lz4"

# COMPRESSION_OPTIONS
# Additional options for the compressor
#COMPRESSION_OPTIONS=()

# MODULES_DECOMPRESS
# Decompress kernel modules during initramfs creation.
# Enable to speedup boot process, disable to save RAM
# during early userspace. Switch (yes/no).
#MODULES_DECOMPRESS="yes"
MKINITNVIDIA

	cat <<NVIDIAHOOK > /mnt/install/nvidia.hook
	[Trigger]
	Operation=Install
	Operation=Upgrade
	Operation=Remove
	Type=Package
	Target=nvidia
	Target=linux

	[Action]
	Description=Update NVIDIA module in initcpio
	Depends=mkinitcpio
	When=PostTransaction
	NeedsTargets
	Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
NVIDIAHOOK

	cat <<NVIDIALTSHOOK > /mnt/install/nvidia-lts.hook
	[Trigger]
	Operation=Install
	Operation=Upgrade
	Operation=Remove
	Type=Package
	Target=nvidia-lts
	Target=linux-lts

	[Action]
	Description=Update NVIDIA module in initcpio
	Depends=mkinitcpio
	When=PostTransaction
	NeedsTargets
	Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
NVIDIALTSHOOK

	cat <<NVIDIAOPENHOOK > /mnt/install/nvidia-open.hook
	[Trigger]
	Operation=Install
	Operation=Upgrade
	Operation=Remove
	Type=Package
	Target=nvidia-open
	Target=linux

	[Action]
	Description=Update NVIDIA module in initcpio
	Depends=mkinitcpio
	When=PostTransaction
	NeedsTargets
	Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
NVIDIAOPENHOOK

	#arch-chroot /mnt /bin/bash install/install.sh

}

check() {
	if [[ "$setpart" = true && "$setkernel" = true && "$setuser" = true && "$setrootpasswd" = true && "$sethoststuf" = true && "$sethardware" = true && "$setdesktop" = true && "$setswap" = true ]]; then
		confirm=$(whiptail --title "Are you ready?" --nocancel --yesno "Are you ready to install Arch Linux?\n\nThere is no going back if you choose 'I'm ready.'" --defaultno --yes-button "I'm ready" --no-button "WAIT..." 0 0 3>&1 1>&2 2>&3; echo $?)
		if [[ $confirm -eq 0 ]]; then
			confirm=$(whiptail --title "Are you ready?" --nocancel --yesno "ARE YOU SURE?\n\nThere really is no going back." --defaultno --yes-button "I'm sure" --no-button "Never mind" 0 0 3>&1 1>&2 2>&3; echo $?)
			if [[ $confirm -eq 1 ]]; then
				exit 0
			else
				installArch
			fi
		else
			whiptail --title "Going back" --msgbox "Never mind then." 0 5
			main
		fi
	else
		whiptail --title "Something went wrong" --msgbox "You're missing some stuff. Check back at your configurations and come back here." 0 5
		main
	fi
}

# Set the menu choices and boolean things to the default
partmenu="Select partitions... (not set)"
setpart=false
kernelmenu="Select a kernel..."
setkernel=false
usermenu="Create a user and a password..."
setuser=false
rootpassmenu="Set a root password..."
setrootpasswd=false
hostmenu="Configure the host..."
sethoststuf=false
hardwaremenu="Tell us your hardware..."
sethardware=false
demenu="Select a desktop environment..."
setdesktop=false
swapmenu="Set swap space..."
setswap=false

main() {
	choice=$(whiptail --title "Welcome to Arch Linux!" --nocancel --menu "Choose some options:" 20 80 10 \
		"1" "$partmenu" \
		"2" "$kernelmenu" \
		"3" "$usermenu" \
		"4" "$rootpassmenu" \
		"5" "$hostmenu" \
		"6" "$hardwaremenu" \
		"7" "$swapmenu" \
		"8" "$demenu" \
		"9" "Install Arch Linux" \
		"10" "Exit" 3>&1 1>&2 2>&3)
	case $choice in
    1)
        partconfig
        ;;
	2)
		kernelconfig
		;;
    3)
        userconfig
        ;;
    4)
        rootconfig
        ;;
    5)
        hostconfig
        ;;
    6)
        hwconfig
        ;;
	7)
        swapconfig
        ;;    
    8)
        desktopconfig
        ;;
    9)
        ;;
    *)
        exit 0
        ;;
esac
}

main
check
rebootconfirm=$(whiptail --title "Chroot or reboot?" --yesno "Installation is COMPLETE.\n\nWould you like to chroot into your installation to do\nsome extra configurations\n\norreboot to your new installation?" --defaultno --yes-button "Chroot" --no-button "Reboot" 0 0 3>&1 1>&2 2>&3; echo $?)
if [[ $rebootconfirm -eq 0 ]]; then
	echo "Chrooting..."
	#arch-chroot /mnt
else
	{
    for ((i = 0 ; i <= 100 ; i+=5)); do
        sleep 0.05
        echo $i
    done
	} | whiptail --gauge "Rebooting in a couple moments..." 6 50 0
	#umount -R /mnt
	#reboot
fi
clear
