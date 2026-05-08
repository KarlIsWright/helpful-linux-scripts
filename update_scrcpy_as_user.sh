#!/bin/bash

echo "Welcome! This script will help you install, update, or remove the scrcpy program."

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

  for file in "${scrcpy_files[@]}"; do
    if [ -f "$file" ]; then
      found+=("$file")
    fi
  done

  if [ ${#not_found[@]} -eq ${#scrcpy_files[@]} ]; then
    echo "scrcpy is not installed."
    return 1
  elif [ ${#not_found[@]} -gt 0 ]; then
    echo "scrcpy installation is broken."
    echo "The following files were found:"
    printf "%s\n" "${found[@]}"
    echo "The following files are missing:"
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
    cd "$folder" || { echo "Failed to enter folder. Exiting."; exit 0; }
  else
    echo ""    
  fi
else
  echo ""
fi

}

# Function to check ANDROID_SDK_ROOT
check_android_sdk_root() {
  if [ -z "$ANDROID_SDK_ROOT" ]; then
    discover_android_sdk_root() {
      echo "ANDROID_SDK_ROOT variable is not set."
      read -p "Would you like me to discover and set it for you? y/n (y): " choice

      choice="${choice:-y}"

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
          ;;
        [Nn]*) 
          echo "FATAL ERROR: ANDROID_SDK_ROOT is not set or empty."
          ;;
        *) 
          echo "Invalid input. Please enter y or n."
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
  echo "checking for the highest gradle version."
  url="https://services.gradle.org/distributions/"
  content=$(curl -s "$url")
  versions=$(echo "$content" | grep -oP 'gradle-\K[0-9]+\.[0-9]+(\.[0-9]+)?(?=-bin.zip)')
  if [ -z "$versions" ]; then
    echo "No matching Gradle versions found."
  fi
  export highest_gradle_version=$(echo "$versions" | sort -V | tail -n 1)
  echo "The highest Gradle version available is: $highest_gradle_version"
}

install_gradel_version() {
  check_highest_gradle_version
  echo " "
  echo "  Gradel is required to compile scrcpy."
  echo "  Press enter to install the latest version."
  echo " "
  echo " "
  export gradle_version=${highest_gradle_version}
  read -p "  Specify which version you'd like to install (default: $highest_gradle_version): " user_input
  gradle_version="${user_input:-$gradle_version}"
  echo "Using gradle version: $gradle_version"

  sed -r -i "s/(gradle-)[0-9]+\.[0-9]+(\.[0-9]+)?(-bin\.zip)/\1$gradle_version\3/" gradle/wrapper/gradle-wrapper.properties
  distributionSha256Sum=$(curl -L https://services.gradle.org/distributions/gradle-${gradle_version}-bin.zip.sha256)
  echo "the sha256sum is $distributionSha256Sum"
  sed -r -i "s/distributionSha256Sum=.*/distributionSha256Sum=$distributionSha256Sum/" gradle/wrapper/gradle-wrapper.properties
}

# Function to install scrcpy in the home dir
install_scrcpy_as_user() {
  check_scrcpy_source || { troubleshooting "$(check_scrcpy_source 2>&1)"; }
  check_android_sdk_root || { troubleshooting "$(check_android_sdk_root 2>&1)"; }
  get_latest_release
  ./bump_version $latest_release || { echo "Failed to run bump_version."; troubleshooting "bump_version failed"; }
  install_gradel_version  || { echo "Failed to download Gradel."; troubleshooting "gradle version install failed"; }
  
  # Run gradlew wrapper and capture output for error analysis
  echo "Installing Gradle wrapper..."
  gradle_output=$(./gradlew wrapper 2>&1)
  if [ $? -ne 0 ]; then
    echo "Gradle wrapper failed. Running troubleshooting..."
    troubleshooting "$gradle_output"
  fi
  
  # Run meson setup and capture output
  echo "Running Meson setup..."
  meson_output=$(meson setup x --prefix=~/.local --pkgconfig.relocatable --reconfigure --buildtype=release --strip -Db_lto=true 2>&1)
  if [ $? -ne 0 ]; then
    echo "Meson setup failed. Running troubleshooting..."
    troubleshooting "$meson_output"
  fi
  
  echo "Running Ninja build and install..."
  ninja_output=$(ninja -Cx 2>&1)
  if [ $? -ne 0 ]; then
    echo "Ninja build failed. Running troubleshooting..."
    troubleshooting "$ninja_output"
  fi

  # Adding additional desktop shortcuts to run scrcpy with either video or audio only.
        cat >> "$HOME/.local/share/applications/scrcpy.desktop" << 'EOF'
[Desktop Entry]
Name=scrcpy
GenericName=Android Remote Control
Comment=Display and control your Android device
# For some users, the PATH or ADB environment variables are set from the shell
# startup file, like .bashrc or .zshrc… Run an interactive shell to get
# environment correctly initialized.
Exec=/bin/sh -c "\\$SHELL -i -c scrcpy --video-codec=h265 --audio-codec=raw --audio-buffer=70 --video-buffer=70"
Icon=scrcpy
Terminal=false
Type=Application
Categories=Utility;RemoteAccess;
StartupNotify=false
EOF


        cat >> "$HOME/.local/share/applications/scrcpy-console.desktop" << 'EOF'
[Desktop Entry]
Name=scrcpy (console)
GenericName=Android Remote Control
Comment=Display and control your Android device
# For some users, the PATH or ADB environment variables are set from the shell
# startup file, like .bashrc or .zshrc… Run an interactive shell to get
# environment correctly initialized.
Exec=/bin/sh -c "\\$SHELL -i -c 'scrcpy --pause-on-exit=if-error  --video-codec=h265 --audio-buffer=70 --video-buffer=70'"
Icon=scrcpy
Terminal=true
Type=Application
Categories=Utility;RemoteAccess;
StartupNotify=false
EOF

        cat >> "$HOME/.local/share/applications/scrcpy-audio.desktop" << 'EOF'
[Desktop Entry]
Name=scrcpy audio
GenericName=Android Remote Control Audio Only
Comment=Run scrcpy in audio only mode.
# For some users, the PATH or ADB environment variables are set from the shell
# startup file, like .bashrc or .zshrc… Run an interactive shell to get
# environment correctly initialized.
Exec=/bin/sh -c "\\$SHELL -i -c 'scrcpy --no-video --no-video-playback --audio-codec=raw --audio-buffer=70'"
Icon=scrcpy
Terminal=false
Type=Application
Categories=Utility;RemoteAccess;
StartupNotify=false
EOF

      cat >> "$HOME/.local/share/applications/scrcpy-video.desktop" << 'EOF'
[Desktop Entry]
Name=scrcpy video
GenericName=Android Remote Control Video Only
Comment=Run scrcpy in audio only mode.
# For some users, the PATH or ADB environment variables are set from the shell
# startup file, like .bashrc or .zshrc… Run an interactive shell to get
# environment correctly initialized.
Exec=/bin/sh -c "\\$SHELL -i -c 'scrcpy --no-audio --no-audio-playback --video-codec=h265 --video-bit-rate=5M --video-buffer=70'"
Icon=scrcpy
Terminal=false
Type=Application
Categories=Utility;RemoteAccess;
StartupNotify=false
EOF

  if ninja install -Cx; then
    echo "Installation completed successfully."
    # Prompt the user to run the application
    read -p "Would you like to run the application now? y/n (y): " choice

    choice="${choice:-y}"

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
    fi
  else
    echo "FATAL ERROR: $cmd is not installed." >&2
  fi
}

# Check for ninja >= 1.12.0
check_version "ninja" "1.12.0"

# Check for meson >= 1.5.0
check_version "meson" "1.5.0"


}


troubleshooting() {
  local error_output="$1"
  local build_gradle_file="server/build.gradle"
  local root_gradle_file="build.gradle"
  local fix_applied=false
  
  echo ""
  echo "----------------------------------------"
  echo " "
  echo "Scanning for Gradle build errors..."
  echo " "
  echo "----------------------------------------"
  
  # Check for UastFacade initialization error
  if echo "$error_output" | grep -qi "UastFacade\|lintVital\|AndroidLintWorkAction"; then
    echo "✗ ERROR FOUND: Lint Framework initialization crash"
    echo "  (UastFacade or lintVital task failure detected)"
    echo ""
    echo "📝 APPLYING FIX: Disabling lintVital tasks..."
    
    # Check if server/build.gradle already has the fix
    if ! grep -q "lintVital" "$build_gradle_file"; then
      echo "  → Adding lintVital disable to $build_gradle_file"
      cat >> "$build_gradle_file" << 'EOF'

// Disable lintVital tasks due to UastFacade crash with Gradle 9.x and AGP 8.7.1
tasks.whenTaskAdded { task ->
    if (task.name.contains('lintVital')) {
        task.enabled = false
    }
}
EOF
      echo "  ✓ Added to server/build.gradle"
      fix_applied=true
    fi
    
    # Check if root build.gradle already has the fix
    if ! grep -q "lintVital" "$root_gradle_file"; then
      echo "  → Adding lintVital disable to root $root_gradle_file"
      sed -i '/tasks.withType(JavaCompile)/a\    // Disable all lint vital tasks due to UastFacade initialization crash\n    tasks.whenTaskAdded { task ->\n        if (task.name.contains("lintVital")) {\n            task.enabled = false\n        }\n    }' "$root_gradle_file"
      echo "  ✓ Added to root build.gradle"
      fix_applied=true
    fi
    
    if [ "$fix_applied" = true ]; then
      echo ""
      echo "----------------------------------------"
      read -p "Would you like to try installing again? (y/n): " retry_choice
      if [[ "$retry_choice" == "y" || "$retry_choice" == "Y" ]]; then
        return 0
      else
        echo "Returning to main menu..."
        main_menu
      fi
    fi
  fi
  
  # Check for other common gradle errors
  if echo "$error_output" | grep -qi "java.lang.NoClassDefFoundError\|ExceptionInInitializerError\|ClassNotFoundException"; then
    echo "✗ ERROR FOUND: Java class loading error during Gradle build"
    echo "  This may be due to classpath or dependency issues."
    echo ""
    echo "----------------------------------------"
    read -p "Return to main menu? (y/n): " return_choice
    if [[ "$return_choice" == "y" || "$return_choice" == "Y" ]]; then
      main_menu
    fi
    return 1
  fi
  
  if echo "$error_output" | grep -qi "Unsupported class file major version"; then
    echo "✗ ERROR FOUND: Java version mismatch"
    echo "  Gradle version may not support current Java version."
    echo ""
    echo "----------------------------------------"
    read -p "Return to main menu? (y/n): " return_choice
    if [[ "$return_choice" == "y" || "$return_choice" == "Y" ]]; then
      main_menu
    fi
    return 1
  fi
  
  return 0
}


get_latest_release() {
        github_url="https://github.com/Genymobile/scrcpy/releases"
        latest_release=$(curl -s "$github_url" | grep -oP 'releases/tag/v\K[0-9]+\.[0-9]+(\.[0-9]+)?' | head -n 1);
        if [ -z "$latest_release" ]; then
        echo "Error. Couldn't detect latest release from Github"
        fi
        export latest_release;

}

get_latest_install(){
        installed_version=$(scrcpy --version | head -n 1 | grep -oP '\K[0-9]+\.[0-9]+(\.[0-9]+)?');
        if [ -z "$installed_version" ]; then
        echo "Scrcpy doesn't appear to be installed."
        fi
        export installed_version;
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
        get_latest_release
        curl -L "https://github.com/Genymobile/scrcpy/archive/refs/tags/v$latest_release.tar.gz" -o "scrcpy-v$latest_release.tar.gz"
        mkdir -p scrcpy && tar -xzf "scrcpy-v$latest_release.tar.gz" -C scrcpy --strip-components=1
        cd "scrcpy" || { echo "Failed to extract scrcpy source. Exiting."; exit 1; }
        check_scrcpy_source
      elif [ "$choice" == "3" ]; then
        exit 0
      else
        echo "Invalid option. Exiting."
      fi

  else
    # Step 2: Extract the version number from meson.build file
    meson_version=$(grep -oP 'version: *'\''\K[0-9]+\.[0-9]+\.[0-9]+' meson.build)  || { echo "Could not get meson_version check meson.build file. Exiting."; exit 1; }
    echo "scrcpy source is present, version v$meson_version"
  fi
}

# Main menu function
main_menu() {
  check_scrcpy_source
  source_installed_status=$?
  check_scrcpy_installed  
  program_installed_status=$?
  get_latest_release
  echo "Latest scrcpy release version from GitHub: $latest_release"

  echo " "
  echo "-----------------   SCRCPY Installation Manager ------------------"
  echo " "
  echo "                 ------------ Main Menu ------------"
  echo " "

  if [ $program_installed_status -eq 0 ]; then
    get_latest_release
    get_latest_install
    echo "                 ------------ Currently installed version ------------"
    echo "Installed scrcpy version: $installed_version"
    echo " "
    echo "                 -----------------------"
    echo "1) Update scrcpy"
    echo "2) Uninstall scrcpy"
    echo "3) Exit"
    read -p "Choose an option (1/2/3): " choice

    case $choice in
      1)

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
          "$HOME/.local/share/applications/scrcpy-audio.desktop"
          "$HOME/.local/share/applications/scrcpy-video.desktop"
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
        echo "Returning to main menu..."
        main_menu
        ;;
      3)
        exit 0
        ;;
      *)
        echo "Invalid choice. Exiting."
        exit 0
        ;;
    esac
  else
    echo " "
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
