## Helpful scripts to install linux apps in home dir
a collection of scripts designed to install linux apps in the user's home dir instead of as system apps.

Many of these are scripts I use personally on my own Arch-Linux install.

Scripts are only tested on Arch-Linux, but should work on other distro's as well.

# install_scrcpy_in_home_dir
This script will help you install scrcpy for linux. Tested only on my own Archlinux build, it should work with other distros.
The script will, install, update, or uninstall scrcpy. Since everything is done in the users home dir, no root is required.
See scrcpy here;
https://github.com/Genymobile/scrcpy


# Install_Latest_NVidia
This script asks what version of the NVIDIA driver you want to work with then fetches, and helps you install it. Requires root.
This script will help you install your chosen NVIDIA driver with the following choices;
* Choose wheather to enable dkms
* Choose wheather to check for running X server
* Check for nouveau
* Choose wheather to disable nouveau
* Choose wheather to enable peer mem
* Choose wheather to enable drm
* Install 32-bit compatibility libraries
* Choose whether to compile for Systemd
* Install for specific Kernel version
* Install NVIDIA Driver
* Uninstall NVIDIA Driver
* Perform Basic Sanity Checks on Installed driver
