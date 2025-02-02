#!/usr/bin/env bash
#|---/ /+--------------------------------------+---/ /|#
#|--/ /-| System Configuration & Dotfiles Setup|--/ /-|#
#|/ /---+--------------------------------------+/ /---|#

#------------------------------#
# Configurations               #
#------------------------------#
SCR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTS_DIR="${SCR_DIR}/dots/.config"
HOME_FILES="${SCR_DIR}/home"
OPTIONS_DIR="${SCR_DIR}/options"
PKG_DIR="${SCR_DIR}/scripts/pkg_mgmt"
LOG_FILE="${HOME}/.dotfiles_setup_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RESET='\033[0m'

#------------------------------#
# ASCII Art & UI               #
#------------------------------#
show_header() {
    clear
    cat <<"EOF"
  /\_/\           /\\
 ( o.o )  [Dotfiles Setup] 
  > ^ <   [Initializing...] 
   /  \   
  /    \  
EOF
    echo -e "\n${YELLOW}>> Automated System Configuration <<${RESET}\n"
}

#------------------------------#
# Logging System               #
#------------------------------#
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    
    echo -e "[${timestamp}] ${level}: ${message}" >> "${LOG_FILE}"
    
    case "$level" in
        "SUCCESS") echo -e "${GREEN}✓ ${message}${RESET}" ;;
        "WARNING") echo -e "${YELLOW}⚠ ${message}${RESET}" ;;
        "ERROR")   echo -e "${RED}✗ ${message}${RESET}" ;;
        "INFO")    echo -e "${BLUE}ℹ ${message}${RESET}" ;;
    esac
}

#------------------------------#
# Dependency Checks            #
#------------------------------#
check_dependencies() {
    local missing=()
    
    if ! command -v paru &> /dev/null; then
        log_message "ERROR" "Missing paru - install AUR helper first"
        missing+=("paru")
    fi
    
    if ! command -v stow &> /dev/null; then
        log_message "ERROR" "Missing stow - install GNU Stow"
        missing+=("stow")
    fi
    
    [ ${#missing[@]} -eq 0 ] || exit 1
}

#------------------------------#
# Package Installation         #
#------------------------------#
install_packages() {
    log_message "INFO" "Starting package installation"
    
    local pkg_lists=("${PKG_DIR}/base.lst" "${PKG_DIR}/dev.lst" "${PKG_DIR}/gui.lst")
    
    for list in "${pkg_lists[@]}"; do
        if [ ! -f "$list" ]; then
            log_message "ERROR" "Missing package list: ${list}"
            exit 1
        fi
        
        log_message "INFO" "Installing packages from: $(basename ${list})"
        
        while IFS= read -r pkg; do
            [[ "$pkg" =~ ^#|^$ ]] && continue
            
            if paru -S --needed --noconfirm "$pkg" &>> "${LOG_FILE}"; then
                log_message "SUCCESS" "Installed: ${pkg}"
            else
                log_message "ERROR" "Failed to install: ${pkg}"
            fi
        done < "$list"
    done
    
    # Handle AUR packages separately
    log_message "INFO" "Installing AUR packages"
    while IFS= read -r aur_pkg; do
        [[ "$aur_pkg" =~ ^#|^$ ]] && continue
        
        if paru -S --needed --noconfirm "$aur_pkg" &>> "${LOG_FILE}"; then
            log_message "SUCCESS" "Installed AUR: ${aur_pkg}"
        else
            log_message "ERROR" "Failed AUR: ${aur_pkg}"
        fi
    done < "${PKG_DIR}/aur.lst"
}

#------------------------------#
# Hardware Configuration       #
#------------------------------#
configure_hardware() {
    log_message "INFO" "Configuring hardware settings"
    
    # Graphics Driver
    PS3="Select graphics driver: "
    select gfx in "NVIDIA" "AMD/Intel"; do
        case $gfx in
            NVIDIA) 
                cp "${OPTIONS_DIR}/nvidia.conf" "${DOTS_DIR}/hypr/source/nvidia.conf"
                log_message "SUCCESS" "Applied NVIDIA configuration"
                break ;;
            *) 
                cp "${OPTIONS_DIR}/nvidia-dummy.conf" "${DOTS_DIR}/hypr/source/nvidia.conf"
                log_message "SUCCESS" "Applied Open Source driver configuration"
                break ;;
        esac
    done

    # Keyboard Layout
    PS3="Select keyboard layout: "
    select kb in "US" "LATAM"; do
        case $kb in
            US)
                cp "${OPTIONS_DIR}/us.conf" "${DOTS_DIR}/hypr/source/keyboard.conf"
                log_message "SUCCESS" "Applied US keyboard layout"
                break ;;
            LATAM)
                cp "${OPTIONS_DIR}/latam.conf" "${DOTS_DIR}/hypr/source/keyboard.conf"
                log_message "SUCCESS" "Applied LATAM keyboard layout"
                break ;;
        esac
    done
}

#------------------------------#
# Dotfiles Deployment          #
#------------------------------#
deploy_dotfiles() {
    log_message "INFO" "Deploying dotfiles"
    
    # Stow .config files
    if stow -d "${SCR_DIR}/dots" -t "${HOME}" .config; then
        log_message "SUCCESS" "Linked .config directories"
    else
        log_message "ERROR" "Failed to stow .config files"
        exit 1
    fi
    
    # Stow home files
    if stow -d "${SCR_DIR}/home" -t "${HOME}"; then
        log_message "SUCCESS" "Linked home directories"
    else
        log_message "ERROR" "Failed to stow home files"
        exit 1
    fi
}

#------------------------------#
# Post-Install Configuration   #
#------------------------------#
finalize_setup() {
    log_message "INFO" "Finalizing setup"
    
    # User Groups
    for group in input seat video; do
        if sudo usermod -aG "$group" "$USER"; then
            log_message "SUCCESS" "Added user to ${group} group"
        else
            log_message "ERROR" "Failed to add to ${group} group"
        fi
    done
    
    # Font Cache
    if fc-cache -fv &>> "${LOG_FILE}"; then
        log_message "SUCCESS" "Updated font cache"
    else
        log_message "WARNING" "Font cache update failed"
    fi
    
    # TMUX Plugins
    if [ -d "${HOME}/.tmux/plugins/tpm" ]; then
        log_message "INFO" "Installing TMUX plugins"
        bash "${HOME}/.tmux/plugins/tpm/bin/install_plugins" &>> "${LOG_FILE}"
    fi
    
    # Wallpaper Setup
    if command -v matugen &> /dev/null; then
        log_message "INFO" "Applying wallpaper theming"
        matugen image "${SCR_DIR}/Wallpapers/garden.webp" &>> "${LOG_FILE}"
    fi
    
    # Default Shell
    if command -v fish &> /dev/null; then
        sudo chsh -s "$(which fish)" "$USER"
        log_message "SUCCESS" "Set Fish as default shell"
    fi
}

#------------------------------#
# Main Execution Flow          #
#------------------------------#
main() {
    show_header
    check_dependencies
    install_packages
    configure_hardware
    deploy_dotfiles
    finalize_setup
    
    echo -e "\n${GREEN}✓ Setup Complete!${RESET}"
    echo -e "${YELLOW}Log saved to: ${LOG_FILE}${RESET}"
    cat <<"EOF"
  /\_/\
 ( ◕ᴗ◕ )
  /  づづ
 System Ready!
EOF
}

main "$@"
