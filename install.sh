#!/usr/bin/env bash
# =============================================================================
# Dotfiles Installation Script
# =============================================================================
#
# Quick install (after cloning):
#   ./install.sh
#
# Or one-liner from GitHub:
#   cd && git clone https://github.com/YOUR_USERNAME/dotfiles .dotfiles && .dotfiles/install.sh
#
# =============================================================================

# Change pwd to directory containing this script
BASEDIR="$(dirname "$0")"
cd "$BASEDIR"



### Support Functions

# Regular Colors
Black='\033[0;30m'        # Black
Red='\033[0;31m'          # Red
Green='\033[0;32m'        # Green
Yellow='\033[0;33m'       # Yellow
Blue='\033[0;34m'         # Blue
Purple='\033[0;35m'       # Purple
Cyan='\033[0;36m'         # Cyan
White='\033[0;37m'        # White

UBlack='\033[4;30m'       # Black
URed='\033[4;31m'         # Red
UGreen='\033[4;32m'       # Green
UYellow='\033[4;33m'      # Yellow
UBlue='\033[4;34m'        # Blue
UPurple='\033[4;35m'      # Purple
UCyan='\033[4;36m'        # Cyan
UWhite='\033[4;37m'       # White

BBlack='\033[1;30m'       # Black
BRed='\033[1;31m'         # Red
BGreen='\033[1;32m'       # Green
BYellow='\033[1;33m'      # Yellow
BBlue='\033[1;34m'        # Blue
BPurple='\033[1;35m'      # Purple
BCyan='\033[1;36m'        # Cyan
BWhite='\033[1;37m'       # White

NC='\033[0m'

function echo_and_exec {
  printf "${Blue}RUNNING: ${UBlue}"
  echo -n "$*"
  printf "${NC}\n"
  "$@"
}

function die {
  printf "${BRed}"
  echo -n "$*" 1>&2
  printf "${NC}\n"
  exit 1
}

function prompt {
  printf "${Blue}"
  echo -n "$*"
  printf "${NC}\n"
}

function question {
  echo -n "$* (y/n): "
  read -r ans
  test \( "$ans" = "" \) -o \( "$ans" = "y" \)
}

# Install $1 to location $2, backup if $2 exists already
function install_and_backup {
  src=$1
  dest=$2
  
  # Check if source file exists in BASEDIR
  src_path="$BASEDIR/$src"
  [ -e "$src_path" ] || die "No $src found in $BASEDIR"
  
  [ -z "$dest" ] && dest="$HOME/$src"

  # Resolve absolute path of source
  src_abs=$(realpath "$src_path")
  mkdir -p "$(dirname "$dest")"

  if [ -e "$dest" ]
  then
    mv "$dest" "$dest.pre.install"
    prompt "Existing $dest backed up to $dest.pre.install"
  fi

  ln -s "$src_abs" "$dest" || die "Failed to create symlink"
  prompt "Created symlink $dest -> $src_abs"
}



### 0. OS Specific Stuff
if [[ "$OSTYPE" == "darwin"* ]]
then
  if ! xcode-select -p 1> /dev/null
  then
    xcode-select --install
    die "Install macOS developer tool first"
  fi

  echo '# iterm' >> "$HOME/.zshrc.local"
  echo 'test -e "${HOME}/.iterm2_shell_integration.zsh" && source "${HOME}/.iterm2_shell_integration.zsh"' >> "$HOME/.zshrc.local"

  prompt "Skipped Installing Homebrew"
  # /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
elif [[ "$OSTYPE" == "linux-gnu"* ]]
then
  prompt "skipped Installing neovim"
#   curl -fsSL https://github.com/neovim/neovim/releases/latest/download/nvim.appimage --create-dirs -o "/tmp/nvim.appimage" || die
#   chmod u+x "/tmp/nvim.appimage"
#   mkdir -p "$HOME/.local/bin"
#   ( cd "$HOME/.local" && /tmp/nvim.appimage --appimage-extract > /dev/null && mv squashfs-root neovim )
#   ln -s $HOME/.local/neovim/AppRun $HOME/.local/bin/nvim
fi



