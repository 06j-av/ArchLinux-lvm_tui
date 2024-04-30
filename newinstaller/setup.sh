#!/bin/bash

start() {
    whiptail --title "Welcome to Arch Linux!" --msgbox "Hello!\n\nWelcome to the Arch Linux install script.\n\nMake sure your EFI and root partition is ready.\n\nWe'll need to check some things first." --ok-button "Begin" 0 5

    whiptail --title "Just a couple things first..." --infobox "Setting the directory..." 8 35
    script_dir="$(dirname "$0")"
    cd "$script_dir"
    dir=$(pwd)
    sleep 1
    whiptail --title "Just a couple things first..." --infobox "Checking your internet connection..." 8 35
    ping -c 5 archlinux.org &> /dev/null 2>&1

    if [[ $? -ne 0 ]]; then
        whiptail --title "Connection error" --msgbox "There's something wrong with your internet connection. Here's some things that might help:\n\nIf you're using a wired connection, is the cable plugged in correctly?\nIf you're using a wireless connection, did you correctly set it up with the 'iwctl' command?\n\nOnce you have a working internet connection, rerun the installer!" 2 15
        exit 1
    fi
    UEFI=false
    whiptail --title "Just a couple things first..." --infobox "Checking your firmware..." 8 35
    if [ -d /sys/firmware/efi ]; then
        UEFI=true
    fi
    if ! $UEFI; then
        whiptail --title "Unsupported firmware" --msgbox "This installation script only supports UEFI firmware.\n\nCould it be that you booted in BIOS mode?\nIf not, you cannot run the installer with the current firmware." 2 15
        exit 1
    fi

    whiptail --title "Just a couple things first..." --infobox "Checking system architecture..." 8 35
    if [[ "$(uname -m)" != "x86_64" ]]; then
        whiptail --title "Unsupported architecture" --msgbox "This installation script only supports the x86_64 architecture.\n\nYou cannot run the installer with the current system architecture." 2 15
        exit 1
    fi
    whiptail --title "Supported system" --msgbox "You're system's all good! Let's proceed." 0 5
}

# Variables: $efipart (str, /dev/ path), $formatefi (boolean t/f), $rootpart (str, /dev/ path)
partconfig() {
    partitions=$(lsblk -npo NAME,FSTYPE,SIZE,PARTTYPENAME)
	efipart=$(whiptail --title "Select partitions..." --nocancel --inputbox "Enter the path to the EFI partition.\n\nThis is usually the first partition on your disk.\n\n$partitions" 0 0 3>&1 1>&2 2>&3)

	# Check if the ESP is a device file and a "EFI System" partition
	if [[ -b "$efipart" && "$(lsblk -no TYPE "$efipart")"  == "part" && "$(lsblk -no PARTTYPENAME "$efipart" = "EFI System" )" ]]; then
		echo "$efipart is a valid ESP."
	else
		whiptail --title "Something went wrong" --msgbox "$efipart is not a valid EFI System Partition." 2 15
		exit 1
	fi

	formatefi=false
	whiptail --title "Format?" --yesno "Do you want to format $efipart?\n\nIf you are dual booting, we highly suggest NOT formatting the partition." --defaultno --yes-button "Format" --no-button "Don't format" 0 0 3>&1 1>&2 2>&3
	if [[ $? -eq 0 ]]; then
        formatefi=true
    fi
    rootpart=$(whiptail --title "Select partitions..." --nocancel --inputbox "You have selected $efipart as your EFI system partition.\n\Enter the path to your root partition.\n\n$partitions" 0 0 3>&1 1>&2 2>&3)

    if [[ -b "$rootpart" && "$(lsblk -no TYPE "$rootpart")"  == "part" && "$(lsblk -no PARTTYPENAME "$rootpart" = "Linux LVM" )" ]]; then
		echo "$rootpart is a valid root partition."
	else
		whiptail --title "Something went wrong" --msgbox "$rootpart is not a valid root partition." 2 15
		exit 1
	fi

	if [[ "$efipart" = "$rootpart" ]]; then
		whiptail --title "Something went wrong" --msgbox "The ESP and root partition cannot be the same!" 2 15
		exit 1
	fi

    disklayout="basic"
    whiptail --title "Disk layout" --yesno "What disk layout do you want to use for the root partition?\n\nBasic: Just a root partition, nothing else\n\LVM: Use Logical Volume Management" --defaultno --yes-button "Basic" --no-button "LVM" 0 0 3>&1 1>&2 2>&3
    if [[ $? -eq 1 ]]; then
        disklayout="lvm"
        vgname=$(whiptail --title "LVM setup" --nocancel --inputbox "Name the volume group:" 0 0 3>&1 1>&2 2>&3)
        lvname=$(whiptail --title "LVM setup" --nocancel --inputbox "Name the root logical volume:" 0 0 3>&1 1>&2 2>&3)
    fi
    setpart=true
    main_menu
}

