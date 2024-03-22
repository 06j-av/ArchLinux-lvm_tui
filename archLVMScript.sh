#!/bin/bash

clear
# Just a nice little introduction :3
echo "----------------------------------------------------------------------------"
echo " Welcome to 06j-av's automated Arch Linux install script."
echo -e " Ensure that you have made both your root partition (ensure the type is \n 'Linux LVM') and your EFI partition. "
echo " This script is for 64-bit UEFI systems ONLY. "
echo " LVM setup is included. "
echo "----------------------------------------------------------------------------"

echo "First, you'll need to provide some information"
echo "before we start to install Arch for you."
sleep 2

# Ask the user for their EFI System Partition (ESP)
echo -e "\nWhat's the path to your EFI System Partition?"
echo "This is usually the first partition on the target drive."
echo -e "ex. /dev/sda1 or /dev/nvme0n1p1\n"
read -p "ESP path: " efipart

# Ensure the ESP path provided is a device file and a partition
if [[ -b "$efipart" && "$(lsblk -no TYPE "$efipart")" == "part" ]]; then
	echo "Found $efipart!"
else
	echo "Error: Invalid ESP path."
  	exit 1
fi

# Prompts the user if they basically want to format the ESP
echo -e "\nDo you want to format $efipart?"
echo "If $efipart is formatted, everything (including EFI entries) in the ESP will be erased, so CHOOSE WISELY."
read -p "(1. Don't format $efipart.) (2. Format $efipart.) " efientry

if [ $efientry -ne '1' ] && [ $efientry -ne '2' ]
then
	echo "Invalid response."
	echo "Aborting."
	exit 1
fi

# Ask the user for their root partition
echo -e "\nWhat's the path to the root (/) partition?"
echo "This is where Arch will be installed."
echo -e "ex. /dev/sda2 or /dev/nvme0n1p3\n"
read -p "Root path: " rootpart

# If the ESP and the root partition are the same, abort
if [ "$efipart" = "$rootpart" ]
then
	echo "The ESP partition and root partition cannot be the same."
	echo "Aborting."
	exit 2
fi

# Ensure the root path provided is a device file and a partition
if [[ -b "$rootpart" && "$(lsblk -no TYPE "$rootpart")" == "part" ]]; then
	echo "Found $rootpart!"
else
	echo "Error: Invalid root path."
	exit 1
fi

# Summarize the inputs so far
echo -e "\nJust to confirm..."
sleep 2
echo "Your EFI system partition is $efipart."
if [ $efientry -eq '1' ] 
then
	echo "You want to keep your existing EFI entries."
else	echo "You want to format $efipart."
fi
echo "And your root partition is $rootpart."
sleep 1
read -p "Is this correct? (y/n) " partconfirm

if [ "$partconfirm" = "y" ]
then
	echo "Let's keep going."
else	echo "Aborting."
		exit 1
fi

sleep 1
echo -e "\nLet's configure some stuff."
echo ''
# Prompt the user for their username, hostname, and time zone.
# The user will enter the root and user passwords during installation.
read -p "What will be your username? " username
read -sp "Enter the password for $username: " userpasswd
echo ''
read -sp "Enter the password for root: " rootpasswd
echo ''
read -p "Enter your preferred hostname: " nameofhost
echo -e "What's your time zone?"
read -p "They usually follow the Region/City format, like 'America/Los_Angeles'. " timezone

# Check if the time zone is valid.
if [ -e /usr/share/zoneinfo/$timezone ]; then
	echo -e "\nFound the timezone $timezone!"
else
	echo "Time zone not found."
	echo "Aborting."
	exit 1
fi

# Prompt the user for the labels for the volume group and logical volume.
read -p "Enter the name for the volume group: " vgname
read -p "Enter the name for the logical volume: " lvname

# Prompt the user for their preferred desktop environment and display manager (if any)
echo -e "\nWhat desktop environment + display manager would you like to use?"
read -p "(1. KDE + SDDM) (2. i3 + ly) (3. Cinnamon + LightDM) (4. Nothing/Minimal installation) " desktop

# This is to ensure the input is what is expected. If not then abort
if [ $desktop -ne '1' ] && [ $desktop -ne '2' ] && [ $desktop -ne '3' ] && [ $desktop -ne '4' ]
then
	echo "Invalid response."
	echo "Aborting."
	exit 1
fi

echo -e "\nHow much swap do you want? \nThis will be a file, not a partition."
read -p "(1. No swap) (2. 2G swap) (3. 4G swap) (4. 8G swap) " swapspace

