#!/bin/bash

# Greet the user
echo "Welcome! This script will help you install, update, or remove the scrcpy program."

# Function to check if scrcpy is installed
check_scrcpy_installed() {
  scrcpy_files=(
    "$HOME/.local/share/scrcpy/scrcpy-server"
    "$HOME/.local/share/man/man1/scrcpy.1"
    "$HOME/.local/share/icons/hicolor/256x256/apps/scrcpy.png"
    "$HOME/.local/share/zsh/site-functions/_scrcpy"
    "$HOME/.local/share/bash-completion/completions/scrcpy"
    "$HOME/.local/share/applications/scrcpy.desktop"
    "$HOME/.local/share/applications/scrcpy-console.desktop"
  )

  not_found=()

  for file in "${scrcpy_files[@]}"; do
    if [ ! -f "$file" ]; then
      not_found+=("$file")
    fi
  done

  if [ ${#not_found[@]} -eq ${#scrcpy_files[@]} ]; then
    echo "scrcpy is not installed."
    return 1
  elif [ ${#not_found[@]} -gt 0 ]; then
    echo "scrcpy installation is broken. The following files are missing:"
    printf "%s\n" "${not_found[@]}"
    return 2
  else
    installed_version=$(scrcpy --version | head -n 1 | grep -oP '\K[0-9]+\.[0-9]+(\.[0-9]+)?')
    echo "scrcpy is installed, version v$installed_version"
    return 0
  fi
}

check_for_scrcpy_folder() {
# Define the folder and files to check
folder="scrcpy"
required_files=("bump_version" "meson.build" "gradlew")

# Check if the folder exists
if [ -d "$folder" ]; then
  echo "Folder '$folder' exists."

  # Check if all required files exist in the folder
  missing_files=()
  for file in "${required_files[@]}"; do
    if [ ! -f "$folder/$file" ]; then
      missing_files+=("$file")
    fi
  done

  # If any files are missing, report them; otherwise, cd into the folder
  if [ ${#missing_files[@]} -eq 0 ]; then
    echo "All required files are present. Entering the folder..."
    cd "$folder" || { echo "Failed to enter folder. Exiting."; exit 1; }
  else
    echo ""    
    exit 1
  fi
else
  echo ""
  exit 1
fi

}

# Function to check if the scrcpy source is present
check_scrcpy_source() {
    check_for_scrcpy_folder
  if [[ "$(basename "$PWD")" != "scrcpy" ]] || [ ! -f "bump_version" ] || [ ! -f "meson.build" ] || [ ! -f "gradlew" ]; then
    echo "scrcpy source code does not appear to be downloaded."
    echo "1) Specify folder where scrcpy source code is located"
    echo "2) Fetch latest scrcpy source code"
    echo "3) Exit"
    read -p "Choose an option (1/2/3): " choice

    if [ "$choice" == "1" ]; then
      read -p "Enter the folder path where scrcpy source code is located: " folder
      cd "$folder" || { echo "Invalid folder. Exiting."; exit 1; }
      check_scrcpy_source
    elif [ "$choice" == "2" ]; then
      echo "Fetching latest scrcpy source code..."
      github_url="https://github.com/Genymobile/scrcpy/releases"
      latest_release=$(curl -s "$github_url" | grep -oP 'releases/tag/v\K[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)
      if [ -z "$latest_release" ]; then
        echo "Failed to fetch the latest scrcpy version. Exiting."
        exit 1
      fi
      curl -L "https://github.com/Genymobile/scrcpy/archive/refs/tags/v$latest_release.tar.gz" -o "scrcpy-v$latest_release.tar.gz"      
      mkdir -p scrcpy && tar -xzf "scrcpy-v$latest_release.tar.gz" -C scrcpy --strip-components=1
      cd "scrcpy" || { echo "Failed to extract scrcpy source. Exiting."; exit 1; }
      check_scrcpy_source
    elif [ "$choice" == "3" ]; then
      exit 0
    else
      echo "Invalid option. Exiting."
      exit 1
    fi
  else
    # Step 2: Extract the version number from meson.build file
    meson_version=$(grep -oP 'version: *'\''\K[0-9]+\.[0-9]+' meson.build)
    echo "scrcpy source is present, version v$meson_version"
  fi
}

# Function to check ANDROID_SDK_ROOT
check_android_sdk_root() {
  if [ -z "$ANDROID_SDK_ROOT" ]; then
    discover_android_sdk_root() {
      echo "ANDROID_SDK_ROOT variable is not set."
      read -p "Would you like me to discover and set it for you? (y/n): " choice
      case "$choice" in
        [Yy]*) 
          possible_folders=("$HOME/Android/Sdk" "$HOME/.android/Sdk" "/usr/local/android-sdk")
          for folder in "${possible_folders[@]}"; do
            if [ -d "$folder" ]; then
              export ANDROID_SDK_ROOT="$folder"
              echo "ANDROID_SDK_ROOT set to: $ANDROID_SDK_ROOT"
              return 0
            fi
          done
          echo "ERROR: Could not find Android SDK folder. Is it installed?"
          exit 1
          ;;
        [Nn]*) 
          echo "FATAL ERROR: ANDROID_SDK_ROOT is not set or empty."
          exit 1
          ;;
        *) 
          echo "Invalid input. Please enter y or n."
          exit 1
          ;;
      esac
    }
    discover_android_sdk_root
  else
    echo "ANDROID_SDK_ROOT is set to: $ANDROID_SDK_ROOT"
  fi
}

# Function to check for highest Gradle version
# Check for the highest gradle build version.
check_highest_gradle_version() {
  url="https://services.gradle.org/distributions/"
  content=$(curl -s "$url")
  versions=$(echo "$content" | grep -oP 'gradle-\K[0-9]+\.[0-9]+(\.[0-9]+)?(?=-bin.zip)')
  if [ -z "$versions" ]; then
    echo "No matching Gradle versions found."
    exit 1
  fi
  highest_version=$(echo "$versions" | sort -V | tail -n 1)
  echo "The highest Gradle version available is: $highest_version"
  sed -r -i "s/(gradle-)[0-9]+\.[0-9]+(\.[0-9]+)?(-bin\.zip)/\1$highest_version\3/" gradle/wrapper/gradle-wrapper.properties
}

# Function to install scrcpy in the home dir
install_scrcpy_as_user() {
  check_scrcpy_source
  check_android_sdk_root
  ./bump_version "$latest_release"
  check_highest_gradle_version
  ./gradlew wrapper
  meson setup x --prefix=~/.local --pkgconfig.relocatable --reconfigure --buildtype=release --strip -Db_lto=true
  ninja -Cx
  if ninja install -Cx; then
    echo "Installation completed successfully."
  # Prompt the user to run the application
  read -p "Would you like to run the application now? (y/n): " choice

  case "$choice" in
    [Yy]* )
      # Run the application if the user chooses 'y'
      ./run x
      ;;
    [Nn]* )
      # Exit without running the application
      echo ""
      ;;
    * )
      # Handle invalid input
      echo "Please enter y or n."
      exit 1
      ;;
  esac
else
  echo "Installation failed." >&2
  exit 1    
  fi
}

# Check if required packages are available.
requirements_check() {

# Function to check if a command exists and its version meets the required version
check_version() {
  local cmd="$1"
  local required_version="$2"
  
  # Check if the command exists
  if command -v "$cmd" >/dev/null 2>&1; then
    # Get the installed version
    installed_version=$("$cmd" --version | grep -oP '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)
    
    # Compare the installed version with the required version
    if printf '%s\n' "$required_version" "$installed_version" | sort -V | head -n 1 | grep -q "^$required_version$"; then
      echo "$cmd version $installed_version is installed and meets the requirement (>= $required_version)."
    else
      echo "FATAL ERROR: $cmd version $installed_version is installed but does not meet the requirement (>= $required_version)." >&2
      exit 1
    fi
  else
    echo "FATAL ERROR: $cmd is not installed." >&2
    exit 1
  fi
}

# Check for ninja >= 1.12.0
check_version "ninja" "1.12.0"

# Check for meson >= 1.5.0
check_version "meson" "1.5.0"


}

# Main menu function
main_menu() {
  echo " "
  echo "-----------------   SCRCPY Installation Manager ------------------"
  echo " "
  echo "                 ------------ Main Menu ------------"
  echo " "
  check_scrcpy_source
  source_installed_status=$?
  check_scrcpy_installed  
  program_installed_status=$?

  if [ $program_installed_status -eq 0 ]; then
    echo "1) Update scrcpy"
    echo "2) Uninstall scrcpy"
    echo "3) Exit"
    read -p "Choose an option (1/2/3): " choice

    case $choice in
      1)
        github_url="https://github.com/Genymobile/scrcpy/releases"
        latest_release=$(curl -s "$github_url" | grep -oP 'releases/tag/v\K[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1)
        echo "Latest release version from GitHub: $latest_release"
        installed_version=$(scrcpy --version | head -n 1 | grep -oP '\K[0-9]+\.[0-9]+(\.[0-9]+)?')
        echo "Installed scrcpy version: $installed_version"

        if [ "$latest_release" == "$installed_version" ]; then
          echo "You already have the latest version of scrcpy installed."
          main_menu
        elif [ "$(printf '%s\n' "$installed_version" "$latest_release" | sort -V | tail -n 1)" == "$latest_release" ]; then
          read -p "Do you want to update scrcpy to version $latest_release? (y/n): " update_choice
          if [ "$update_choice" == "y" ]; then            
            install_scrcpy_as_user
            main_menu
          fi
        else
          echo "You have a newer version of scrcpy installed."
          main_menu
        fi
        ;;
      2)
        scrcpy_files=(
          "$HOME/.local/share/scrcpy/scrcpy-server"
          "$HOME/.local/share/man/man1/scrcpy.1"
          "$HOME/.local/share/icons/hicolor/256x256/apps/scrcpy.png"
          "$HOME/.local/share/zsh/site-functions/_scrcpy"
          "$HOME/.local/share/bash-completion/completions/scrcpy"
          "$HOME/.local/share/applications/scrcpy.desktop"
          "$HOME/.local/share/applications/scrcpy-console.desktop"
        )
        removed_files=()
        for file in "${scrcpy_files[@]}"; do
          if [ -f "$file" ]; then
            rm -f "$file"
            removed_files+=("$file")
          fi
        done
        if [ ${#removed_files[@]} -gt 0 ]; then
          echo "The following files were removed:"
          printf "%s\n" "${removed_files[@]}"
          echo "scrcpy has been successfully uninstalled."
        else
          echo "No files to remove, scrcpy seems already uninstalled."
        fi
        ;;
      3)
        exit 0
        ;;
      *)
        echo "Invalid choice. Exiting."
        exit 1
        ;;
    esac
  else
    echo "1) Install scrcpy"
    echo "2) Exit"
    read -p "Choose an option (1/2): " choice
    if [ "$choice" == "1" ]; then
      install_scrcpy_as_user
    else
      exit 0
    fi
  fi
}

# Start the main menu
main_menu
