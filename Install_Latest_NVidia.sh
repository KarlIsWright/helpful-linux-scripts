#!/bin/bash

#Change to Downloads folder
cd $HOME/Downloads
#DRIVER VERSION
#
read -e -p "enter driver version (eg 550.54.14): " -i "550.54.14" NVID_VER
# NVID_VER=${NVID_VER:-550.54.14}
echo $NVID_VER
#Check if installer exists
if [ -e "NVIDIA-Linux-x86_64-$NVID_VER.run" ]; then
    echo "NVIDIA installer exists."
else
    echo "NVIDIA installer not found." \n
    echo "Downloading..."
    # Fetch Installer
    wget https://us.download.nvidia.com/XFree86/Linux-x86_64/$NVID_VER/NVIDIA-Linux-x86_64-$NVID_VER.run
fi
# Make exec
chmod +x NVIDIA-Linux-x86_64-$NVID_VER.run
# Check if directory exists
if [ -d "NVIDIA-Linux-x86_64-$NVID_VER" ]; then
    echo "NVIDIA install dir exists."
    # cd
    cd NVIDIA-Linux-x86_64-$NVID_VER
    #make exec    
    chmod +x nvidia-installer
else
    echo "NVIDIA install dir does not exist."
    echo "Creating install dir..."
    # Extract
    sh NVIDIA-Linux-x86_64-$NVID_VER.run -x
    #make exec    
    chmod +x nvidia-installer    
fi

# cd
cd NVIDIA-Linux-x86_64-$NVID_VER


# Initialize variables
dkms="--dkms"
noxcheck="--no-x-check"
nonouveaucheck="--no-nouveau-check"
disablenouveau="--no-disable-nouveau"
nopeermem="--peermem"
nodrm="--drm"
installcompat32libs="--install-compat32-libs"
rebuildinitramfs="--no-rebuild-initramfs"
nocheckforaltinstalls="--check-for-alternate-installs"
systemd="--systemd"
skipdepmod="--depmod"
KERNELNAME="$(uname -r)"

show_menu() {
    echo "1. dkms: $dkms"
    echo "2. no x check: $noxcheck"
    echo "3. no nouveau check: $nonouveaucheck"
    echo "4. disable nouveau: $disablenouveau"
    echo "5. no peer mem: $nopeermem"
    echo "6. no drm: $nodrm"
    echo "7. Install 32-bit compatibility libraries: $installcompat32libs"
    echo "8. Rebuild Init RAM FS: $rebuildinitramfs"
    echo "9. Check for alternate installs: $nocheckforaltinstalls"
    echo "10. Systemd: $systemd"
    echo "11. Skip mod dependancy: $skipdepmod"
    echo "12. Install to Kernel version: $KERNELNAME"
    echo "13. Install NVIDIA Driver"
    echo "14. Uninstall NVIDIA Driver"
    echo "15. Perform Basic Sanity Checks on Installed driver"
    echo "16. exit"
}

toggle_variable() {
    case $1 in
        1) dkms=$(toggle $dkms);;
        2) noxcheck=$(toggle $noxcheck);;
        3) nonouveaucheck=$(toggle $nonouveaucheck);;
        4) disablenouveau=$(toggle $disablenouveau);;
        5) nopeermem=$(toggle $nopeermem);;
        6) nodrm=$(toggle $nodrm);;
        7) installcompat32libs=$(toggle $installcompat32libs);;
        8) rebuildinitramfs=$(toggle $rebuildinitramfs);;
        9) nocheckforaltinstalls=$(toggle $nocheckforaltinstalls);;
        10) systemd=$(toggle $systemd);;
        11) skipdepmod=$(toggle $skipdepmod);;        
    esac
}