# This is to ensure the input is what is expected. If not then abort
if [ $swapspace -ne '1' ] && [ $swapspace -ne '2' ] && [ $swapspace -ne '3' ] && [ $swapspace -ne '4' ]
then
	echo "Invalid response."
	echo "Aborting."
	exit 1
fi

echo -e "\nAre you using an Intel or AMD CPU?"
read -p "(1. Intel) (2. AMD) " cpumake

# This is to ensure the input is what is expected. If not then abort
if [ $cpumake -ne '1' ] && [ $cpumake -ne '2' ]
then
	echo "Invalid response."
	echo "Aborting."
	exit 1
fi

read -p "Are you using an NVIDIA GPU? (y/n) " nvidiayn

# This is to ensure the input is what is expected. If not then abort
if [ "$nvidiayn" != 'y' ] && [ "$nvidiayn" != 'n' ]
then
	echo "Invalid response."
	echo "Aborting."
	exit 1
fi

if [ "$nvidiayn" = "y" ]; then
	# As Arch Linux has different NVIDIA drivers
 	echo "Take a look at your NVIDIA GPU series. Choose the NVIDIA package that is recommended for your GPU series. "
  	echo "According to the Arch Wiki..."
   	echo "For the Maxwell (NV110/GMXXX) series and newer, install the 'nvidia' package"
    	echo "Alternatively for the Turing (NV160/TUXXX) series or newer the 'nvidia-open' package may be installed for open source kernel modules on the linux kernel"
	read -p "(1. nvidia) (2. nvidia-open) " nvidiatype
	
 	# This is to ensure the input is what is expected. If not then abort
	if [ $nvidiatype -ne '1' ] && [ $nvidiatype -ne '2' ]
	then
		echo "Invalid response."
		echo "Aborting."
		exit 1
	fi
fi

# Summarize the configurations so far.
echo -e "\nLet's confirm your configurations."

sleep 1

echo "Your username is $username."

echo "The hostname will be $nameofhost."

echo "Your timezone is $timezone."

echo "The path to your LVM root volume will be /dev/$vgname/$lvname."

if [ $desktop -eq '1' ]
then
	echo "You want to use KDE Plasma with SDDM."
elif [ $desktop -eq '2' ]
then
	echo "You want to use i3 with ly."
elif [ $desktop -eq '3' ]
then
	echo "You want to use Cinnamon with LightDM."
elif [ $desktop -eq '4' ]
then
	echo "You only want to begin at the console."
fi


if [ $swapspace -eq '1' ]
then
	echo "You don't want a swap file."
elif [ $swapspace -eq '2' ]
then
	echo "You want a 2G swap file."
elif [ $swapspace -eq '3' ]
then
	echo "You want a 4G swap file."
elif [ $swapspace -eq '4' ]
then
	echo "You want a 8G swap file."
fi
if [ $cpumake -eq '1' ]
then
	echo "You are using an Intel CPU."
elif [ $cpumake -eq '2' ]
then
	echo "You are using an AMD CPU."
fi

if [ "$nvidiayn" = "y" ]  && [ $nvidiatype -eq '1' ]
then
	echo "And you are using an NVIDIA GPU and want to install the nvidia package."
elif [ "$nvidiayn" = "y" ]  && [ $nvidiatype -eq '1' ]
then
	echo "And you are using an NVIDIA GPU and want to install the nvidia-open package."
elif [ "$nvidiayn" = "n" ]
then
	echo "And you are not using an NVIDIA GPU."
fi

sleep 1

read -p "Is this correct? (y/n) " configconfirm

