#!/bin/bash

# Ask for the administrator password upfront
echo "Please enter your root password:"
read -s PASSWORD

# Function to execute a command with 'sudo' using the password from above
run_as_root() {
    echo $PASSWORD | sudo -Sv
    echo $PASSWORD | sudo -S $@
}

get_user_response() {
    local prompt_message="$1"
    local user_response

    while true; do
        echo "$prompt_message (y/n)"
        read user_response
        case $user_response in
            [Yy]* ) user_response='y'; break;;  # Yes
            [Nn]* ) user_response='n'; break;;  # No
            * ) echo "Please answer 'y' for yes or 'n' for no.";;
        esac
    done

    echo $user_response  # This will return the value to the caller.
}

install_vscode_extensions=$(get_user_response "Do you wish to install VS Code Extensions?")
install_python_extension=$(get_user_response "VS Code Extensions: Install Python extensions?")
install_ssh_extension=$(get_user_response "VS Code Extensions: Install SSH extensions?")
install_java_extension=$(get_user_response "VS Code Extensions: Install Java extensions?")

# Ask the user if they want to set up Git.
SETUP_GIT=$(get_user_response "Do you wish to set up global Git configuration? (y/n)")
if [[ $SETUP_GIT = "y" ]]; then
    # If the user wants to set up Git, ask for their credentials.
    echo "Please enter your Git user name:"
    read GIT_USER_NAME
    echo "Please enter your Git email address:"
    read GIT_EMAIL

    # Check if the user has entered both a name and an email.
    if [[ -n $GIT_USER_NAME && -n $GIT_EMAIL ]]; then
        # Set the global Git name and email.
        git config --global user.name "$GIT_USER_NAME"
        git config --global user.email "$GIT_EMAIL"
        echo "Git global configuration updated."
    else
        echo "Git global configuration not updated. Please ensure to provide both name and email."
    fi

    SETUP_BRANCH=$(get_user_response "Do you want to setup 'main' as the default branch?")
    if [[ $SETUP_BRANCH = "y" ]]; then
        git config --global init.defaultBranch main
    else
        echo "Skipped setup of default branch"
    fi
    echo "You setup your git settings successfully!"
else
    echo "Skipping Git setup."
fi




# Ask if the user wants to generate an SSH key.
GENERATE_SSH_KEY=$(get_user_response "Do you want to generate a new SSH key for Git? (y/n)")
if [[ $GENERATE_SSH_KEY = "y" ]]; then

    if [[ $SETUP_GIT = "y" ]]; then
        USE_GIT_FOR_SSH=$(get_user_response "Do you want to use your GIT email for the SSH Key? (y/n)")
        if [[ $USE_GIT_FOR_SSH = "y" ]]; then
            SSH_EMAIL="$GIT_EMAIL"  # Default to using the Git email.
        else
            echo "Please enter a email/name for the SSH key:"
            read SSH_EMAIL
        fi
    else
        echo "Please enter a email for the SSH key:"
        read SSH_EMAIL
    fi

    # Ask for a name for the SSH key.
    echo "Please enter a name for storing the SSH key:"
    read SSH_KEY_NAME

    # Generate the SSH key.
    ssh-keygen -t rsa -b 4096 -C "$SSH_EMAIL" -f ~/.ssh/"$SSH_KEY_NAME"

    # Ensure the ssh-agent is running and add the new SSH key to it.
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/"$SSH_KEY_NAME"

    run_as_root dnf install xclip

    # Display the public key.
    echo "Here is your public SSH key:"
    cat ~/.ssh/"$SSH_KEY_NAME".pub

    # Attempt to copy the public key to the clipboard.
    if xclip -sel clip < ~/.ssh/"$SSH_KEY_NAME".pub; then
        echo "Your public SSH key has been copied to the clipboard."
    else
        echo "Failed to copy the SSH key to the clipboard. Please ensure 'xclip' is installed, or copy the key manually."
    fi

    # Confirm with the user that they've pasted the key into Git.
    while true; do
        echo "Please past the key into git (online) and confirm to continue the script (y)"
        read PASTED_INTO_GIT

        if [[ $PASTED_INTO_GIT = "y" ]]; then
            echo "Continuing with the script..."
            break
        fi
    done