# Variable: $linuxkernel
selkernel() {
    linuxkernel=$(whiptail --title "Select a kernel" --nocancel --menu "Choose the kernel that you want to install." 20 70 4 3>&1 1>&2 2>&3 \
 	"linux" "The vanilla Linux kernel" \
   	"linux-lts" "Long-term (LTS) Linux kernel" \
   	"linux-hardened" "A security-focused Linux kernel" \
   	"linux-rt" "The realtime Linux kernel" \
   	"linux-rt-lts" "The LTS realtime Linux kernel" \
   	"linux-zen" "The linux-zen Linux kernel")
    setkernel=true
    main_menu
}

# Variable: $name (str), $usename (boolean t/f)
setname() {
    input=$(whiptail --title "Full name" --nocancel --inputbox "What's your name?" 0 0 3>&1 1>&2 2>&3)
    if [[ ! -z "$input" ]]; then
    	usename=true
        name="$input"
	else
		usename=false
    fi
    usermenu
}

# Variable: $username (str)
setusername() {
    good_input=false
    while ! $good_input; do
        input=$(whiptail --title "Username" --nocancel --inputbox "Rules for a username:\n\nMust start with a lower-case letter\nCan be followed by any number, letter, or the dash symbol\nCannot be over 32 characters long\n\nEnter a username:" 0 0 3>&1 1>&2 2>&3)
        if printf "%s" "$input" | grep -Eoq "^[a-z][a-z0-9-]*$" && [ "${#input}" -lt 33 ]; then
            if grep -Fxq "$input" "$dir/reserved-users.txt"; then
                whiptail --title "Something went wrong" --msgbox "The username you entered ($input) is or will potentially be reserved for system use. Please select a different one." 2 15
            else
                good_input=true
                username="$input"
            fi
        else
            whiptail --title "Something went wrong" --msgbox "The username you entered ($input) is invalid.\n\nThe username must start with a lower-case letter, which can be followed by any number, letter, or dash symbol. It cannot be over 32 characters long." 2 15
        fi
    done
    setnameofuser=true
    usermenu
}

# Variable: $userpasswd (str)
setuserpasswd() {
    good_input=false
    while ! $good_input; do
        input=$(whiptail --passwordbox --nocancel "Enter the password for $username:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        confirm=$(whiptail --passwordbox --nocancel "Re-enter password to verify:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        if [ -z "$userpasswd" ]; then
            whiptail --title "Something went wrong" --msgbox "You can't have an empty password." 2 15
        elif [ "$confirm" != "$userpasswd" ]; then
            whiptail --title "Something went wrong" --msgbox "The two passwords didn't match!" 2 15
        else
            userpasswd="$input"
            good_input=true
        fi
    done
    setuserpassword=true
    usermenu
}

checkusermenu() {
    if [[ "$setuserpassword" = true && "$setnameofuser" = true ]]; then
        setuser=true
        main_menu
    else
        main_menu
    fi
}

usermenu() {
    choice=$(whiptail --title "User menu" --nocancel --menu "Select an option below using the UP/DOWN keys and ENTER." 20 80 10 \
		"1" "< Back" \
		"2" "Enter your full name (optional)" \
		"3" "Enter your username" \
		"4" "Enter your password" 3>&1 1>&2 2>&3)
    case $choice in
        1) checkusermenu ;;
        2) setname ;;
        3) setusername ;;
        4) setuserpasswd ;;
    esac
}

