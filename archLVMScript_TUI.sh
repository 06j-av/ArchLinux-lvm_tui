#!/bin/bash

clear


welcomeText="Welcome to 06j-av's automated Arch Linux install script.

Ensure that you have made both your EFI partition and a 'Linux LVM' type 
partition.

This script is for 64-bit UEFI systems ONLY. LVM setup is included."
whiptail --title "Welcome to Arch Linux!" --msgbox "$welcomeText" 0 5

# Check if the user is running the script on a 64-bit UEFI system
if [[ "$(uname -m)" != "x86_64" && ! -e /sys/firmware/efi/fw_platform_size ]]; then
    whiptail --title "Error" --msgbox "Your system isn't using a 64-bit architecture AND not using UEFI firmware!" 0 5
    exit 2
elif [[ "$(uname -m)" != "x86_64" && -e /sys/firmware/efi/fw_platform_size ]]; then
    whiptail --title "Error" --msgbox "Your system isn't using a 64-bit architecture!" 0 5
    exit 2
elif [[ "$(uname -m)" = "x86_64" && ! -e /sys/firmware/efi/fw_platform_size ]]; then
    whiptail --title "Error" --msgbox "Your system isn't using UEFI firmware!" 0 5
    exit 2
else
    whiptail --title "Info" --msgbox "Great! You're system is compatible with this script!" 0 5
fi

# Get a list of partitions using the 'lsblk' command
partitions=$(lsblk -no NAME,FSTYPE,SIZE,PARTTYPENAME)

# Create a formatted string for input box display
input_text="Enter the EFI System Partition path:\n\n$partitions"

# Use whiptail to create an input box with partition list
efipart=$(whiptail --title "Partitioning" --nocancel --inputbox "$input_text" 0 0 3>&1 1>&2 2>&3)

# Ensure the ESP path provided is a device file & a partition
# if [[ -b "$efipart" && "$(lsblk -no TYPE "$efipart")" == "part" ]]
# then
# 	whiptail --title "Partition found" --msgbox "Found partition $efipart." 0 0
# else
#   	whiptail --title "Error" --msgbox "Couldn't find partition $efipart." 0 5

#     while [[ ! -b "$efipart" && "$(lsblk -no TYPE "$efipart")" != "part" ]]
#     do
#         efipart=$(whiptail --title "Try again." --nocancel --inputbox "$input_text" 0 0 3>&1 1>&2 2>&3)
#         if [[ ! -b "$efipart" && "$(lsblk -no TYPE "$efipart")" != "part" ]]
#         then
#             whiptail --title "Error" --msgbox "Couldn't find partition $efipart." 0 5
#         fi
#     done
#     whiptail --title "Partition found" --msgbox "Found partition $efipart." 0 0
# fi

echo "EFI System Partition path: $efipart"

formatText="Do you want to format $efipart?

Keep in mind, formatting will erase ALL data in $efipart, and is irreversible.

Choose WISELY."
whiptail --title "Partitioning" --yesno "$formatText" --defaultno --yes-button "Yes, format." --no-button "No, don't format." 0 0 3>&1 1>&2 2>&3
# 0 = format
# 1 = don't format
espprompt=$(echo $?)
echo $espprompt

# Get a list of partitions using the 'lsblk' command
partitions=$(lsblk -no NAME,FSTYPE,SIZE,PARTTYPENAME)

# Create a formatted string for input box display
input_text="You have chosen $efipart as your ESP.\n\nNow enter the root partition path:\n\n$partitions"

# Use whiptail to create an input box with partition list
rootpart=$(whiptail --title "Partitioning" --nocancel --inputbox "$input_text" 0 0 3>&1 1>&2 2>&3)

# Ensure the ESP path provided is a device file & a partition
# if [[ -b "$rootpart" && "$(lsblk -no TYPE "$rootpart")" == "part" ]]
# then
# 	whiptail --title "Partition found" --msgbox "Found partition $rootpart." 0 0
# else
#   	whiptail --title "Error" --msgbox "Couldn't find partition $rootpart." 0 5

#     while [[ ! -b "$rootpart" && "$(lsblk -no TYPE "$rootpart")" != "part" ]]
#     do
#         rootpart=$(whiptail --title "Try again." --nocancel --inputbox "$input_text" 0 0 3>&1 1>&2 2>&3)
#         if [[ ! -b "$rootpart" && "$(lsblk -no TYPE "$rootpart")" != "part" ]]
#         then
#             whiptail --title "Error" --msgbox "Couldn't find partition $rootpart." 0 5
#         fi
#     done
#     whiptail --title "Partition found" --msgbox "Found partition $rootpart." 0 0
# fi

