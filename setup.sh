#!/bin/bash

start() {
    # Welcome message
    whiptail --title "Welcome to Arch Linux!" --msgbox "Hello!\n\nWelcome to the Arch Linux install script.\n\nMake sure your EFI and root partition is ready.\n\nWe'll need to check some things first." --ok-button "Begin" 0 5

    # Set the directory to the script's parent directory
    whiptail --title "Just a couple things first..." --infobox "Setting the directory..." 8 35
    script_dir="$(dirname "$0")"
    cd "$script_dir"
    dir=$(pwd)
    sleep 1

    # Check for a sufficient internet connection
    whiptail --title "Just a couple things first..." --infobox "Checking your internet connection..." 8 35
    ping -c 5 archlinux.org &> /dev/null 2>&1

    # If ping wasn't successful, return a connection error
    if [[ $? -ne 0 ]]; then
        whiptail --title "Connection error" --msgbox "There's something wrong with your internet connection. Here's some things that might help:\n\nIf you're using a wired connection, is the cable plugged in correctly?\nIf you're using a wireless connection, did you correctly set it up with the 'iwctl' command?\n\nOnce you have a working internet connection, rerun the installer!" 2 15
        exit 1
    fi

    # Check if the user is running UEFI firmware
    UEFI=false
    whiptail --title "Just a couple things first..." --infobox "Checking your firmware..." 8 35
    if [ -d /sys/firmware/efi ]; then
        UEFI=true
    fi
    if ! $UEFI; then
        whiptail --title "Unsupported firmware" --msgbox "This installation script only supports UEFI firmware.\n\nCould it be that you booted in BIOS mode?\nYou cannot run the installer with BIOS firmware." 2 15
        exit 1
    fi


    # Check if the user is running x64/amd64 hardware
    whiptail --title "Just a couple things first..." --infobox "Checking system architecture..." 8 35
    if [[ "$(uname -m)" != "x86_64" ]]; then
        whiptail --title "Unsupported architecture" --msgbox "This installation script only supports the x86_64 architecture.\n\nYou cannot run the installer with the current system architecture." 2 15
        exit 1
    fi
    sleep 1

    # If all succeeds, proceed
    whiptail --title "Supported system" --msgbox "Your system's all good! Let's proceed.\n\nBy the way, mistakes will stop the script." 0 5

    useconfig=false
    whiptail --title "Configuration file" --yesno "Do you have a configuration file you can use?" --defaultno 0 0 3>&1 1>&2 2>&3

    if [[ $? -eq 0 ]]; then
        useconfig=true
    else
        whiptail --title "Arch Linux installer" --msgbox "These are the steps we will help you go through: \n\n1. Selecting your partitions \n2. Selecting a kernel\n3. Set up a user account\n4. Set up your root password\n5. Configure your system\n6. Select a desktop environment." 0 5
    fi

}

checkefi() {
    # Check if the ESP is a device file and a "EFI System" partition
    if [[ -b "$efipart" && "$(lsblk -no TYPE "$efipart")"  == "part" && "$(lsblk -no PARTTYPENAME "$efipart")" = "EFI System" ]]; then
        echo "$efipart is a valid ESP." &> /dev/tty2
    else
        whiptail --title "Something went wrong" --msgbox "$efipart is not a valid EFI System Partition." 0 0
        exit 1
    fi
}

checkrootpart() {
    if [[ -b "$rootpart" && "$(lsblk -no TYPE "$rootpart")"  == "part" && "$(lsblk -no PARTTYPENAME "$rootpart")" = "Linux LVM" || "$(lsblk -no PARTTYPENAME "$rootpart")" = "Linux filesystem" ]]; then
        echo "$rootpart is a valid ESP."  &> /dev/tty2
    else
        whiptail --title "Something went wrong" --msgbox "$rootpart is not a valid root partition." 0 0
        exit 1
    fi
}