# Summarize the partitioning and installation configurations.
return_configurations() {

	echo '===== PARTITIONING & FORMATTING ====='
	echo "EFI System Partition path: $efipart"
	echo "Root partition path: $rootpart"
	if [ $efientry -eq '1' ] 
	then
		echo "$efipart will NOT be formatted."
	elif [ $efientry -eq '2' ]
	then
		echo "$efipart WILL be formatted."
	fi

	echo "$rootpart WILL be formatted."

	echo -e '\n===== CONFIGURATIONS ====='
	echo "Initial user: $username"
	if [ $desktop -eq '1' ]
	then
		echo "Desktop environment: KDE Plasma"
		echo "Display manager: SDDM"
	elif [ $desktop -eq '2' ]
	then
		echo "Desktop environment: i3 window manager"
		echo "Display manager: ly"
	elif [ $desktop -eq '3' ]
	then
		echo "Desktop environment: Cinnamon"
		echo "Display manager: LightDM"
	elif [ $desktop -eq '4' ]
	then
		echo "Minimal installation"
  		echo "You will begin at the Linux console after reboot."
	fi

  	echo "System hostname: $nameofhost"
   	echo "System timezone: $timezone"


	if [ $swapspace -eq '1' ]
	then
		echo "Swap file size: N/A"
	elif [ $swapspace -eq '2' ]
	then
		echo "Swap file size: 2G"
	elif [ $swapspace -eq '3' ]
	then
		echo "Swap file size 4G"
	elif [ $swapspace -eq '4' ]
	then
		echo "Swap file size: 8G"
	fi
	echo -e '\n===== HARDWARE ====='
	if [ $cpumake -eq '1' ]
	then
		echo "CPU: Intel"
  		echo "intel-ucode will be installed."
	elif [ $cpumake -eq '2' ]
		then
		echo "CPU: AMD"
		echo "amd-ucode will be installed."
	fi

	
	if [ "$nvidiayn" = "y" ] && [ $nvidiatype -eq '1' ]
	then
		echo "GPU: NVIDIA GPU (using nvidia)."
		echo "The nvidia package will be installed."
	elif [ "$nvidiayn" = "y" ]  && [ $nvidiatype -eq '2' ]
	then
		echo "GPU: NVIDIA GPU (using nvidia-open)."
		echo "The nvidia-open package will be installed."
	elif [ "$nvidiayn" = "n" ]
	then
		echo "GPU: Other GPU (using mesa)"
	fi
}

# Ensure the user actually wants to proceed.
if [ "$configconfirm" = "y" ]
then
	clear
	return_configurations
	echo -e "\nARE YOU SURE YOU WANT TO PROCEED?"
	read -p "PLEASE be sure. After this, there's no going back (at least at this moment). (y/n) " begininstallconfirm
	if [ "$begininstallconfirm" = "y" ]
	then
		echo "Here we go!"
	else	
			echo "Aborting."
			exit 1
	fi
else	
		echo "Aborting."
		exit 1
fi


sleep 1

echo "Beginning Arch Linux installation in..."
sleep 1
echo "5..."
sleep 1
echo "4..."
sleep 1
echo "3..."
sleep 1
echo "2..."
sleep 1
echo "1..."
sleep 1
echo 'Here we go!'
sleep 1

clear

echo "-----------------------------------------"
echo "PARTITIONING & LVM SETUP"
echo "-----------------------------------------"
sleep 1

# Format the ESP if requested.
if [ $efientry -eq '2' ]
then
	echo "You have chosen to format the EFI System Partition."
	echo "Formatting..."
	mkfs.fat -F 32 $efipart
elif [ $efientry -eq '1' ]
then
	echo "Don't worry. Your EFI partition has been untouched."
fi

sleep 1
# Set up the physical volume, volume group, and logical volume.
echo "Setting up LVM..."
echo -e "Creating physical volume...\n"
pvcreate $rootpart
echo -e "\nCreating volume group $vgname...\n"
vgcreate $vgname $rootpart


echo -e "\nCreating root logical volume $lvname...\n"
lvcreate -l 100%FREE $vgname -n $lvname

modprobe dm_mod
vgchange -ay

lvmpath=/dev/$vgname/$lvname

echo -e "\nFormatting $lvmpath... \n"
mkfs.ext4 $lvmpath

sleep 1

# Mount the file systems and build the fstab file.
echo -e "\nMounting the file systems...\n"
mount $lvmpath /mnt
mount --mkdir $efipart /mnt/boot/efi

sleep 1

echo -e "\nBuilding fstab file...\n"
mkdir /mnt/etc
genfstab -U /mnt >> /mnt/etc/fstab

sleep 1

echo -e "\nInstalling the base package...\n"
pacstrap /mnt base --noconfirm --needed

sleep 1

# Store the mkinitcpio files in the repository into a directory at the root level of the new installation.
# This will be removed at the end of the installation.
mkdir -v /mnt/installScript-files

cat <<REALEND > /mnt/installScript-files/archInstall.sh
clear
echo "-----------------------------------------"
echo "INSTALLATION"
echo "-----------------------------------------"
sleep 1

# Install some tools, including the linux kernel