if [[ $efipart == $rootpart ]]
then 
    whiptail --title "But wait!" --msgbox "The ESP and root partitions can't be the same!" 0 0
    echo "Error: EFI partition and root partition are the same. Aborting."
    exit 1
fi

echo "Root partition path: $rootpart"


if [[ $espprompt -eq '0' ]]
then
    partsummaryText="Your EFI partition is $efipart.
    
You want to format $efipart.
    
Your root partition is $rootpart.
    
Is this correct?"
else
    partsummaryText="Your EFI partition is $efipart.
    
You don't want to format $efipart.
    
Your root partition is $rootpart.
    
Is this correct?"
fi

whiptail --title "Just to confirm..." --yesno "$partsummaryText" --yes-button "Yes, continue." --no-button "No, abort." 0 0 3>&1 1>&2 2>&3
partconfirm=$(echo $?)
echo $partconfirm
if [[ $partconfirm -eq '1' ]]
then
    whiptail --title "Stopping..." --msgbox "If that's not correct, run the script again." 0 0
    exit 0
fi

whiptail --msgbox "Let's keep going. Time for some installation configurations." 0 0
username=$(whiptail --title "Username & passwords" --nocancel --inputbox "Enter a username:" 0 0 3>&1 1>&2 2>&3)
userpasswd=$(whiptail --passwordbox "Enter the password for $username:" 8 78 --title "Username & passwords" 3>&1 1>&2 2>&3)
rootpasswd=$(whiptail --title "Username & passwords" --nocancel --passwordbox "Enter the password for root:" 8 78 3>&1 1>&2 2>&3)

echo $username $userpasswd $rootpasswd

nameofhost=$(whiptail --title "Host configuration" --nocancel --inputbox "What's going to be this system's hostname?" 0 0 3>&1 1>&2 2>&3)
# Get the list of timezones
timezones=$(timedatectl list-timezones)

# Create an array from the list of timezones
timezones_array=()
while IFS= read -r line; do
    timezones_array+=("$line" "")
done <<< "$timezones"

timezoneText="What's your time zone?

You can use PgUp or PgDn to quickly scroll."
# Show the Whiptail menu and store the selected timezone
timezone=$(whiptail --title "Host configuration" --menu "$timezoneText" 20 60 10 "${timezones_array[@]}" 3>&1 1>&2 2>&3)

echo $nameofhost $timezone

vgname=$(whiptail --title "Host configuration" --nocancel --inputbox "Name the volume group:" 0 0 3>&1 1>&2 2>&3)
lvname=$(whiptail --title "Host configuration" --nocancel --inputbox "Name the root logical volume:" 0 0 3>&1 1>&2 2>&3)

echo $vgname $lvname

desktop=$(whiptail --title "Host configuration" --menu "What desktop environment + display manager do you want?" 25 78 16 3>&1 1>&2 2>&3 \
"KDE + SDDM" "Install KDE Plasma DE with the SDDM display manager" \
"i3 + ly" "Install i3 WM with the ly display manager" \
"Cinnamon + LightDM" "Install Cinnamon DE with the LightDM display manager" \
"Nothing" "Install nothing, minimal installation")
echo $desktop

swapText="How much swap space do you want?

This will be a file, not a partition."
swapspace=$(whiptail --title "Host configuration" --menu "$swapText" 25 78 16 3>&1 1>&2 2>&3 \
"N/A" "No swap file" \
"2G" "2G swap file" \
"4G" "4G swap file" \
"8G" "8G swap file")
echo $swapspace

cpumake=$(whiptail --title "Host configuration" --yesno "Are you using an Intel or an AMD CPU?" --yes-button "Intel CPU" --no-button "AMD CPU" 0 0 3>&1 1>&2 2>&3; echo $?)
echo $cpumake

nvidiayn=$(whiptail --title "Host configuration" --yesno "Are you using an NVIDIA GPU?" 0 0 3>&1 1>&2 2>&3; echo $?)
echo $nvidiayn

if [[ $nvidiayn -eq '0' ]]
then
    nvidiatypeText="According to the Arch Wiki...
    
    For the Maxwell (NV110/GMXXX) series and newer, install the 'nvidia' package
    Alternatively for the Turing (NV160/TUXXX) series or newer the 'nvidia-open' package may be installed for open source kernel modules on the linux kernel
    
    Which package fits best for your NVIDIA graphics card?"
    nvidiatype=$(whiptail --title "Host configuration" --yesno "$nvidiatypeText" --yes-button "nvidia" --no-button "nvidia-open" 0 0 3>&1 1>&2 2>&3; echo $?)
    echo $nvidiatype
    if [[ $nvidiatype -eq '0' ]]
    then
        nvidiause="You are using an NVIDIA GPU and want to install the nvidia package."
        gpushortsum="GPU: NVIDIA (using nvidia)"
    else
        nvidiause="You are using an NVIDIA GPU and want to install the nvidia-open package."
        gpushortsum="GPU: NVIDIA (using nvidia-open)"
    fi