checkusername() {
    if printf "%s" "$username" | grep -Eoq "^[a-z][a-z0-9-]*$" && [ "${#username}" -lt 33 ]; then
            if grep -Fxq "$input" "$dir/reserved-users.txt"; then
                whiptail --title "Something went wrong" --msgbox "The username you entered ($username) is or will potentially be reserved for system use.\n\nCheck reserved-users.txt for a list of reserved usernames." 0 0
                exit 1
            fi
    else
        whiptail --title "Something went wrong" --msgbox "The username you entered ($username) is invalid.\n\nThe username must start with a lower-case letter, which can be followed by\nany number, letter, or dash symbol. It cannot be over 32 characters long." 0 0
        exit 1
    fi
}

checkpasswd() {
    if [ -z "$1" ]; then
        whiptail --title "Something went wrong" --msgbox "You can't have an empty password." 0 0
        exit 1
    elif [[ "$2" != "$1" && ! $useconfig ]]; then
        whiptail --title "Something went wrong" --msgbox "The two passwords didn't match!" 0 0
        exit 1
    fi
}

checkswap() {
    pattern='^[0-9]+[GMK]$'

    if [[ "$swapspace" =~ $pattern ]]; then
        makeswap=true
    else
        whiptail --title "Something went wrong" --msgbox "The swap size you entered is invalid." 2 15
        exit 1
    fi
}

partition() {
    partitions=$(lsblk -npo NAME,FSTYPE,SIZE,PARTTYPENAME)
    agree=false
    while ! $agree; do
        efipart=$(whiptail --title "Select partitions..." --nocancel --inputbox "Enter the path to the EFI partition.\n\nThis is usually the first partition on your disk.\n\n$partitions" 0 0 3>&1 1>&2 2>&3)

        checkefi

        formatefi=false
        whiptail --title "Format?" --yesno "Do you want to format $efipart?\n\nIf you are dual booting, we highly suggest NOT formatting the partition." --defaultno --yes-button "Format" --no-button "Don't format" 0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            formatefi=true
        fi
        rootpart=$(whiptail --title "Select partitions..." --nocancel --inputbox "You have selected $efipart as your EFI system partition.\n\Enter the path to your root partition.\n\n$partitions" 0 0 3>&1 1>&2 2>&3)

        checkrootpart

        if [[ "$efipart" = "$rootpart" ]]; then
            whiptail --title "Something went wrong" --msgbox "The ESP and root partition cannot be the same!" 0 0
            main_menu
        fi

        disklayout="basic"
        whiptail --title "Disk layout" --yesno "What disk layout do you want to use for the root partition?\n\nBasic: Just a root partition, nothing else\nLVM: Logical storage volumes stored on volume groups\nthat combine multiple disks\n\nSelecting LVM will use $rootpart as the root logical volume." --defaultno --yes-button "Basic" --no-button "LVM" 0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 1 ]]; then
            disklayout="lvm"
            vgname=$(whiptail --title "LVM setup" --inputbox "Name the volume group:" 0 0 3>&1 1>&2 2>&3)
            lvname=$(whiptail --title "LVM setup" --nocancel --inputbox "Name the root logical volume:" 0 0 3>&1 1>&2 2>&3)
        fi
        case $formatefi in
                "false") eficonfirm="(Don't format)" ;;
                "true") eficonfirm="(Format)" ;;
        esac

        case $disklayout in
                "basic") diskconfirm="You want to use a basic disk layout." ;;
                "lvm") diskconfirm="You want to use an LVM disk layout." ;;
        esac

        whiptail --title "Just to confirm..." --yesno "Your EFI partition is $efipart $eficonfirm.\n\nYour root partition is $rootpart.\n$diskconfirm\n\nIs this correct?" --defaultno  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done
}

kernel() {
    agree=false
    while ! $agree; do
        linuxkernel=$(whiptail --title "Select a kernel" --nocancel --menu "Choose the kernel that you want to install." 20 70 6 3>&1 1>&2 2>&3 \
        "linux" "The vanilla Linux kernel" \
        "linux-lts" "Long-term (LTS) Linux kernel" \
        "linux-hardened" "A security-focused Linux kernel" \
        "linux-rt" "The realtime Linux kernel" \
        "linux-rt-lts" "The LTS realtime Linux kernel" \
        "linux-zen" "The linux-zen Linux kernel")
        whiptail --title "Just to confirm..." --yesno "You want to use the $linuxkernel Linux kernel.\n\nIs this correct?"  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done
}