else
    echo "Skipping SSH key generation."
fi




# Ask the user if the system will be used for remote sessions.
REMOTE_USAGE=$(get_user_response "Will this computer be used for remote sessions? This will enable Xorg by default since it works better with remote sessions (y/n)")

if [[ $REMOTE_USAGE = "y" ]]; then
    # Set GNOME to use Xorg for the next sessions.
    run_as_root tee /etc/gdm/custom.conf <<EOL
# GDM configuration storage
[daemon]
# Uncomment the line below to force the login screen to use Xorg
WaylandEnable=false
EOL
    echo "Xorg will be used for future sessions."
else
    echo "No changes made to the display server settings."
fi






# Update and upgrade the system
run_as_root dnf update -y
run_as_root dnf upgrade -y


# Install important packages

run_as_root dnf install -y gnome-tweaks

run_as_root dnf -y install flatpak
run_as_root flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

run_as_root dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
run_as_root dnf -y install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
run_as_root dnf -y install ffmpeg
run_as_root dnf -y install ffmpeg-devel

run_as_root dnf install @development-tools





# Install Docker
run_as_root dnf -y remove docker \
                    docker-client \
                    docker-client-latest \
                    docker-common \
                    docker-latest \
                    docker-latest-logrotate \
                    docker-logrotate \
                    docker-selinux \
                    docker-engine-selinux \
                    docker-engine
run_as_root dnf -y install dnf-plugins-core
run_as_root dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
run_as_root dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker on Start
run_as_root systemctl start docker
run_as_root enable docker.service
run_as_root enable containerd.service

# Enable Docker rootless
run_as_root groupadd docker
run_as_root usermod -aG docker $USER
run_as_root newgrp docker






# Install VS Code
run_as_root rpm --import https://packages.microsoft.com/keys/microsoft.asc
run_as_root sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
run_as_root dnf check-update
run_as_root dnf install -y code

declare -a PYTHON_EXTENSIONS=(
    "ms-python.python"
    "ms-python.vscode-pylance"
)
declare -a SSH_EXTENSIONS=(
    "ms-vscode-remote.remote-ssh"
)
declare -a DOCKER_EXTENSIONS=(
    "ms-azuretools.vscode-docker"
)
declare -a JAVA_EXTENSIONS=(
    "vscjava.vscode-java-pack"
)

if [ "$install_vscode_extensions" = "y" ]; then
    echo "User chose to install VS Code extensions. Proceeding..."

    if [ "$install_python_extension" = "y" ]; then
        echo "Installing Python extensions..."
        for extension in "${PYTHON_EXTENSIONS[@]}"; do
            code --install-extension $extension
        done
    fi

    if [ "$install_python_extension" = "y" ]; then
        echo "Installing Python extensions..."
        for extension in "${SSH_EXTENSIONS[@]}"; do
            code --install-extension $extension
        done
    fi

    if [ "$install_python_extension" = "y" ]; then
        echo "Installing Python extensions..."
        for extension in "${DOCKER_EXTENSIONS[@]}"; do
            code --install-extension $extension
        done
    fi
    
    if [ "$install_python_extension" = "y" ]; then
        echo "Installing Python extensions..."
        for extension in "${JAVA_EXTENSIONS[@]}"; do
            code --install-extension $extension
        done
    fi
else
    echo "User chose not to install any VS Code extensions."
fi





# Set DNF metadata expiry to 7 days for quick package installation
grep -q "^#metadata_expire" /etc/dnf/dnf.conf && echo $PASSWORD | sudo -S sed -i 's/^#metadata_expire.*/metadata_expire=7d/' /etc/dnf/dnf.conf || \
grep -q "^metadata_expire" /etc/dnf/dnf.conf && echo $PASSWORD | sudo -S sed -i 's/^metadata_expire.*/metadata_expire=7d/' /etc/dnf/dnf.conf || \
echo "metadata_expire=7d" | sudo tee -a /etc/dnf/dnf.conf
run_as_root dnf clean all




# Enable minimize and maximize buttons on window title bars in GNOME.
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'




# Clear the password variable at the end of the script
unset PASSWORD




echo "Initialization completed."
