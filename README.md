# Arch Linux Installation with LVM Setup (Terminal User Interface)

This script automates the installation process of Arch Linux with Logical Volume Management (LVM) and uses a terminal user interface with `whiptail`. It is designed to make the installation steps more simpler for incoming Arch Linux users.

## Some stuff you need to know
- This script will only make one user, so for now you can add users with `useradd` when you boot into your installation.

## Things you'll need

- **Arch Linux ISO**: Download the latest Arch Linux ISO from the [official website](https://archlinux.org/download/).
- **Bootable USB Drive**: Create a bootable USB drive with the Arch ISO using your preferred tools.
- **Internet Connection**: Ensure that your system has a **stable** internet connection for downloading packages during the installation process.

## Usage

1. **Boot from USB**: Insert the bootable USB drive into your system, boot from it, and get yourself a great internet connection. (obviously)

2. **Prepare Disk**:
   - Ensure that you create an EFI System Partition (ESP) and a partition with the type set as "Linux LVM". You can confirm using:
    ```
    lsblk -o NAME,PARTTYPENAME
    ```


3. **Run some pacman commands**:
   - You'll need to run some pacman commands to ensure that the installation process goes smooth.
     ```
     pacman -Sy
     pacman -S git
     # In case you get errors about keys, run
     pacman-key --init
     ```
    
4. **Clone this repository**:
   - Clone the repository to the Arch ISO environment using:
     ```
     git clone https://github.com/06j-av/ArchLinux-lvm_tui
     ```

5. **Run the Script**:
   - Run the script. You shouldn't need to make the script executable, but if you do, run `chmod +x setup.sh`.
     ```
     ./ArchLinux-lvm_tui/setup.sh
     # Or if you've entered the directory
     ./setup.sh
     ```

6. **Follow the On-Screen Instructions**:
   - Follow the prompts and provide necessary inputs as requested by the script.

7. **Reboot**:
   - Once the installation is complete, reboot your system and remove the USB drive, and if everything went well, you can say "hello" to your new Arch Linux system.

## Notes

- Ensure that you have a backup of your important data before proceeding with the installation, as it will overwrite existing partitions.
- If you want this program to fit *your* specific configurations, go ahead and modify the script according to your requirements!

## Support

If you encounter any issues or have questions about the script, feel free to [report it as an issue](https://github.com/06j-av/archlinux-installScript-LVM/issues).