echo -e "\nInstalling the linux kernel & essential tools ...\n"
pacman -S linux linux-firmware linux-headers base-devel lvm2 git neofetch zip unzip --noconfirm --needed
echo -e "\nInstalling the nvim terminal text editor...\n"
pacman -S neovim --noconfirm --needed
echo -e "\nInstalling networking tools...\n"
pacman -S networkmanager wpa_supplicant wireless_tools netctl dialog bluez bluez-utils --noconfirm --needed
echo -e "\nEnabling Network Manager...\n"
systemctl enable NetworkManager
echo -e "\nConfiguring the linux initcpio...\n"
cp -f /installScript-files/mkinitcpio_withlvm.conf /etc/mkinitcpio.conf
mkinitcpio -P linux
sleep 1

# Configure the locale

echo -e "\nConfiguring the locale to US English UTF-8...\n"
sed -i 's/#en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
locale-gen
echo 'LANG=en_US.UTF-8' > /etc/locale.conf
sleep 1

clear
echo "-----------------------------------------"
echo "Root and user setup"
echo "-----------------------------------------"

# Set the passwords for the user and root

echo -e "\nSetting the root password...\n"
echo '$rootpasswd' | passwd --stdin root
sleep 1
echo -e "\nCreating user $username...\n"
useradd -m -g users -G wheel $username
sleep 1
echo -e "\nSetting the password for $username...\n"
echo '$userpasswd' | passwd --stdin $username
sleep 1

# Edit the sudoers file ensuring that people in the wheel group can use sudo.

echo -e "\nConfiguring sudoers...\n"
sed -i 's/^# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/' /etc/sudoers
sleep 1

clear
echo "-----------------------------------------"
echo "GRUB installation"
echo "-----------------------------------------"

# Install GRUB and configure it.

echo -e "\nInstalling the GRUB bootloader...\n"
pacman -S grub dosfstools os-prober mtools efibootmgr --noconfirm --needed
grub-install --target=x86_64-efi --bootloader-id=grub_uefi --recheck
if [ -d /boot/grub/locale ]; then
	echo "Copying the locale for GRUB..."
	cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
	echo "Making the GRUB configuration..."
 	sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER="false"/' /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg
else
	echo "Making the /boot/grub/locale directory..."
	mkdir /boot/grub/locale
	echo "Copying the locale for GRUB..."
	cp /usr/share/locale/en\@quot/LC_MESSAGES/grub.mo /boot/grub/locale/en.mo
  	sed -i 's/^#GRUB_DISABLE_OS_PROBER=false/GRUB_DISABLE_OS_PROBER="false"/' /etc/default/grub
	grub-mkconfig -o /boot/grub/grub.cfg
fi
sleep 1

clear
echo "-----------------------------------------"
echo "Swap file setup"
echo "-----------------------------------------"

# Make the swap file.

if [ $swapspace -ne '1' ]
then	
	echo -e "\nBuilding swap file...\n"
	if [ $swapspace -eq '2' ]
	then
		dd if=/dev/zero of=/swapfile bs=1G count=2 status=progress
		chmod 600 /swapfile
		mkswap -U clear /swapfile
		echo -e "\nMaking a fstab backup...\n"
		cp /etc/fstab /etc/fstab.bak
		echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
		mount -a
		swapon -a
	elif [ $swapspace -eq '3' ]
	then
		dd if=/dev/zero of=/swapfile bs=1G count=4 status=progress
		chmod 600 /swapfile
		mkswap -U clear /swapfile
		echo -e "\nMaking a fstab backup...\n"
		cp /etc/fstab /etc/fstab.bak
		echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
		mount -a
		swapon -a
	elif [ $swapspace -eq '4' ]
	then
		dd if=/dev/zero of=/swapfile bs=1G count=8 status=progress
		chmod 600 /swapfile
		mkswap -U clear /swapfile
		echo -e "\nMaking a fstab backup...\n"
		cp /etc/fstab /etc/fstab.bak
		echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
		mount -a
		swapon -a
	fi
else
	echo "A swap file will not be made, per your request."
fi
sleep 1

clear
echo "-----------------------------------------"
echo "Almost there..."
echo "-----------------------------------------"

# Set the hostname and time zone.

echo -e "\nSetting the hostname...\n"
echo "$nameofhost" > /etc/hostname
echo -e "127.0.0.1	localhost\n127.0.1.1	$nameofhost" > /etc/hostsecho -e "\nSetting the timezone...\n"
ln -sf /usr/share/zoneinfo/$timezone /etc/localtime
systemctl enable systemd-timesyncd
sleep 1

# Add the multilib repository

echo -e "\nEnabling the multilib repository...\n"
echo -e "[multilib]\nInclude = /etc/pacman.d/mirrorlist" >> /etc/pacman.conf
pacman -Sy
sleep 1

