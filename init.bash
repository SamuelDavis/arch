# VARIABLES
# #########
TIMEZONE=${TIMEZONE:-"America/New_York"}
ENC=${ENC:-"UTF-8"}
LANG=${LANG:-"en_US"}
HOSTNAME=${HOSTNAME:-"docker-container"}
ROOT_PASSWORD=${ROOT_PASSWORD:-""}
SWAP_SIZE=${SWAP_SIZE:-"4GB"}
USERNAME=${USERNAME:-""}
PASSWORD=${PASSWORD:-""}
NET_NAME=${NET_NAME:-""}
NET_PASS=${NET_PASS:-""}

# SETUP
#######
echo "Setup root dependencies..."

pacman --sync --refresh
# editor
# updating pacman
# internet
# graphics drivers
# visudo for creating users
# bootloader
# package manager
# git
# git friends
pacman --sync --noconfirm --needed \
    vim neovim \
    reflector \
    networkmanager \
    nvidia \
    xf86-video-intel \
    sudo \
    grub efibootmgr os-prober \
    git \
    base-devel

echo "Rebuild kernel..."
mkinitcpio -P

echo "Paralellize Pacman..."
sed -i 's/#Parallel/Parallel/' /etc/pacman.conf

# Timezone
##########
echo "Configure timezone..."

ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
hwclock --systohc


# LOCALE
########
echo "Configure locale..."

echo "$LANG.$ENC $ENC" >> /etc/locale.gen
locale-gen
echo "LANG=$LANG.$ENC" >> /etc/locale.conf

# Networking
############
echo "Configure networking..."

echo $HOSTNAME >> /etc/hostname
echo -e "127.0.0.1\tlocalhost" >> /etc/hosts
echo -e "::1\t\tlocalhost" >> /etc/hosts
echo -e "127.0.1.1\t$HOSTNAME.localdomain\t$HOSTNAME" >> /etc/hosts

if [ -n "$ROOT_PASSWORD" ]; then
    # Root Password
    ###############
    echo "Configure root password..."

    echo "root:$ROOT_PASSWORD" | chpasswd
fi

# Swap File
###########
echo "Configure swap file..."

fallocate -l $SWAP_SIZE /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo "/swapfile none swap defaults 0 0" >> /etc/fstab

# Boot loader
#############
echo "Configure bootloader..."

echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub
grub-install \
--target=x86_64-efi \
--efi-directory=/boot \
--bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

# User interface
################
echo "Install user interface..."

# window manager
# terminal emulator
pacman --sync --noconfirm \
    i3 \
    xterm

# Display Server
################
echo "Install display server..."

# display-server
# setup X systems
# configuring displays
pacman --sync --noconfirm \
    xorg-server \
    xorg-xinit \
    xorg-xrandr

echo "Configure display server..."
Xorg :0 -configure
mv /root/xorg.conf.new /etc/X11/xorg.conf
sed -i 's/Keyboard0/LaptopKeyboard/' /etc/X11/xorg.conf
sed -i 's/Mouse0/LaptopTrackpad/' /etc/X11/xorg.conf
sed -i 's/Monitor0/HDMIMonitor/' /etc/X11/xorg.conf
sed -i 's/Monitor1/LaptopMonitor/' /etc/X11/xorg.conf
sed -i 's/Screen0/HDMIScreen/' /etc/X11/xorg.conf
sed -i 's/Screen1/LaptopScreen/' /etc/X11/xorg.conf
sed -i 's/Card1/IntegratedCard/' /etc/X11/xorg.conf
sed -i 's/Card0/DiscreteCard/' /etc/X11/xorg.conf
nvidia-xconfig -o /etc/X11/xorg.conf.d/20-nvidia.conf
cp /etc/X11/xinit/xinitrc ~/.xinitrc

# Background Services
#####################
echo "Configure background services..."

systemctl enable NetworkManager

if [ -n "$USERNAME" && -n "$PASSWORD" ]; then
    # Add User
    ##########
    echo "Add user..."

    useradd \
        --groups wheel \
        --create-home \
        "$USERNAME"
        echo "$USERNAME:$PASSWORD" | chpasswd
        echo "%wheel ALL=(ALL:ALL) ALL" >> /etc/sudoers.d/100_sudo_include_file

    # Configure User
    ################
    echo "Configuring user..."

    su "$USERNAME" <<'EOF'

    # Connect to Internet
    #####################

    if [ -n "$NET_NAME" && -n "$NET_PASS" ]; then
        nmcli device wifi connect $NET_NAME password $NET_PASS
    fi

    # Dependencies
    ##############
    git clone https://aur.archlinux.org/yay-bin.git $HOME/yay-bin
    cd $HOME/yay-bin
    makepkg --syncdeps --install --clean --noconfirm

    # Appearance
    ############

    # scale the UI
    echo "Xft.dpi: 220" >> ~/.Xresources
    # scale the Terminal
    echo "XTerm*faceName: xft:monospace:pixelsize=24" >> ~/.Xresources

    echo "XTerm*faceName: xft:monospace:pixelsize=24" >> ~/.Xresources
    echo "XTerm*background: black" >> ~/.Xresources
    echo "XTerm*foreground: white" >> ~/.Xresources

EOF
fi

