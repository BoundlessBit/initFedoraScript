#!/bin/bash

echo "Hello World"
mkdir ~/initFedora
cd ~/initFedora

USER_RESPONSE=''

get_user_response() {
    local prompt_message="$1"

    while true; do
        echo "$prompt_message (y/n)"
        read response
        case $response in
            [Yy]* ) 
                USER_RESPONSE='y'  # Set the global variable
                return  # We use 'return' here to exit the function, ensuring it doesn't continue to loop
                ;;
            [Nn]* ) 
                USER_RESPONSE='n'  # Set the global variable
                return  # Exit the function
                ;;
            * ) echo "Please answer 'y' for yes or 'n' for no.";;
        esac
    done
}

# Install VS Code & Extensions

get_user_response "Do you wish to install VS Code?"
install_vscode=$USER_RESPONSE

if [ "$install_vscode" = "y" ]; then
    get_user_response "VS Code Extensions: Install Python extensions?"
    install_python_extension=$USER_RESPONSE

    get_user_response "VS Code Extensions: Install SSH extensions?"
    install_ssh_extensions=$USER_RESPONSE

    get_user_response "VS Code Extensions: Install Java extensions?"
    install_java_extensions=$USER_RESPONSE
else
    echo "VS Code Extensions installation will be skipped."
fi


# Ask the user if they want to set up Git.
get_user_response "Do you wish to set up global Git configuration?"
if [[ $USER_RESPONSE = "y" ]]; then
    # If the user wants to set up Git, ask for their credentials.
    echo "Please enter your Git user name:"
    read GIT_USER_NAME
    echo "Please enter your Git email address:"
    read GIT_EMAIL

    # Check if the user has entered both a name and an email.
    if [[ -n $GIT_USER_NAME && -n $GIT_EMAIL ]]; then
        git config --global user.name "$GIT_USER_NAME"
        git config --global user.email $GIT_EMAIL
        echo "Git global configuration updated."
    else
        echo "Git global configuration not updated. Please ensure to provide both name and email."
    fi

    get_user_response "Do you want to setup 'main' as the default branch?"
    if [[ $USER_RESPONSE = "y" ]]; then
        git config --global init.defaultBranch main
    else
        echo "Skipped setup of default branch"
    fi
    echo "You setup your git settings successfully!"
else
    echo "Skipping Git setup."
fi



# Ask if the user wants to generate an SSH key.
get_user_response "Do you want to generate a new SSH key for Git?"
if [[ $USER_RESPONSE = "y" ]]; then
    echo "Please enter a email for the SSH key:"
    read SSH_EMAIL

    echo "Please enter a name for storing the SSH key:"
    read SSH_KEY_NAME

    # Generate the SSH key.
    ssh-keygen -t rsa -b 4096 -C "$SSH_EMAIL" -f ~/.ssh/"$SSH_KEY_NAME"

    # Ensure the ssh-agent is running and add the new SSH key to it.
    eval "$(ssh-agent -s)"
    ssh-add ~/.ssh/"$SSH_KEY_NAME"

    # Display the public key.
    echo "Here is your public SSH key, which is saved under ~/.ssh/"
    cat ~/.ssh/"$SSH_KEY_NAME".pub

    echo "Xclip will be downloaded to paste your public SSH key to the clipboard"
    sudo dnf install xclip
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
get_user_response "Will this computer be used for remote sessions? This will enable Xorg by default because it works better with remote sessions"

if [[ $USER_RESPONSE = "y" ]]; then
    # Set GNOME to use Xorg for the next sessions.
    sudo tee /etc/gdm/custom.conf <<EOL
# GDM configuration storage
[daemon]
# Uncomment the line below to force the login screen to use Xorg
WaylandEnable=false
EOL
    echo "Xorg will be used for future sessions."
else
    echo "No changes made to the display server settings."
fi



# Update the system
sudo dnf update -y


# Install important packages

sudo dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm --allowerasing
sudo dnf -y install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm --allowerasing
sudo dnf -y install ffmpeg --allowerasing
sudo dnf -y install ffmpeg-devel --allowerasing

# UI tweaks
sudo dnf -y install gnome-tweaks

sudo dnf install nautilus-python python3-gobject
git clone https://github.com/chr314/nautilus-copy-path.git
cd nautilus-copy-path
make install
nautilus -q
cd ..

# Application runtimes
sudo dnf -y install flatpak snapd nodejs
sudo flatpak -y remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
sudo flatpak -y install flathub

# Dev Tools
sudo dnf -y install @development-tools htop 
sudo flatpak -y install com.getpostman.Postman

# Network Tools
sudo dnf -y install ufw curl wget 

# Multimedia 
sudo dnf -y remove firefox
sudo flatpak -y install org.videolan.VLC org.gimp.GIMP org.chromium.Chromium org.mozilla.firefox org.mozilla.Thunderbird



# Install Docker
sudo dnf -y remove docker \
                    docker-client \
                    docker-client-latest \
                    docker-common \
                    docker-latest \
                    docker-latest-logrotate \
                    docker-logrotate \
                    docker-selinux \
                    docker-engine-selinux \
                    docker-engine
sudo dnf -y install dnf-plugins-core
sudo dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
sudo dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

# Enable Docker on Start
sudo systemctl start docker
sudo systemctl enable docker.service
sudo systemctl containerd.service

# Enable Docker rootless
sudo groupadd docker
sudo usermod -aG docker $USER
sudo newgrp docker



# Install VS Code
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'echo -e "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc" > /etc/yum.repos.d/vscode.repo'
sudo dnf check-update
sudo dnf install -y code

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

if [ "$install_vscode" = "y" ]; then
    echo "User chose to install VS Code extensions. Proceeding..."

    if [ "$install_python_extensions" = "y" ]; then
        echo "Installing Python extensions..."
        for extension in "${PYTHON_EXTENSIONS[@]}"; do
            code --install-extension $extension
        done
    fi

    if [ "$install_ssh_extensions" = "y" ]; then
        echo "Installing Python extensions..."
        for extension in "${SSH_EXTENSIONS[@]}"; do
            code --install-extension $extension
        done
    fi

    if [ "$install_docker_extensions" = "y" ]; then
        echo "Installing Python extensions..."
        for extension in "${DOCKER_EXTENSIONS[@]}"; do
            code --install-extension $extension
        done
    fi
    
    if [ "$install_java_extensions" = "y" ]; then
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
sudo dnf clean all


# Enable minimize and maximize buttons on window title bars in GNOME.
gsettings set org.gnome.desktop.wm.preferences button-layout 'appmenu:minimize,maximize,close'

rm -R ~/initFedora
echo "Initialization completed."
read -n 1 -s -r -p "Press any key to close the terminal..."