# Variable: $rootpasswd (str)
selrootpasswd() {
    good_input=false
    while ! $good_input; do
        input=$(whiptail --passwordbox --nocancel "Enter the password for root:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        confirm=$(whiptail --passwordbox --nocancel "Re-enter password to verify:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        if [ -z "$input" ]; then
            whiptail --title "Something went wrong" --msgbox "You can't have an empty password." 2 15
        elif [ "$confirm" != "$input" ]; then
            whiptail --title "Something went wrong" --msgbox "The two passwords didn't match!" 2 15
        else
            rootpasswd="$input"
            good_input=true
        fi
    done
    setrootpasswd=true
    usermenu
}

# Variable: $nameofhost (str)
sethostname() {
    nameofhost=$(whiptail --title "System menu / Hostname" --nocancel --inputbox "What's going to be this system's hostname?" 0 0 3>&1 1>&2 2>&3)
    sethost=true
    sysmenu
}

# Variable: $timezone
settimezone() {
    timezones_array=()
	while IFS= read -r line; do
    	timezones_array+=("$line" "")
	done <<< "$timezones"
	# Show the Whiptail menu and store the selected timezone
	timezone=$(whiptail --title "System menu / Time zone" --menu --nocancel "What's your time zone?\n\nYou can use PgUp or PgDn to quickly scroll." 20 60 10 "${timezones_array[@]}" 3>&1 1>&2 2>&3)
	settime=true
	sysmenu
}

# Variable: $locale (str)
setlocale() {
    locale=$(whiptail --title "System menu / Locale" --nocancel --menu "What's your locale?" 20 80 10 \
		"en_US.UTF-8" "English (United States)" \
		"en_AU.UTF-8" "English (Australia)" \
		"en_CA.UTF-8" "English (Canada)" \
		"en_GB.UTF-8" "English (Great Britain)"
		"es_ES.UTF-8" "Spanish (Spain)" \
		"es_MX.UTF-8" "Spanish (Mexico)" \
		"de_DE.UTF-8" "German (Germany)" \
		"it_IT.UTF-8" "Italian (Italy)" \
		"pt_PT.UTF-8" "Portuguese (Portugal)" \
		"pt_BR.UTF-8" "Portuguese (Brazil)" \
		"ja_JP.UTF-8" "Japanese" 3>&1 1>&2 2>&3)
    setutf=true
    sysmenu
}

# Variable: $cpumake (str)
setcpu() {
    cpumake=$(whiptail --title "System menu / CPU" --nocancel --menu "What's your locale?" 20 80 10 \
		"amd" "Install microcode for AMD CPUs" \
		"intel" "Install microcode for Intel CPUs" 3>&1 1>&2 2>&3)
    setmicrocode=true
    sysmenu
}

# Variable: $gpupkg (str)
setgpu() {
    if [[ "$linuxkernel" = "linux" ]]; then
        recommended="nvidia or nvidia-open"
    elif [[ "$linuxkernel" = "linux-lts" ]]; then
        recommended="nvidia-lts or nvidia-open-dkms"
    elif [[ "$linuxkernel" != "linux" && "$linuxkernel" != "linux-lts" ]]; then
        recommended="nvidia-dkms or nvidia-open-dkms"
    fi
    gpupkg=$(whiptail --title "System menu / GPU" --nocancel --menu "Which GPU package fits best for your GPU?\n\nFor NVIDIA GPUs, $recommended likely fits best for your kernel." 20 80 10 \
		"nvidia" "Proprietary NVIDIA driver for 'linux'" \
		"nvidia-lts" "Proprietary NVIDIA driver for 'linux-lts'" \
		"nvidia-dkms" "Proprietary NVIDIA driver for other kernels" \
		"nvidia-open" "Open-source NVIDIA driver for 'linux'"
		"nvidia-open-dkms" "Open-source NVIDIA driver for other kernels" \
		"mesa" "Open-source Nouveau GPU drivers" 3>&1 1>&2 2>&3)
    setgpupkg=true
    sysmenu
}

# Variable: $swapspace (str)
setswap() {
    swapspace=$(whiptail --title "System menu / Swap space" --nocancel --inputbox "Enter the size of your swap space in human-readable format.\n\nExamples:\n2G, 4G\n200M, 800M" 0 0 3>&1 1>&2 2>&3)
	if [[ -z "$swapspace" ]]; then
		setswap=false
	else
		setswap=true
	fi
	sysmenu
}

checksysmenu() {
    if [[ "$sethost" = true && "$settime" = true && "$setutf" = true && "$setmicrocode" = true && "$setgpupkg" = true ]]; then
        setsys=true
        main_menu
    else
        main_menu
    fi
}

sysmenu() {
    if [[ $setkernel = false ]]; then
		whiptail --title "Come back to this later" --msgbox "You should probably set your specified kernel first, so come back when you've done that." 0 0
		main_menu
	fi
    choice=$(whiptail --title "System menu" --nocancel --menu "Select an option below using the UP/DOWN keys and ENTER." 20 80 10 \
		"1" "< Back" \
		"2" "Set the hostname" \
		"3" "Set the timezone" \
		"4" "Set the locale" \
		"5" "Set CPU microcode" \
		"6" "Set GPU drivers" \
		"7" "Set swap space" 3>&1 1>&2 2>&3)
    case $choice in
        1) checksysmenu ;;
        2) sethostname ;;
        3) settimezone ;;
        4) setlocale ;;
        5) setcpu ;;
        6) setgpu ;;
        7) setswap ;;
    esac
}

