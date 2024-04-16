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
	main
}

kernelconfig() {
	linuxkernel=$(whiptail --title "Select a kernel" --menu "Choose the kernel that you want to install." 20 60 4 3>&1 1>&2 2>&3 \
 	"linux" "The vanilla Linux kernel and modules" \
  	"linux-hardened" "A security-focused Linux kernel" \
   	"linux-lts" "Long-term (LTS) Linux kernel" \
      	"linux-zen" "Made by kernel hackers for the best kernel possible")
       	kernelmenu="$linuxkernel"
}

userconfig() {
	username=$(whiptail --title "Username & password" --nocancel --inputbox "Enter a username:" 0 0 3>&1 1>&2 2>&3)
	userpasswd=$(whiptail --passwordbox "Enter the password for $username:" 8 78 --title "Username & password" 3>&1 1>&2 2>&3)
	usermenu="Username: $username"
	main
}

rootconfig() {
	rootpasswd=$(whiptail --title "Root password" --nocancel --passwordbox "Enter the password for root:" 8 78 3>&1 1>&2 2>&3)
	rootpassmenu="Root password set."
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
	timezone=$(whiptail --title "Host configuration" --menu "What's your time zone?\n\nYou can use PgUp or PgDn to quickly scroll." 20 60 10 "${timezones_array[@]}" 3>&1 1>&2 2>&3)

	# Get the list of locales
	locales=$(cat /usr/share/i18n/SUPPORTED)

	# Create an array from the list of locales
	locales_array=()
	while IFS= read -r line; do
	    locales_array+=("$line" "")
	done <<< "$locales"
	# Show the Whiptail menu and store the selected timezone
	locale=$(whiptail --title "Host configuration" --menu "What's your locale?\n\nYou can use PgUp or PgDn to quickly scroll." 20 60 10 "${locales_array[@]}" 3>&1 1>&2 2>&3)
	hostmenu="Hostname: $nameofhost; Time zone: $timezone; Locale: $locale"
	main
}

hwconfig() {
	cpumake=$(whiptail --title "Hardware" --radiolist "Select your CPU make:" 0 0 2 \
		"AMD" "You have an AMD CPU." ON \
		"Intel" "You have an Intel CPU." OFF 3>&1 1>&2 2>&3)
	gputype=$(whiptail --title "Hardware" --radiolist "What's your GPU?" 0 0 4 \
		"NVIDIA" "NVIDIA with nvidia package" ON \
		"NVIDIA (open)" "NVIDIA with nvidia-open package" OFF \
		"Other" "Other GPU using the mesa package" OFF)
	hardwaremenu="CPU: $cpumake; GPU: $gputype"
	main
}

swapconfig() {
	swapspace=$(whiptail --title "Swap space" --menu "How much swap space do you want?\n\nThis will be a file, not a partition." 25 78 16 3>&1 1>&2 2>&3 \
	"N/A" "No swap file" \
	"2G" "2G swap file" \
	"4G" "4G swap file" \
	"8G" "8G swap file")
	if [[ "$swapspace" = "N/A" ]]; then
		swapmenu="No swap space"
	else
		swapmenu="Swap space: $swapspace sized file"
	fi
}

desktopconfig() {
	desktop=$(whiptail --title "Desktop environment" --menu "What desktop environment do you want?" 25 78 8 3>&1 1>&2 2>&3 \
	"budgie" "Install the Budgie desktop environment" \
	"cinnamon" "Install the Cinnamon desktop environment" \
	"deepin" "Install the Deepin desktop environment" \
	"gnome" "Install the GNOME desktop environment" \
	"lxde" "Install the LXDE (with GTK 2) desktop environment" \
	"lxde-gtk3" "Install the LXDE (with GTK 3) desktop environment" \
	"Ixqt" "Install the LXQt desktop environment" \
	"mate" "Install the MATE desktop environment" \
	"plasma" "Install the KDE Plasma desktop environment" \
	"xfce4" "Install the Xfce desktop environment" \
	"awesome" "Install the awesome window manager" \
	"bspwm" "Install the Bspwm window manager" \
	"i3" "Install the i3 window manager" \
	"sway" "Install the Sway window manager" \
	"No DE" "Install nothing, minimal installation")
	if [[ "$desktop" != "No DE" ]]; then	
		displaymgr=$(whiptail --title "Display manager" --menu "What display manager do you want?" 25 78 8 3>&1 1>&2 2>&3 \
				
		"No DM" "Don't install a display manager")
		demenu="$desktop + $displaymgr"
	else
		demenu="$desktop"
	fi
	main
}

# Set the menu choices to the default
partmenu="Select partitions... (not set)"
kernelmenu="Select a kernel..."
usermenu="Create a user and a password..."
rootpassmenu="Set a root password..."
hostmenu="Configure the host..."
hardwaremenu="Tell us your hardware..."
demenu="Select a desktop environment..."
swapmenu="Set swap space..."

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
        #desktopconfig
        ;;
    9)
        #installArch
        ;;
    *)
        exit 0
        ;;
esac
}

main