### 1. Install Dependencies

## Using system package manager
prompt "Installing Dependencies..."
deb_packages="coreutils zsh vim tmux git curl dnsutils wget python3 fonts-powerline python3-pip"
rpm_packages="coreutils zsh vim tmux git curl dnsutils wget python3 powerline-fonts python3-pip"
homebrew_packages="iterm2 homebrew/cask-fonts/font-meslo-for-powerline coreutils zsh vim neovim tmux wget python3"

if command -v sudo > /dev/null
then
  privileged_runner="sudo"
elif command -v dzdo > /dev/null
then
  privileged_runner="dzdo"
elif [[ "$OSTYPE" != "darwin"* ]]
then
  die "No supported privileged runner found"
fi

if command -v brew > /dev/null
then
  echo_and_exec brew install $homebrew_packages || die
elif command -v dnf > /dev/null
then
  echo_and_exec $privileged_runner dnf install -y $rpm_packages || die
elif command -v yum > /dev/null
then
  echo_and_exec $privileged_runner yum install -y $rpm_packages || die
elif command -v apt > /dev/null
then
  echo_and_exec $privileged_runner apt update
  echo_and_exec $privileged_runner apt install -y $deb_packages || die
else
  die "No supported package manager found, you'll have to install $packages manually!"
fi

## Custom installed dependencies
# prompt "Installing oh-my-zsh"
# CHSH=no RUNZSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" || die "Installation failed"

# prompt "Installing zsh-autosuggestions"
# git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions || die "Installation failed"

# prompt "Installing tpm (Tmux Plugin Manager)"
# git clone https://github.com/tmux-plugins/tpm ~/.tmux/plugins/tpm || die "Installation failed"

# prompt 'Installing vim color scheme "Alduin"'
# curl -fsSL https://github.com/AlessandroYorba/Alduin/raw/master/colors/alduin.vim --create-dirs -o ~/.vim/colors/alduin.vim || die "Installation failed"

# prompt 'Installing vim-plug'
# curl -fsSLLo ~/.vim/autoload/plug.vim --create-dirs https://raw.githubusercontent.com/junegunn/vim-plug/master/plug.vim || die

# prompt "Installing neovim-python"
# pip3 install neovim || die



### 2. Install Configs
if ! question "Is this a server installation? (minimum command line interface)"
then
  echo "export DOTFILES_SERVER=false" >> "$HOME/.zshrc.local"
fi
install_and_backup .zshrc

install_and_backup .gitconfig
install_and_backup .gitignoreglobal

install_and_backup .config/nvim/init.vim
install_and_backup .vimrc
install_and_backup .vim/ftplugin
prompt "Installing vim plugins"
source ~/.zshrc.local
export PATH="$PATH:$HOME/.local/bin"
nvim +PlugInstall +qall || die "Failed to install vim plugins"
nvim +PlugInstall +UpdateRemotePlugins +qall

# ctags config (optional - install 'ctags' package separately if you want to use it)
install_and_backup .ctags

install_and_backup .tmux.conf

install_and_backup .ssh/authorized_keys
install_and_backup .ssh/config

for file in bin/*
do
  install_and_backup "$file" "$HOME/.local/bin/$(basename $file)"
done



### 3. Post-installation reminder
printf "\n${BGreen}========================================${NC}\n"
printf "${BGreen}  Installation Complete!${NC}\n"
printf "${BGreen}========================================${NC}\n\n"
printf "${Yellow}IMPORTANT: You need to configure these files:${NC}\n"
printf "  1. ${Cyan}~/.gitconfig${NC} - Update your name and email\n"
printf "  2. ${Cyan}~/.ssh/config${NC} - Add your SSH hosts\n"
printf "  3. ${Cyan}~/.zshrc.local${NC} - Add machine-specific settings\n"
printf "\nSee the README.md for more details.\n\n"