# Variable: $min_install (boolean t/f), $desktop (str), {$desktop_pkgs[@]} (array), $displaymgr (str). $setdesktop
setdesktop() {
	min_install=true
	desktop=$(whiptail --title "Things to install / Desktop environment" --menu --nocancel "What desktop environment do you want?" 25 78 12 \
	"budgie" "Install the Budgie desktop environment" \
	"cinnamon" "Install the Cinnamon desktop environment" \
	"gnome" "Install the GNOME desktop environment" \
	"lxde" "Install the LXDE desktop environment" \
	"lxqt" "Install the LXQt desktop environment" \
	"mate" "Install the MATE desktop environment" \
	"plasma" "Install the KDE Plasma desktop environment" \
	"xfce4" "Install the Xfce desktop environment" \
	"i3" "Install the i3 window manager" \
	"sway" "Install the Sway window manager" \
	"No DE" "Install nothing, minimal installation" 3>&1 1>&2 2>&3)

	if [[ "$desktop" != "No DE" ]]
	then
		min_install=false
		desktop_pkgs=("xorg-server" "$desktop")
		if [[ "$desktop" = "cinnamon" ]]; then
			desktop_pkgs+=("metacity")
		elif [[ "$desktop" = "lxqt" ]]; then
			desktop_pkgs+=("oxygen-icons")
		fi

		displaymgr=$(whiptail --title "Things to install / Display manager" --menu --nocancel "What display manager do you want?" 25 78 7 \
		"sddm" "Recommended for KDE & LXQt" \
		"ly" "Terminal display manager" \
		"gdm" "Recommended for GNOME" \
		"lightdm" "Cross-desktop display manager" \
		"lxdm" "LXDE display manager" \
		"xorg-xinit" "Start GUIs manually with startx/xinitrc" 3>&1 1>&2 2>&3)
		desktop_pkgs+=("$displaymgr")

	else
		min_install=true
	fi
	setdedm=true
	desktopmenu
}

# Variable: $termemul, $setterm
settermemul() {
    termemul=$(whiptail --title "Things to install / Terminal emulator" --menu --nocancel "Which terminal emulator do you want?" 25 78 12 \
		"alacritty" "A cross-platform, GPU-accelerated terminal emulator" \
		"cool-retro-term" "A terminal emulator that mimics an old cathode display" \
		"deepin-terminal" "Terminal emulator for the Deepin desktop" \
		"foot" "Lightweight terminal emulator for Wayland with sixel support" \
		"konsole" "Terminal emulator for the KDE desktop" \
		"kitty" "A modern, hackable, featureful, OpenGL-based term. emulator" \
		"qterminal" "Lightweight Qt-based terminal emulator" \
		"terminology" "Terminal emulator by the Enlightenment project team" \
		"xterm" "Simple terminal emulator for the X Window System" \
		"yakuake" "Drop-down terminal based on Konsole" \
		"zutty" "A high-end terminal for low-end systems" 3>&1 1>&2 2>&3)
		desktop_pkgs+=("$termemul")
	setterm=true
    desktopmenu

}

# Variable: $aurinstall (boolean t/f)
setaur() {
	aurinstall=false
	whiptail --title "Things to install / Install AUR helper" --yesno "Do you want to install yay to access packages in the Arch User Repository?." --defaultno --yes-button "Install" --no-button "Don't install" 0 0 3>&1 1>&2 2>&3
	if [[ $? -eq 0 ]]; then
        	aurinstall=true
	fi
 	desktopmenu
}

