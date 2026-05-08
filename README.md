## Helpful scripts to install linux apps in home dir
a collection of scripts designed to install linux apps in the user's home dir instead of as system apps.

Many of these are scripts I use personally on my own Arch-Linux install.

Scripts are only tested on Arch-Linux, but should work on other distro's as well.

# Funtion to add app folders into your user path
Take this function and add add it into your ~/.bashrc file. It takes folders in your ~/.local/ that end in .app,
searches for a bin folder, then adds that bin path into your user $PATH.

```
add_bin_to_path() {
    # Loop through all directories ending in .app under $HOME/.local
    for app_dir in "$HOME/.local"/*.app; do
        # Skip if no such directories exist
        [[ -d "$app_dir" ]] || continue

        # Check for 'bin' subdirectory
        bin_dir="$app_dir/bin"
        if [[ -d "$bin_dir" ]]; then
            # Convert the bin_dir path to use $HOME instead of the absolute path
            relative_bin_dir="${bin_dir/#$HOME/\$HOME}"

            # Check if bin_dir is already in the PATH
            if [[ ":$PATH:" != *":$bin_dir:"* ]]; then
                #echo "Adding $relative_bin_dir to PATH"
                export PATH="$PATH:$bin_dir"
            else
                :;
            fi
        fi
    done
}

add_bin_to_path;
```

# install_scrcpy_in_home_dir
This script will help you install scrcpy for linux. Tested only on my own Archlinux build, it should work with other distros.
The script will, install, update, or uninstall scrcpy. Since everything is done in the users home dir, no root is required.
See scrcpy here;
https://github.com/Genymobile/scrcpy


# Added script to install kitty as a user app.
Title says it all, run update-kitty.sh and it'll install kitty into ~/.local/kitty.app
Then use the function up above to add it into your path when you login.

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