else
    nvidiause="You are not using an NVIDIA GPU."
    gpushortsum="GPU: Not NVIDIA (using mesa)"
fi

# Variables:
# Desktop environment
# Swap file size
# NVIDIA GPU
# NVIDIA GPU packages

if [[ "$desktop" = "KDE + SDDM" ]]
then
	desktopsummary="You want to use KDE Plasma with SDDM."
    desktopshortsum="DE + DM: KDE Plasma & SDDM"
elif [[ "$desktop" = "i3 + ly" ]]
then
	desktopsummary="You want to use i3 with ly."
    desktopshortsum="WM + DM: i3 & ly"
elif [[ "$desktop" = "Cinnamon + LightDM" ]]
then
	desktopsummary="You want to use Cinnamon with LightDM."
    desktopshortsum="DE + DM: Cinnamon & LightDM"
elif [[ "$desktop" = "Nothing" ]]
then
	desktopsummary="You only want to begin at the console."
    desktopshortsum="DE + DM: N/A"
fi

if [[ "$swapspace" = "N/A" ]]
then
    swapsummary="You don't want a swap file."
    swapshortsum="Swap size: N/A"
else
    swapsummary="You want a $swapspace swap file."
    swapshortsum="Swap size: $swapspace"
fi

configsummaryText="Your username will be $username.
The system hostname will be $nameofhost.
Your timezone is $timezone.
$desktopsummary
$swapsummary
$nvidiause
Is this correct?"

configconfirm=$(whiptail --title "Just to confirm..." --yesno "$configsummaryText" --yes-button "Yes, continue." --no-button "No, abort." 0 0 3>&1 1>&2 2>&3; echo $?)
echo $configconfirm
if [[ $configconfirm -eq '1' ]]
then
    whiptail --title "Stopping..." --msgbox "If that's not correct, run the script again." 0 0
    exit 0
fi

if [[ $espprompt -eq '0' ]]
then
    partshortsum="PARTITIONING:
ESP path: $efipart
Root path: $rootpart
$efipart WILL be formatted.
LVM path: /dev/$vgname/$lvname"
else
    partshortsum="PARTITIONING:
ESP path: $efipart
Root path: $rootpart
$efipart WILL NOT be formatted.
LVM path: /dev/$vgname/$lvname"
fi

if [[ $cpumake -eq '0' ]]
then
    cpushortsum="CPU: Intel
intel-ucode will be installed."
else
    cpushortsum="CPU: AMD
amd-ucode will be installed."
fi

finalconfirmText="Here are all of your configurations:
$partshortsum
HOST CONFIGURATIONS:
Username: $username
Hostname: $nameofhost
Time zone: $timezone
$desktopshortsum
$swapshortsum
$cpushortsum
$gpushortsum

ARE YOU SURE YOU WANT TO PROCEED WITH INSTALLATION?

If you do, there's no going back.
Not even kidding. You can't Ctrl + C out of this if you agree to installation."

finalconfirm=$(whiptail --title "WARNING:" --yesno "$finalconfirmText" --yes-button "Yes, install." --no-button "No, abort." 0 0 3>&1 1>&2 2>&3; echo $?)
echo $finalconfirm
if [[ $finalconfirm -eq '1' ]]
then
    whiptail --title "Stopping..." --msgbox "If you've changed your mind, run this script again. See you next time!." 0 0
    exit 0
else
    finalconfirmAgain=$(whiptail --title "FINAL WARNING:" --yesno "Once again, ARE YOU SURE that you want to proceed with installation?" --yes-button "Proceed" --no-button "I changed my mind" 0 0 3>&1 1>&2 2>&3; echo $?)
    if [[ $finalconfirmAgain -eq '1' ]]
    then
        whiptail --title "Stopping..." --msgbox "If you've changed your mind, run this script again. See you next time!" 0 0
        exit 0
    fi
fi

{
    for ((i = 0 ; i <= 100 ; i+=1)); do
        sleep 0.1
        echo $i
    done
} | whiptail --gauge "Installation will begin once this progress bar finishes..." 6 50 0