# Function to toggle values based on custom values
toggle() {
    case $1 in
        "--dkms") echo "--no-dkms";;
        "--no-dkms") echo "--dkms";;
        "--no-peermem") echo "--peermem";;
        "--peermem") echo "--no-peermem";;
        "--no-drm") echo "--drm";;
        "--drm") echo "--no-drm";;
        "--no-x-check") echo "$x checkwillbeperformed";;
        "--no-nouveau-check") echo "--nouveau-check";;
        "--nouveau-check") echo "--no-nouveau-check";;
        "--disable-nouveau") echo "--no-disable-nouveau";;
        "--no-disable-nouveau") echo "--disable-nouveau";;
        "--install-compat32-libs") echo "--no-install-compat32-libs";;
        "--no-install-compat32-libs") echo "--install-compat32-libs";;
        "--rebuild-initramfs") echo "--no-rebuild-initramfs";;
        "--no-rebuild-initramfs") echo "--rebuild-initramfs";;
        "--no-check-for-alternate-installs") echo "--check-for-alternate-installs";;
        "--check-for-alternate-installs") echo "--no-check-for-alternate-installs";;
        "--systemd") echo "--no-systemd";;
        "--no-systemd") echo "--systemd";;
        "--skip-depmod") echo "--depmod";;
        "--depmod") echo "--skip-depmod";;
        *) echo "unknown";;
    esac
}

# Function to check variable for custom value and return custom value
check_variable() {
    case $1 in
        "--peermem") echo "";;
        "--no-peermem") echo "--no-peermem";;
        "--drm") echo "";;
        "--no-drm") echo "--no-drm";;
        "--no-disable-nouveau") echo "";;
        "--disable-nouveau") echo "--disable-nouveau";;
        "--nouveau-check") echo "";;
        "--no-nouveau-check") echo "--no-nouveau-check";;        
        "--check-for-alternate-installs") echo "";;
        "--no-check-for-alternate-installs") echo "--no-check-for-alternate-installs";;
        "--depmod") echo "";;
        "--skip-depmod") echo "--skip-depmod";;
        *) echo "unknown";;
    esac
}

# Example usage:
# Check a variable named 'status' for a custom value and return another custom value
# For example:
# status="off"
# new_status=$(check_variable $status)
# echo "New status: $new_status"

# Main function
main() {
    while true; do
        clear
        show_menu

        read -p "Enter your choice: " choice

        case $choice in
            1|2|3|4|5|6|7|8|9|10|11)
                toggle_variable $choice
                ;;
            12)
                read -e -p "Enter Kenerl to install to: " -i "$(uname -r)" KERNELNAME
                ;;
            13)
                echo "Executing command..."
                sudo ./nvidia-installer -a $dkms $(check_variable $nodrm) $(check_variable $nopeermem) $installcompat32libs $rebuildinitramfs $systemd $(check_variable $skipdepmod) $(check_variable $nonouveaucheck) $disablenouveau $(check_variable $nocheckforaltinstalls) $noxcheck --kernel-name=$KERNELNAME --kernel-module-source-prefix=/usr/src --kernel-source-path=/lib/modules/$KERNELNAME/build/ --kernel-module-build-directory=kernel/ --kernel-module-source-prefix=/usr/src --kernel-install-path=/lib/modules/$KERNELNAME/kernel/drivers/video/
                echo "Command executed!"
                read -e -p "acknowledge that you have read the above: " -i "I have" didyouread
                ;;
            14)
                echo "uninstalling..."
                sudo ./nvidia-installer -a --uninstall
                echo "uninstalled."
		read -e -p "acknowledge that you have read the above: " -i "I have" didyouread
                ;;
            15)
                echo "performing sanity checks..."
                sudo ./nvidia-installer -a --sanity
                echo "perfored sanity check."
		read -e -p "acknowlege that you have read the above: " -i "I have" didyouread
                ;;
            16)
                echo "Exiting..."
                exit 0
                ;;
            *)
                echo "Invalid option. Please try again."
                ;;
        esac
    done
}

main

# Check the exit status of the command
if [ $? -eq 0 ]; then
    echo "The command executed successfully."
    cd ../
    rm -rf NVIDIA-Linux-x86_64-$NVID_VER
else
    echo "The command failed to execute."
fi