createuser() {
    agree=false
    while ! $agree; do
        usename=false
        input=$(whiptail --title "Name" --nocancel --inputbox "What's your name? This will not be your username\nof which you will use to log in.\n\nLeave blank to skip." 0 0 3>&1 1>&2 2>&3)
        if [[ ! -z "$input" ]]; then
            name=$input
            usename=true
        else
            name="No name entered"
        fi
        username=$(whiptail --title "Username" --nocancel --inputbox "Rules for a username:\n\nMust start with a lower-case letter\nCan be followed by any number, letter, or the dash symbol\nCannot be over 32 characters long\n\nEnter a username:" 0 0 3>&1 1>&2 2>&3)
        checkusername
        userpasswd=$(whiptail --passwordbox --nocancel "Enter the password for $username:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        confirm=$(whiptail --passwordbox --nocancel "Re-enter password to verify:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        checkpasswd $userpasswd $confirm
        whiptail --title "Just to confirm..." --yesno "Your username is $username ($name).\n\nIs this correct along with your password?"   0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done
}

setrootpasswd() {
    agree=false
    while ! $agree; do
        rootpasswd=$(whiptail --passwordbox --nocancel "Enter the password for root:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        confirm=$(whiptail --passwordbox --nocancel "Re-enter password to verify:" 8 78 --title "User password" 3>&1 1>&2 2>&3)
        checkpasswd $rootpasswd $confirm
        whiptail --title "Just to confirm..." --yesno "You want to use this password for root?"   0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done
}

configsys() {
    agree=false
    while ! $agree; do
        # Show the Whiptail menu and store the selected timezone
        host=$(whiptail --title "Hostname" --nocancel --inputbox "What's going to be this system's hostname?" 0 0 3>&1 1>&2 2>&3)
        whiptail --title "Just to confirm..." --yesno "Your hostname will be $host.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done

    timezones=$(timedatectl list-timezones)
    timezones_array=()
    while IFS= read -r line; do
        timezones_array+=("$line" "")
    done <<< "$timezones"
    agree=false
    while ! $agree; do
        # Show the Whiptail menu and store the selected timezone
        timezone=$(whiptail --title "Time zone" --menu --nocancel "What's your time zone?\n\nYou can use PgUp or PgDn to quickly scroll." 20 60 10 "${timezones_array[@]}" 3>&1 1>&2 2>&3)
        whiptail --title "Just to confirm..." --yesno "Your timezone is $timezone.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done

    agree=false
    while ! $agree; do
        locale=$(whiptail --title "Locale" --nocancel --menu "What's your locale?" 20 80 10 \
		"en_US.UTF-8" "English (United States)" \
		"en_AU.UTF-8" "English (Australia)" \
		"en_CA.UTF-8" "English (Canada)" \
		"en_GB.UTF-8" "English (Great Britain)" \
		"es_ES.UTF-8" "Spanish (Spain)" \
		"es_MX.UTF-8" "Spanish (Mexico)" \
		"de_DE.UTF-8" "German (Germany)" \
		"it_IT.UTF-8" "Italian (Italy)" \
		"pt_PT.UTF-8" "Portuguese (Portugal)" \
		"pt_BR.UTF-8" "Portuguese (Brazil)" \
		"ja_JP.UTF-8" "Japanese" 3>&1 1>&2 2>&3)
		whiptail --title "Just to confirm..." --yesno "Your current locale is $locale.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done

    agree=false
    while ! $agree; do
        cpumake=$(whiptail --title "CPU microcode" --nocancel --menu "What's your locale?" 20 80 10 \
		"amd" "Install microcode for AMD CPUs" \
		"intel" "Install microcode for Intel CPUs" 3>&1 1>&2 2>&3)
		whiptail --title "Just to confirm..." --yesno "The microcode that fits your CPU is $cpumake-ucode.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done

    agree=false
    while ! $agree; do
        if [[ "$linuxkernel" = "linux" ]]; then
            recommended="nvidia or nvidia-open"
        elif [[ "$linuxkernel" = "linux-lts" ]]; then
            recommended="nvidia-lts or nvidia-open-dkms"
        elif [[ "$linuxkernel" != "linux" && "$linuxkernel" != "linux-lts" ]]; then
            recommended="nvidia-dkms or nvidia-open-dkms"
        fi
        gpupkg=$(whiptail --title "GPU driver" --nocancel --menu "Which GPU package fits best for your GPU?\n\nFor NVIDIA GPUs, $recommended likely fits best for your kernel." 20 80 10 \
            "nvidia" "Proprietary NVIDIA driver for 'linux'" \
            "nvidia-lts" "Proprietary NVIDIA driver for 'linux-lts'" \
            "nvidia-dkms" "Proprietary NVIDIA driver for other kernels" \
            "nvidia-open" "Open-source NVIDIA driver for 'linux'" \
            "nvidia-open-dkms" "Open-source NVIDIA driver for other kernels" \
            "mesa" "Open-source Nouveau GPU drivers" 3>&1 1>&2 2>&3)
        whiptail --title "Just to confirm..." --yesno "The GPU package that fits your GPU is $gpupkg.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            agree=true
        else
            whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
        fi
    done


    agree=false
    while ! $agree; do
        whiptail --title "Set swap?" --yesno "Do you want to set up a swap file?\n\nSwap is part of disk space that is used as extra memory for\nthe system.\n\nThis will be a file, not a partition."  0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            swapspace=$(whiptail --title "Swap space" --nocancel --inputbox "Enter the size of your swap space in human-readable format.\n\nExamples:\n2G, 4G\n200M, 800M\n\nOnly KiB, MiB, or GiB-sized files are supported." 0 0 3>&1 1>&2 2>&3)
            checkswap
            whiptail --title "Just to confirm..." --yesno "You want a $swapspace-sized swap file.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
            if [[ $? -eq 0 ]]; then
                agree=true
                makeswap=true
            else
                whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
            fi
        else
            whiptail --title "Just to confirm..." --yesno "You want no swap space.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
            if [[ $? -eq 0 ]]; then
                agree=true
                makeswap=false
            else
                whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
            fi
        fi
    done
}

desktop() {
    agree=false
    while ! $agree; do
        min_install=true
        desktop_pkgs=()
        desktoppkg=$(whiptail --title "Things to install / Desktop environment" --menu --nocancel "What desktop environment do you want?" 25 78 12 \
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
        if [[ "$desktoppkg" != "No DE" ]]
        then
            min_install=false
            desktop_pkgs=("xorg-server" "$desktoppkg")
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
            browser=$(whiptail --title "Things to install / Browser" --menu --nocancel "Which browser do you want?" 25 78 12 \
            "skip" "Install a browser later" \
            "firefox" "Standalone web browser from mozilla.org" \
            "chromium" "THe open source project behind Google Chrome" \
            "vivaldi" "An advanced browser made with the power user in mind" \
            "falkon" "Web browser based on QtWebEngine" \
            "konqueror" "KDE web browser" \
            "epiphany" "The GNOME Web browser" 3>&1 1>&2 2>&3)

            if [[ "$browser" != "skip" ]]; then
                desktop_pkgs+=("$browser")
            fi

            whiptail --title "Just to confirm..." --yesno "You want a desktop environment along with a display manager and other programs.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
            if [[ $? -eq 0 ]]; then
                agree=true
            else
                whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
            fi
        else
            whiptail --title "Just to confirm..." --yesno "You want a minimal installation.\n\nIs that correct?"  0 0 3>&1 1>&2 2>&3
            if [[ $? -eq 0 ]]; then
                agree=true
                min_install=true
            else
                whiptail --title "Just to confirm..." --msgbox "Let's start again." --ok-button "Proceed" 0 0
            fi
        fi
    done
}

checkvars() {
    required_vars=(
        "efipart" "rootpart" "disklayout" "vgname" "lvname" "kernel" "name" "username" "userpasswd" "rootpasswd"
        "host" "timezone" "locale" "cpumake" "gpupkg" "desktop_pkgs" "formatefi" "usename" "makeswap"
    )

    for var in "${required_vars[@]}"; do
        grep -q "^$var=" "$configfilepath"
        if [[ $? -eq 0 ]]; then
            value=$(grep "^$var=" "$configfilepath" | cut -d'=' -f2-)
            # Check if the value is empty
            if [ -z "$value" ]; then
                whiptail --title "Something went wrong" --msgbox "Variable $var in your config has no value. Please give it the acceptable value according to the template provided or the GitHub README." 0 0
                exit 1
            fi
        else
            whiptail --title "Something went wrong" --msgbox "You need variable $var in your config file. Please add it and give it the acceptable value according to the template provided or the GitHub README." 0 0
            exit 1
        fi
    done
}

checkconfigfile() {
    whiptail --title "Just a moment..." --infobox "We're reviewing your config file..." 8 35
    checkvars
    checkefi
    sleep 1
    checkrootpart
    sleep 1
    checkusername
    sleep 1
    checkpasswd $userpasswd
    sleep 1
    checkpasswd $rootpasswd
    sleep 1
    checkswap
    sleep 1
}

configfile() {
    configfilepath=$(whiptail --title "Preset configuration file" --inputbox "Enter the path to your configuration file.\n\nThere's a template included in the cloned repository named 'setup.conf'. If no valid file path is provided,\nthat will be the default." 0 0 3>&1 1>&2 2>&3)
    if [[ $? -eq 0 ]]; then
        if [[ ! -z "$configfilepath" && -f "$configfilepath" ]]; then
            source $configfilepath
            checkconfigfile
        elif [[ -z "$configfilepath"  ]]; then
            source $dir/setup.conf
            configfilepath="$dir/setup.conf"
            checkconfigfile
        elif [[ ! -f "$configfilepath" ]]; then
            whiptail --title "No configuration file" --yesno "We couldn't find a configuration file.\n\nWould you like to go through the process manually or exit the installer?" --yes-button "Proceed" --no-button "Exit" 0 0 3>&1 1>&2 2>&3
            if [[ $? -eq 0 ]]; then
                progress
            else
                exit 0
            fi
        fi
    else
        whiptail --title "No configuration file" --yesno "We couldn't find a configuration file.\n\nWould you like to go through the process manually or exit the installer?" --yes-button "Proceed" --no-button "Exit" 0 0 3>&1 1>&2 2>&3
        if [[ $? -eq 0 ]]; then
            progress
        else
            exit 0
        fi
    fi
}

progress() {

    whiptail --title "Step 1/6" --msgbox "First, let's select your partitions." --ok-button "Next" 0 5

    partition

    whiptail --title "Step 2/6" --msgbox "Next, let's select your Linux kernel." --ok-button "Next" 0 5

    kernel

    whiptail --title "Step 3/6" --msgbox "Next, let's have you set up your user." --ok-button "Next" 0 5

    createuser

    whiptail --title "Step 4/6" --msgbox "Next, let's set up the password for root." --ok-button "Next" 0 5

    setrootpasswd

    whiptail --title "Step 5/6" --msgbox "Next, let's configure your system." --ok-button "Next" 0 5

    configsys

    whiptail --title "Step 6/6" --msgbox "Next, let's choose a desktop environment." --ok-button "Next" 0 5

    desktop

}

installarch() {
    confirm=$(whiptail --title "Are you ready?" --nocancel --yesno "Are you ready to install Arch Linux?\n\nThere is no going back if you choose 'I'm ready.'" --defaultno --yes-button "I'm ready" --no-button "WAIT..." 0 0 3>&1 1>&2 2>&3; echo $?)
    if [[ $confirm -eq 0 ]]; then
        confirm=$(whiptail --title "Are you ready?" --nocancel --yesno "ARE YOU SURE?\n\nThere really is no going back." --defaultno --yes-button "I'm sure" --no-button "Never mind" 0 0 3>&1 1>&2 2>&3; echo $?)
        if [[ $confirm -eq 1 ]]; then
            whiptail --title "Going back" --msgbox "Never mind then.\n\nGood bye!" 0 5
            exit 0
        else
            {
                for ((i = 0 ; i <= 100 ; i+=1)); do
                    sleep 0.05
                    echo $i
                done
            } | whiptail --gauge "Installation will begin once this finishes...\n\nYou can see what's happening by typing Alt+F2 (the tty2 console)." 10 50 0
        fi
    else
        whiptail --title "Going back" --msgbox "Never mind then.\n\nGood bye!" 0 5
        exit 0
    fi

    whiptail --title "Ready!" --infobox "Here we go!" 8 35
	sleep 3

	if [[ "$formatefi" = true ]]; then
        whiptail --title "Partitioning" --infobox "Formatting the EFI System partition..." 8 35
		mkfs.fat -F 32 $efipart &> /dev/tty2
		sleep 2
	else
        whiptail --title "Partitioning" --infobox "The ESP has been untouched." 8 35
		sleep 2
	fi

    if [[ "$disklayout" = "lvm" ]]; then
		whiptail --title "LVM setup" --infobox "Creating physical volume $rootpart..." 8 35
		pvcreate $rootpart &> /dev/tty2
		sleep 1

		whiptail --title "LVM setup" --infobox "Creating volume group $vgname..." 8 35
		vgcreate $vgname $rootpart &> /dev/tty2
		sleep 1

		whiptail --title "LVM setup" --infobox "Creating logical volume $lvname" 8 35
		lvcreate -l 100%FREE $vgname -n $lvname &> /dev/tty2
		sleep 1

		whiptail --title "LVM setup" --infobox "Finishing LVM setup..." 8 35
		modprobe dm_mod
		vgchange -ay &> /dev/tty2
		sleep 1
		lvmpath=/dev/$vgname/$lvname

		whiptail --title "LVM setup" --infobox "Formatting & mounting $lvmpath..." 8 35
		mkfs.ext4 -q $lvmpath
		sleep 1
  		mount $lvmpath /mnt
		sleep 1

	elif [[ "$disklayout" = "basic" ]]; then
 		whiptail --title "Partitioning" --infobox "Formatting & mounting $rootpart..." 8 35
 		mkfs.ext4 -q $rootpart
   		mount $rootpart /mnt
		sleep 1
 	fi

    whiptail --title "Partitioning" --infobox "Mounting $efipart..." 8 35
 	mount --mkdir $efipart /mnt/boot/efi
 	sleep 1

 	pacstrap_pkgs=("base" "$linuxkernel" "$linuxkernel-headers" "linux-firmware" "base-devel" "zip" "unzip" "$cpumake-ucode" "networkmanager" "neovim" "wpa_supplicant" "wireless_tools" "netctl" "dialog" "bluez" "bluez-utils" "ntfs-3g" "grub" "efibootmgr" "mtools" "os-prober" "man-db" "pipewire" "lib32-pipewire" "wireplumber" "pipewire-pulse" "pipewire-alsa" "pipewire-jack" "lib32-pipewire-jack")

 	if [[ "$gpupkg" != "mesa" ]]; then
        pacstrap_pkgs+=("$gpupkg" "nvidia-utils" "lib32-nvidia-utils")
    else
        pacstrap_pkgs+=("mesa" "lib32-mesa")
	fi
	sleep 1

 	if [[ "$disklayout" = "lvm" ]]; then
        pacstrap_pkgs+=("lvm2")
  	fi

 	if [[ "$min_install" = false ]]; then
        pacstrap_pkgs+=(${desktop_pkgs[@]})
 	fi

    sleep 1

 	whiptail --title "Installing Arch Linux..." --infobox "Installing packages..." 8 35
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
	pacstrap /mnt ${pacstrap_pkgs[@]} &> /dev/tty2
	if [[ $? -ne 0 ]]; then
		whiptail --title "Something went wrong" --msgbox "Pacstrap couldn't install the packages.\n\nIt could be from corrupted pacman keys (run pacman-key --init)\nor another issue." 0 5
  		exit 10
  	fi

  	sleep 1

  	whiptail --title "Getting things ready..." --infobox "Preparing some stuff..." 8 35
	mkdir /mnt/install
 	cp $dir/installfiles/* /mnt/install/
 	genfstab -U /mnt >> /mnt/etc/fstab
    sleep 1

	sleep 1

	if [[ "$disklayout" = "lvm" ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Configuring the Linux initcpio..." 8 35
		cp -f /mnt/install/mkinit.conf /mnt/etc/mkinitcpio.conf
		arch-chroot /mnt mkinitcpio -P &> /dev/tty2
		sleep 1
  	fi

  	whiptail --title "Installing Arch Linux..." --infobox "Configuring the system..." 8 35
 	echo "$host" > /mnt/etc/hostname
	echo -e "127.0.0.1	localhost\n127.0.1.1	$host" > /mnt/etc/hosts
	arch-chroot /mnt ln -sf /usr/share/zoneinfo/$timezone /etc/localtime &> /dev/tty2
	arch-chroot /mnt hwclock --systohc &> /dev/tty2
	sed -i "s/#$locale UTF-8/$locale UTF-8/" /mnt/etc/locale.gen
	arch-chroot /mnt locale-gen &> /dev/tty2
	echo "LANG=$locale" > /mnt/etc/locale.conf
	sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
	arch-chroot /mnt pacman -Sy &> /dev/tty2
	sleep 1

    whiptail --title "Installing Arch Linux..." --infobox "Installing and configuring GRUB..." 8 35
    arch-chroot /mnt grub-install --target=x86_64-efi --bootloader-id=arch_grub --recheck &> /dev/tty2
	cp /mnt/usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /mnt/boot/grub/locale/en.mo
	sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER="false"/' /mnt/etc/default/grub
	arch-chroot /mnt grub-mkconfig --output=/boot/grub/grub.cfg &> /dev/tty2
	sleep 1

  	whiptail --title "Installing Arch Linux..." --infobox "Configuring users and passwords..." 8 35
   	if [[ "$usename" = "true" ]]; then
		arch-chroot /mnt useradd -m -g users -G wheel $username -c "$name"
	else
		arch-chroot /mnt useradd -m -g users -G wheel $username
	fi
	arch-chroot /mnt chpasswd <<<"$username:$userpasswd"
 	arch-chroot /mnt chpasswd <<<"root:$rootpasswd"
	sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /mnt/etc/sudoers
  	sleep 1


	whiptail --title "Installing Arch Linux..." --infobox "Enabling some systemd services..." 8 35
	arch-chroot /mnt systemctl enable NetworkManager &> /dev/tty2
	arch-chroot /mnt systemctl enable systemd-timesyncd &> /dev/tty2
    if [[ "$min_install" = false && "$displaymgr" != "xorg-xinit" ]]; then
        arch-chroot /mnt systemctl enable $displaymgr &> /dev/tty2
    fi

    sleep 1

    if [[ "$gpupkg" != "mesa" ]]; then
        whiptail --title "Installing Arch Linux..." --infobox "Configuring NVIDIA..." 8 35
        mkdir /mnt/etc/pacman.d/hooks
		cat <<NVIDIAHOOK > /mnt/etc/pacman.d/hooks/nvidia.hook
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
		sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"/' /mnt/etc/default/grub
		sed -i 's/^MODULES=()/MODULES=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)/' /mnt/etc/mkinitcpio.conf
		arch-chroot /mnt mkinitcpio -P &> /dev/tty2
		arch-chroot /mnt grub-mkconfig --output=/boot/grub/grub.cfg &> /dev/tty2
    fi

	sleep 1

	whiptail --title "Installing Arch Linux..." --infobox "Blacklisting the PC speaker..." 8 35
	echo -e "blacklist pcspkr\nblacklist snd_pcsp" > /mnt/etc/modprobe.d/nobeep.conf
	sleep 1

	if [[ "$makeswap" = true ]]; then
		whiptail --title "Installing Arch Linux..." --infobox "Configuring swap space..." 8 35
		arch-chroot /mnt mkswap -U clear --size $swapspace --file /swapfile &> /dev/tty2
		arch-chroot /mnt swapon /swapfile &> /dev/tty2
		echo '/swapfile none swap sw 0 0' | tee -a /mnt/etc/fstab
		arch-chroot /mnt mount -a
		arch-chroot /mnt swapon -a
		sleep 1
	fi

    rm -rf /mnt/install
}

start

if ! $useconfig; then
    progress
else
    configfile
fi
installarch
choice=$(whiptail --title "Installation complete" --nocancel --menu "Installation is now COMPLETE!\n\nWhat would you like to do now?" 20 80 10 \
		"1" "Return to Linux console" \
		"2" "Power off the system" \
		"3" "Reboot the system" \
		"4" "Chroot into installation" 3>&1 1>&2 2>&3)
case $choice in
	1) clear; exit 0 ;;
	2) poweroff ;;
	3) reboot ;;
	4) arch-chroot /mnt ;;
esac