checkdesktopmenu() {
	if [[ "$setdedm" = true && "$setterm" = true ]]; then
        setdesktop=true
        main_menu
    else
        main_menu
    fi
}

desktopmenu() {
    choice=$(whiptail --title "Things to install" --nocancel --menu "Select an option below using the UP/DOWN keys and ENTER." 20 80 10 \
		"1" "< Back" \
		"2" "Desktop environments" \
		"3" "Terminal emulators" \
		"4" "AUR helper" 3>&1 1>&2 2>&3)
    case $choice in
        1) checkdesktopmenu ;;
        2) setdesktop ;;
        3) settermemul ;;
        4) setaur ;;
    esac
}

configfile() {
    configfilepath=$(whiptail --title "Preset configuration file" --nocancel --inputbox "Enter the path to your configuration file.\n\nThere's a template included in the cloned repository named 'setup.conf'. If no valid file path is provided,\nthat will be the default." 0 0 3>&1 1>&2 2>&3)
    if [[ ! -z "$configfilepath" && -f "$configfilepath" ]]; then
        source $configfilepath
    else
        source $dir/setup.conf
    fi
    main_menu
}

installarch() {

	if [[ "$setpart" = true && "$setkernel" = true && "$setuser" = true && "$setrootpasswd" = true && "$setsys" = true && "$setdesktop" = true && "$setdesktop" = true && "$setswap" = true ]]; then
		confirm=$(whiptail --title "Are you ready?" --nocancel --yesno "Are you ready to install Arch Linux?\n\nThere is no going back if you choose 'I'm ready.'" --defaultno --yes-button "I'm ready" --no-button "WAIT..." 0 0 3>&1 1>&2 2>&3; echo $?)
		if [[ $confirm -eq 0 ]]; then
			confirm=$(whiptail --title "Are you ready?" --nocancel --yesno "ARE YOU SURE?\n\nThere really is no going back." --defaultno --yes-button "I'm sure" --no-button "Never mind" 0 0 3>&1 1>&2 2>&3; echo $?)
			if [[ $confirm -eq 1 ]]; then
				exit 0
			else
				{
					for ((i = 0 ; i <= 100 ; i+=1)); do
						sleep 0.05
						echo $i
					done
				} | whiptail --gauge "Installation will begin once this finishes...\n\nYou can see what's happening by entering Alt+F2 (the tty2 console)." 8 50 0

			fi
		else
			whiptail --title "Going back" --msgbox "Never mind then." 0 5
			main
		fi
	else
		whiptail --title "Something went wrong" --msgbox "You're missing some stuff. Check back at your configurations and come back here." 0 5
		main
	fi

	whiptail --title "Installing Arch Linux..." --infobox "Here we go!" 8 35
	sleep 3

	if ! $formatefi; then
		whiptail --title "Partitioning" --infobox "The ESP has been untouched." 8 35
		sleep 2
	else
		whiptail --title "Partitioning" --infobox "Formatting the EFI System partition..." 8 35
		mkfs.fat -F32 $efipart > /dev/tty2 2>&1

	fi

	if [[ "$disklayout" = "lvm" ]]; then
		whiptail --title "LVM setup" --infobox "Creating physical volume $rootpart..." 8 35
		pvcreate $rootpart > /dev/tty2 2>&1
		sleep 1

		whiptail --title "LVM setup" --infobox "Creating volume group $vgname..." 8 35
		vgcreate $vgname $rootpart > /dev/tty2 2>&1
		sleep 1

		whiptail --title "LVM setup" --infobox "Creating logical volume $lvname" 8 35
		lvcreate -l 100%FREE $vgname -n $lvname > /dev/tty2 2>&1
		sleep 1

		whiptail --title "LVM setup" --infobox "Finishing LVM setup..." 8 35
		modprobe dm_mod
		sleep 1
		vgchange -ay > /dev/tty2 2>&1
		sleep 1
		rootpath=/dev/$vgname/$lvname

		whiptail --title "LVM setup" --infobox "Formatting & mounting $rootpath..." 8 35
		mkfs.ext4 -q $rootpath
		sleep 1
  		mount $rootpath /mnt
    		sleep 1

	elif [[ "$disklayout" = "basic" ]]; then
 		whiptail --title "Partitioning" --infobox "Formatting & mounting $rootpart..." 8 35
 		mkfs.ext4 -q $rootpart
   		mount $rootpart /mnt
		sleep 1
 	fi

	whiptail --title "Partitioning" --infobox "Formatting & mounting $rootpart..." 8 35
   	mount --mkdir $efipart /mnt/boot/efi
    	sleep 1

 	whiptail --title "Getting things ready..." --infobox "Building fstab file..." 8 35
	mkdir /mnt/etc
	genfstab -U /mnt >> /mnt/etc/fstab
	sleep 1

	whiptail --title "Getting things ready..." --infobox "Getting some files..." 8 35
	mkdir /mnt/install
 	cp $dir/installfiles/* /mnt/install/
 	if [[ "$gpupkg" != "mesa" ]]; then
 		cat <<NVIDIAHOOK > /mnt/install/nvidia.hook
[Trigger]
Operation=Install
Operation=Upgrade
Operation=Remove
Type=Package
Target=$gpupkg
Target=$linuxkernel

[Action]
Description=Update NVIDIA module in initcpio
Depends=mkinitcpio
When=PostTransaction
NeedsTargets
Exec=/bin/sh -c 'while read -r trg; do case $trg in linux*) exit 0; esac; done; /usr/bin/mkinitcpio -P'
NVIDIAHOOK
	fi
	sleep 1

	whiptail --title "Getting things ready..." --infobox "Installing the base package..." 8 35
	pacstrap /mnt base --noconfirm --needed &> /dev/tty2
	sleep 1

 	whiptail --title "Installing Arch Linux..." --infobox "Installing the Linux kernel and other tools..." 8 35
	pacstrap /mnt $linuxkernel $linuxkernel-headers linux-firmware base-devel git neofetch zip $cpumake-ucode networkmanager neovim wpa_supplicant wireless_tools netctl dialog bluez bluez-utils ntfs-3g &> /dev/tty2

	whiptail --title "Installing Arch Linux..." --infobox "Enabling Network Manager..." 8 35
	arch-chroot /mnt systemctl enable NetworkManager &> /dev/tty2

 	if [[ "$disklayout" = "lvm" ]]; then
		pacstrap /mnt lvm2 &> /dev/tty2
		whiptail --title "Installing Arch Linux..." --infobox "Configuring the Linux initcpio..." 8 35
		arch-chroot /mnt cp -f /install/mkinit.conf /etc/mkinitcpio.conf
		arch-chroot /mnt mkinitcpio -P > /dev/tty2 2>&1
  	fi

	whiptail --title "Installing Arch Linux..." --infobox "Setting the locale..." 8 35
	sed -i 's/#$locale/$locale/' /mnt/etc/locale.gen
	arch-chroot /mnt locale-gen > /dev/tty2
	echo "LANG=$locale" > /mnt/etc/locale.conf
	sleep 1

 	whiptail --title "Installing Arch Linux..." --infobox "Configuring users and passwords..." 8 35
   	if [[ "$usename" = "true" ]]; then
		arch-chroot /mnt useradd -m -g users -G wheel $username -c "$name"
	else
		arch-chroot /mnt useradd -m -g users -G wheel $username
	fi
	arch-chroot /mnt chpasswd <<<"$username:$userpasswd"
 	arch-chroot /mnt chpasswd <<<"root:$rootpasswd"
  	sleep 1
	sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers

	if [[ "$aurinstall" = true ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Installing the 'yay' AUR helper..." 8 35
		pacstrap /mnt go
		cat <<AURINSTALL > /mnt/aurinstall.sh
su $username -c 'git -C /home/$username clone https://aur.archlinux.org/yay.git
cd /home/$username/yay

su $username -c 'makepkg'

pacman -U /home/$username/yay/yay-*.pkg.tar.zst
AURINSTALL
		arch-chroot /mnt /bin/bash /aurinstall.sh
	fi

   	whiptail --title "Installing Arch Linux..." --infobox "Installing and configuring GRUB..." 8 35
	pacstrap /mnt grub dosfstools mtools os-prober efibootmgr &> /dev/tty2
	arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=arch_grub --recheck &> /dev/tty2
	if [ -d /boot/grub/locale ]; then
		cp /mnt/usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /mnt/boot/grub/locale/en.mo
		sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER="false"/' /mnt/etc/default/grub
		arch-chroot /mnt grub-mkconfig --output=/boot/grub/grub.cfg &> /dev/tty2
	else
		mkdir /mnt/boot/grub/locale
		cp /mnt/usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /mnt/boot/grub/locale/en.mo
		sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER="false"/' /mnt/etc/default/grub
		arch-chroot /mnt grub-mkconfig --output=/boot/grub/grub.cfg &> /dev/tty2
	fi
	sleep 1

	if [[ "$setswap" = "true" ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Configuring swap space..." 8 35
		mkswap -U clear --size $swapspace --file /swapfile > /dev/tty2
		swapon /swapfile
		echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
		mount -a
		swapon -a

	fi

	whiptail --title "Installing Arch Linux..." --infobox "Configuring the system..." 8 35
	echo "$nameofhost" > /mnt/etc/hostname
	echo -e "127.0.0.1	localhost\n127.0.1.1	$nameofhost" > /mnt/etc/hosts
	arch-chroot /mnt ln -sf /usr/share/zoneinfo/$timezone /etc/localtime &> /dev/tty2
	arch-chroot /mnt hwclock --systohc &> /dev/tty2
	arch-chroot /mnt systemctl enable systemd-timesyncd &> /dev/tty2
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Enabling the multilib repository..." 8 35
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
	arch-chroot /mnt pacman -Sy &> /dev/tty2

	if [[ "$gpupkg" != "mesa" ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Installing NVIDIA drivers..." 8 35
		pacstrap /mnt $gpupkg nvidia-utils lib32-nvidia-utils
		mkdir /mnt/etc/pacman.d/hooks
		cp /mnt/install/nvidia.hook /mnt/etc/pacman.d/hooks/
		sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"/' /mnt/etc/default/grub
		sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /mnt/etc/mkinitcpio.conf
		arch-chroot /mnt mkinitcpio -P &> /dev/tty2
		arch-chroot /mnt grub-mkconfig --output=/boot/grub/grub.cfg &> /dev/tty2
	else
		whiptail --title "Installing Arch Linux..." --infobox "Installing Nouveau GPU drivers..." 8 35
		pacstrap /mnt mesa lib32-mesa
	fi
	whiptail --title "Installing Arch Linux..." --infobox "Installing PipeWire..." 8 35
	pacstrap /mnt pipewire lib32-pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack lib32-pipewire-jack --noconfirm --needed > /dev/tty2 2>&1

	if ! $min_install; then
		whiptail --title "Installing Arch Linux..." --infobox "Installing desktop packages..." 8 35
		pacstrap /mnt ${desktop_pkgs[@]} &> /dev/tty2
		if [[ "$displaymgr" != "xorg-xinit" ]]; then
			arch-chroot /mnt systemctl enable $displaymgr &> /dev/tty2
		fi
	fi
	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Blacklisting the PC speaker..." 8 35
	echo -e "blacklist pcspkr\nblacklist snd_pcsp" > /mnt/etc/modprobe.d/nobeep.conf
	sleep 1

	rm -rf /mnt/install
	whiptail --title "Installation complete" --msgbox "Installation is now COMPLETE.\n\nYou will now be returned to the main menu." 0 0
	main_menu
}

exitoptions() {
	choice=$(whiptail --title "Exit options" --nocancel --menu "How would you like to exit?" 20 80 10 \
		"1" "Return to Linux console" \
		"2" "Power off the system" \
		"3" "Reboot the system" \
		"4" "Chroot into installation" 3>&1 1>&2 2>&3)
	case $choice in
		1) exit 0 ;;
		2) poweroff ;;
		3) reboot ;;
		4) arch-chroot /mnt ;;
	esac
}

main_menu() {
    choice=$(whiptail --title "Main Menu" --nocancel --menu "Select an option below using the UP/DOWN keys and ENTER." 20 80 10 \
		"1" "Select partitions" \
		"2" "Select a kernel" \
		"3" "Create your user account >" \
		"4" "Set the root password" \
		"5" "System settings >" \
		"6" "Choose some things to install... >" \
		"7" "Install Arch Linux" \
		"8" "Use a configuration file..." \
		"9" "Exit installer" 3>&1 1>&2 2>&3)
    case $choice in
        1) partconfig ;;
        2) selkernel ;;
        3) usermenu ;;
        4) selrootpasswd ;;
        5) sysmenu ;;
        6) desktopmenu ;;
        7) installarch ;;
        8) configfile ;;
        *) exitoptions ;;
    esac
}

start
main_menu