# Install the CPU microcodes and regenerate the GRUB config

if [ $cpumake -eq '1' ]
then
	echo -e "\nInstalling the Intel microcode...\n"
	pacman -S intel-ucode --noconfirm --needed
elif [ $cpumake -eq '2' ]
then
	echo -e "\nInstalling the AMD microcode...\n"
	pacman -S amd-ucode --noconfirm --needed
fi
grub-mkconfig -o /boot/grub/grub.cfg
sleep 1

# Install NVIDIA if the user has an NVIDIA GPU

if [ "$nvidiayn" = "y" ]
then
	echo -e "\nNVIDIA time.\n"
	sleep 0.5
 	mkdir /etc/pacman.d/hooks
	if [ $nvidiatype -eq '1' ]
	then
		echo -e '\nInstalling the nvidia package...\n'
		pacman -S nvidia nvidia-utils --noconfirm --needed
  		echo -e '\nCreating pacman hook for nvidia...\n'
    		cp /installScript-files/nvidia-hook.hook /etc/pacman.d/hooks/nvidia.hook
	elif [ $nvidiatype -eq '2' ]
	then
		echo -e "\nInstalling the nvidia-open package...\n"
		pacman -S nvidia-open nvidia-utils --noconfirm --needed
  		echo -e '\nCreating pacman hook for nvidia-open...\n'
    		cp /installScript-files/nvidia-open-hook.hook /etc/pacman.d/hooks/nvidia.hook
	fi
 	echo -e "\nUpdating the linux initramfs...\n"
	cp -f /installScript-files/mkinitcpio_withnvidia.conf /etc/mkinitcpio.conf
 	sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet nvidia_drm.modeset=1"/' /etc/default/grub
 	mkinitcpio -P linux
  	grub-mkconfig -o /boot/grub/grub.cfg
   
elif [ "$nvidiayn" = "n" ]
then
	echo -e "\nInstalling the mesa package...\n"
	pacman -S mesa --noconfirm --needed
fi
sleep 1

# Install PipeWire audio drivers
echo -e "\nInstalling PipeWire...\n"
pacman -S pipewire lib32-pipewire wireplumber pipewire-pulse pipewire-alsa pipewire-jack lib32-pipewire-jack --noconfirm --needed

# Install the preferred desktop environment and its companion display manager (if chosen to do so)

if [ $desktop -eq '1' ]
then
	echo -e "\nInstalling KDE Plasma with SDDM...\n"
	pacman -S xorg plasma sddm alacritty dolphin --noconfirm --needed
	systemctl enable sddm
elif [ $desktop -eq '2' ]
then
	echo -e "\nInstalling i3 with ly...\n"
	pacman -S xorg i3 ly alacritty nitrogen ranger --noconfirm --needed
	systemctl enable ly
elif [ $desktop -eq '3' ]
then
	echo -e "\nInstalling Cinnamon with LightDM...\n"
	pacman -S xorg lightdm lightdm-gtk-greeter cinnamon metacity alacritty --noconfirm --needed
	systemctl enable lightdm
elif [ $desktop -eq '4' ]
then
	echo "No desktop environment and display manager will be installed."
fi

# Remove the ANNOYING PC speaker module from the kernel
echo -e "\nLastly... blacklisting the PC speaker module\n"
echo -e "blacklist pcspkr\nblacklist snd_pcsp" > /etc/modprobe.d/nobeep.conf

sleep 1

echo -e '\nClearing the pacman cache...\n'
pacman -Scc --noconfirm
rm -f /var/cache/pacman/pkg/*

clear
echo "Installation is COMPLETE. "
echo "We'll leave it to you to either do some more configurations or reboot to your new Arch system."
echo "To reboot, run these commands in order:"
echo -e "umount -R /mnt\nreboot"
echo "To do some more configurations, run:"
echo "arch-chroot /mnt"
exit 0

REALEND

cp -v /root/archlinux-installScript-LVM/mkinitcpio_withlvm.conf /mnt/installScript-files/
cp -v /root/archlinux-installScript-LVM/mkinitcpio_withnvidia.conf /mnt/installScript-files/
cp -v /root/archlinux-installScript-LVM/nvidia-open-hook.hook /mnt/installScript-files/
cp -v /root/archlinux-installScript-LVM/nvidia-hook.hook /mnt/installScript-files/

sleep 3

arch-chroot /mnt /bin/bash installScript-files/archInstall.sh
rm -rf /mnt/installScript-files
