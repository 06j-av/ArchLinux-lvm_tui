# Arch Linux Installation with LVM Setup (Terminal User Interface)

This script automates the installation process of Arch Linux with Logical Volume Management (LVM) and uses a terminal user interface with `whiptail`. It is designed to make the installation steps more simpler for incoming Arch Linux users.

This is a **Terminal User Interface** variant of the [text-based installer](https://github.com/06j-av/archlinux-installScript-LVM) that I likely will not even touch anymore because this one is much better than the other one (at least in my opinion).

## Some stuff you need to know
- This script is **still in development**. It is only public so I can test this in a virtual machine :p
- Don't run anything in the 'newinstaller/' directory in this repository. I just didn't make a branch for the next update to this installer and just slapped an **UNFINISHED** updated script in a folder.
- This script will only make __one__ user.
   - You'll have to add extra users yourself when you reboot into the installation.
- This script will only have options for kernel (`linux` and `linux-lts`), and installs `alacritty` as the default terminal emulator.

## Things you'll need

- **Arch Linux ISO**: Download the latest Arch Linux ISO from the [official website](https://archlinux.org/download/).
- **Bootable USB Drive**: Create a bootable USB drive with the Arch ISO using your preferred tools.
- **Internet Connection**: Ensure that your system has a **stable** internet connection for downloading packages during the installation process.

## Usage

1. **Boot from USB**: Insert the bootable USB drive into your system, boot from it, and get yourself a great internet connection with Ethernet or a wireless connection with `iwctl`. (obviously)

2. **Prepare Disk**:
   - Ensure that you create an EFI System Partition (ESP) and a partition with the type set as "Linux LVM". You can confirm these actions using:
    ```
    lsblk -o NAME,PARTTYPENAME
    ```


3. **Run some pacman commands**:
   - You'll need to run some pacman commands to ensure that the installation process goes smooth.
     ```
     pacman -S git
     ```
    
4. **Clone this repository**:
   - Clone the repository to the Arch ISO environment using:
     ```
     git clone https://github.com/06j-av/ArchLinux-lvm_tui
     ```

5. **Run the Script**:
   - Run the script. You shouldn't need to make the script executable, but if you need to, run `chmod +x setup.sh`.
     ```
     ./setup.sh
     ```

6. **Follow the On-Screen Instructions**:
   - Follow the prompts and provide necessary inputs as requested by the script.

7. **Reboot**:
   - Once the installation is complete, reboot your system and remove the USB drive, and if everything went well, you can say "hello" to your new Arch Linux system.

## Next steps
This can be seen in the `newinstaller/` directory on this repository.

- Revamped menu or something like that
- Support for configuration files to skip the whole menu-by-menu process
   - For what I have in mind, it's basically just setting the variables yourself
- Adding additional applications (extra packages to install during the installation)
- More kernels
   - I might just add the kernels that are officially supported according to the [ArchWiki](https://wiki.archlinux.org/title/Kernel#Officially_supported_kernels).
- Addition to basic layout (just the partition) and LVM + LUKS encryption
- Install the AUR helper for access to the Arch User Repository
   - Likely `yay`
- Add multiple users

`At this point this might just turn into the official archinstall program that's included in the live ISO but it has LVM setup support soooooo yay!!!!`

## Notes

- Ensure that you have a backup of your important data before proceeding with the installation, as it will format your chosen partitions.
- If you want this program to fit *your* specific configurations, go ahead and modify the script according to your requirements!

## Support

If you encounter any issues or have questions about the script, feel free to [report it as an issue](https://github.com/06j-av/ArchLinux-lvm_tui/issues).
