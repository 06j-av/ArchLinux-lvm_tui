#!/bin/bash

start() {
    whiptail --title "Welcome to Arch Linux!" --msgbox "Hello!\n\nWelcome to the Arch Linux install script.\n\nMake sure your EFI and root partition is ready.\n\nWe'll need to check some things first." --ok-button "Let's get started!" 0 5

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
    ARCHIS64=false
    whiptail --title "Just a couple things first..." --infobox "Checking your firmware..." 8 35
    if [ -d /sys/firmware/efi ]; then
        UEFI=true
    fi
    if ! $UEFI; then
        whiptail --title "Unsupported firmware" --msgbox "This installation script only supports UEFI firmware.\n\nCould it be that you booted in BIOS mode?\n\nIf not, you cannot run the installer with the current firmware." 2 15
        exit 1
    fi

    whiptail --title "Just a couple things first..." --infobox "Checking system architecture..." 8 35
    if [[ "$(uname -m)" != "x86_64" ]]; then
        whiptail --title "Unsupported architecture" --msgbox "This installation script only supports the x86_64 architecture.\n\nYou cannot run the installer with the current system architecture." 2 15
        exit 1
    fi
    whiptail --title "Supported system" --msgbox "You're system's all good! Let's proceed." 0 5
}

partconfig() {
    partitions=$(lsblk -npo NAME,FSTYPE,SIZE,PARTTYPENAME)
	efipart=$(whiptail --title "Select partitions..." --nocancel --inputbox "Enter the path to the EFI partition.\n\nThis is usually the first partition on your disk.\n\n$partitions" 0 0 3>&1 1>&2 2>&3)

	# Check if the ESP is a device file and a "EFI System" partition
	if [[ -b "$efipart" && "$(lsblk -no TYPE "$efipart")"  == "part" && "$(lsblk -no PARTTYPENAME "$efipart" == "EFI System" )" ]]; then
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

    if [[ -b "$rootpart" && "$(lsblk -no TYPE "$rootpart")"  == "part" && "$(lsblk -no PARTTYPENAME "$rootpart" == "Linux LVM" )" ]]; then
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

selkernel() {
    linuxkernel=$(whiptail --title "Select a kernel" --nocancel --menu "Choose the kernel that you want to install." 20 70 4 3>&1 1>&2 2>&3 \
 	"linux" "The vanlilla Linux kernel and modules" \
   	"linux-lts" "Long-term (LTS) Linux kernel" \
   	"linux-hardened" "A security-focuzed Linux kernel" \
   	"linux-rt" "The realtime Linux kernel" \
   	"linux-rt-lts" "The LTS realtime Linux kernel" \
   	"linux-zen" "The linux-zen Linux kernel")
    kernelmenu="Selected kernel: $linuxkernel"
    setkernel=true
    main_menu
}

setname() {
    input=$(whiptail --title "Full name" --nocancel --inputbox "What's your name?" 0 0 3>&1 1>&2 2>&3)
    if [[ ! -z "$input" ]]; then
        name="$input"
    fi
    usermenu
}

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

selrootpasswd() {
    good_input=false
    while ! $good_input; do
        input=$(whiptail --passwordbox --nocancel "Enter the password for root:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        confirm=$(whiptail --passwordbox --nocancel "Re-enter password to verify:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        if [ -z "$userpasswd" ]; then
            whiptail --title "Something went wrong" --msgbox "You can't have an empty password." 2 15
        elif [ "$confirm" != "$userpasswd" ]; then
            whiptail --title "Something went wrong" --msgbox "The two passwords didn't match!" 2 15
        else
            rootpasswd="$input"
            good_input=true
        fi
    done
    setrootpasswd=true
    usermenu
}

sethostname() {
    nameofhost=$(whiptail --title "System menu / Hostname" --nocancel --inputbox "What's going to be this system's hostname?" 0 0 3>&1 1>&2 2>&3)
    sethost=true
    sysmenu
}

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

setlocale() {
    choice=$(whiptail --title "System menu / Locale" --nocancel --menu "What's your locale?" 20 80 10 \
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

setcpu() {
    choice=$(whiptail --title "System menu / CPU" --nocancel --menu "What's your locale?" 20 80 10 \
		"amd" "Install microcode for AMD CPUs" \
		"intel" "Install microcode for Intel CPUs" 3>&1 1>&2 2>&3)
    setmicrocode=true
    sysmenu
}

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

setswap() {
    swapspace=$(whiptail --title "System menu / Swap space" --nocancel --inputbox "Enter the size of your swap space in human-readable format.\n\nExamples:\n2G, 4G\n200M, 800M" 0 0 3>&1 1>&2 2>&3)
	setswap=true
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
		"4" "Set the locale"
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
	desktopmenu
}

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

setapps() {
    aurinstall=false
	whiptail --title "Things to install / Install AUR helper" --yesno "Do you want to install yay to access packages in the Arch User Repository?." --defaultno --yes-button "Install" --no-button "Don't install" 0 0 3>&1 1>&2 2>&3
	if [[ $? -eq 0 ]]; then
        aurinstall=true
    fi
    while true; do
        package=$(whiptail --title "Things to install / Install other packages" --nocancel --inputbox "If you want to install other packages, enter their package name here.\n\nLeave blank to finish." 0 0 3>&1 1>&2 2>&3)
        if [ $? -ne 0 ]
    done
}

desktopmenu() {
    choice=$(whiptail --title "Things to install" --nocancel --menu "Select an option below using the UP/DOWN keys and ENTER." 20 80 10 \
		"1" "< Back" \
		"2" "Desktop environments" \
		"3" "Terminal emulators" \
		"4" "Install other packages" 3>&1 1>&2 2>&3)
    case $choice in
        1) checkdesktopmenu ;;
        2) setdesktop ;;
        3) settermemul ;;
        4) setapps ;;
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

main_menu() {
    choice=$(whiptail --title "Main Menu" --nocancel --menu "Select an option below using the UP/DOWN keys and ENTER." 20 80 10 \
		"1" "Select partitions" \
		"2" "Select a kernel" \
		"3" "Create your user account >" \
		"4" "Set the root password" \
		"5" "System settings >" \
		"6" "Choose some things to install... >"
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
        *) exit 0 ;;
    esac
}

start
main_menu
