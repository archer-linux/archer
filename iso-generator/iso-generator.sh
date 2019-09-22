#!/usr/bin/env bash

# Stop spellcheck from spamming to declare and assign seperately (not important in our case)
# shellcheck disable=SC2155

###############################################################
### Archer Linux Install Script
### iso-generator.sh
###
### Copyright (C) 2018 Dylan Schacht
### Copyright (C) 2019 MC archer_dev
###
### By: Dylan Schacht (deadhead) 
### Email: deadhead3492@gmail.com
### Webpage: https://archer.sh
###
### By: MC - archer_dev
### Email: root@archer.sh
### Webpage: https://archer.sh
###
### Any questions, comments, or bug reports may be sent to above
### email address. Enjoy, and keep on using Archer.
###
### License: GPL v2.0
###############################################################

# Error codes:
# * Exit 1: Missing dependencies (check_dependencies)
# * Exit 2: Missing Arch iso (update_arch_iso)
# * Exit 3: Missing wget (update_arch_iso)
# * Exit 4: Failed to create iso (create_iso)

# Exit on error
#set -o errexit

# Enable tracing of what gets executed
#set -o xtrace

# Clears the screen and adds a banner
prettify() {
    clear
    echo "-- Archer Linux --"
    echo ""
}

set_version() {
    # Label must be 11 characters long
    archer_iso_label="ARCHERV105" # prev: iso_label
    archer_iso_release="1.0.5" # prev: iso_rel
    archer_iso_name="archer-${archer_iso_release}-${system_architecture}.iso" # prev: version
}

init() {
    # Location variables
    working_dir=$(dirname "$(pwd)") # prev: aa ## This is the pwd, but up one.
    custom_iso="${working_dir}"/customiso # prev: customiso
    squashfs="${custom_iso}"/arch/"${system_architecture}"/squashfs-root # prev: sq

    # Check for existing Arch iso
    if (ls "${working_dir}"/archlinux-*-"${system_architecture}".iso &>/dev/null); then
        local_arch_iso=$(ls "${working_dir}"/archlinux-*-"${system_architecture}".iso | tail -n1 | sed 's!.*/!!') # Outputs Arch iso filename prev: iso
    fi

    # Link to AUR snapshots
    aur_snapshot_link="https://aur.archlinux.org/cgit/aur.git/snapshot/" # prev: aur

    # Packages to add to local repo
    local_aur_packages=( # prev: builds
        'fetchmirrors'
        'numix-icon-theme-git'
        'numix-circle-icon-theme-git'
        'oh-my-zsh-git'
        'opensnap'
        'perl-linux-desktopfiles'
        'obmenu-generator'
        'yay'
    )

    check_dependencies
    update_arch_iso
    local_repo_builds
}

check_dependencies() { #prev: check_depends
    echo "Checking dependencies"

    for current_dependency in $(cat dependencies.txt); do
        pacman -Qi $current_dependency
    if [ "$?" -eq "0" ]; then
        found_dependencies+="$current_dependency " # found_dependencies, in case we need a list of deps present before progressing past this point.
    else
        missing_dependencies+="$current_dependency "
    fi
    done

    if [ -n "$missing_dependencies" ]; then
        echo -en "Missing dependencies: ${missing_dependencies}\n\nInstalling them now"
        sudo pacman -Sy --noconfirm ${missing_dependencies}
    fi
    echo "Done installing packages"
    echo ""
}

update_arch_iso() { # prev: update_iso
    update=false

    # Check for latest Arch Linux iso
    if [[ "${system_architecture}" == "x86_64" ]]; then
        arch_iso_latest=$(curl -s https://www.archlinux.org/download/ | grep "Current Release" | awk '{print $3}' | sed -e 's/<.*//') # prev: archiso_latest
        arch_iso_link="https://mirrors.kernel.org/archlinux/iso/${arch_iso_latest}/archlinux-${arch_iso_latest}-x86_64.iso" # prev: archiso_link
    else
        arch_iso_latest=$(curl -s https://mirror.archlinux32.org/archisos/ | grep -o ">.*.iso<" | tail -1 | sed 's/>//;s/<//')
        arch_iso_link="https://mirror.archlinux32.org/archisos/${arch_iso_latest}"
    fi

    echo "Checking for updated Arch Linux image ..."
    iso_date=$(<<<"${arch_iso_link}" sed 's!.*/!!')
    if [[ "${iso_date}" != "${local_arch_iso}" ]]; then
        if [[ -z "${local_arch_iso}" ]]; then
            echo -en "\nNo Arch Linux image found under ${working_dir}\n\n. Downloading it now: "
            update=true
        else
            echo -en "Updated Arch Linux image available: ${arch_iso_latest}\n. Downloading it now "
            update=true
        fi

        if "${update}" ; then
            cd "${working_dir}" || exit
            echo ""
            echo "Downloading Arch Linux image ..."
            echo "(Don't resize the window or it will mess up the progress bar)"
            wget -c -q --show-progress "${arch_iso_link}"
            if [[ "$?" -gt "0" ]]; then
                echo "Error: You need 'wget' to download the image, exiting."
                exit 3
            fi
            local_arch_iso=$(ls "${working_dir}"/archlinux-*-"${system_architecture}".iso | tail -n1 | sed 's!.*/!!')
        fi
    fi
    echo "Done"
    echo ""
}

local_repo_builds() { # prev: aur_builds
    # Update pacman databases
    sudo pacman -Sy --noconfirm

    echo "Building AUR packages for local repo ..."

    # Begin build loop checking /tmp for existing builds, then build packages & install if required
    for pkg in $(echo "${local_aur_packages[@]}"); do
        wget -qO- "${aur_snapshot_link}/${pkg}.tar.gz" | tar xz -C /tmp
        cd /tmp/"${pkg}" || exit
         makepkg -si --noconfirm --nocheck
    done

    echo "Done"
    echo ""
}

extract_arch_iso() { # prev: extract_iso
    cd "${working_dir}" || exit

    if [[ -d "${custom_iso}" ]]; then
        sudo rm -rf "${custom_iso}"
    fi

    echo "Extracting Arch Linux image ..."

    # Extract Arch iso to mount directory and continue with build
    7z x "${local_arch_iso}" -o"${custom_iso}"

    echo "Done"
    echo ""
}

copy_config_files() { # prev: build_conf
    # Change directory into the iso, where the filesystem is stored.
    # Unsquash root filesystem 'airootfs.sfs', this creates a directory 'squashfs-root' containing the entire system
    echo "Unsquashing ${system_architecture} image ..."
    cd "${custom_iso}"/arch/"${system_architecture}" || exit
    sudo unsquashfs airootfs.sfs
    echo "Done"
    echo ""

    echo "Copying Archer files ..."
    # Copy over vconsole.conf (sets font at boot), locale.gen (enables locale(s) for font) & uvesafb.conf
    sudo cp "${working_dir}"/etc/vconsole.conf "${working_dir}"/etc/locale.gen "${squashfs}"/etc/
    sudo fakechroot "${squashfs}" /bin/bash locale-gen

    # Copy over main Archer config and installer script, make them executable
    sudo cp "${working_dir}"/etc/archer.conf "${squashfs}"/etc/
    sudo cp "${working_dir}"/archer-installer.sh "${squashfs}"/usr/bin/archer
    sudo cp "${working_dir}"/extra/sysinfo "${working_dir}"/extra/iptest "${squashfs}"/usr/bin/
    sudo chmod +x "${squashfs}"/usr/bin/archer "${squashfs}"/usr/bin/sysinfo "${squashfs}"/usr/bin/iptest

    # Create Archer and lang directories, copy over all lang files
    sudo mkdir -p "${squashfs}"/usr/share/archer/lang "${squashfs}"/usr/share/archer/extra "${squashfs}"/usr/share/archer/boot "${squashfs}"/usr/share/archer/etc
    sudo cp "${working_dir}"/lang/* "${squashfs}"/usr/share/archer/lang/

    # Create shell function library, copy /lib to squashfs-root
    sudo mkdir "${squashfs}"/usr/lib/archer
    sudo cp "${working_dir}"/lib/* "${squashfs}"/usr/lib/archer/

    # Copy over extra files (dotfiles, desktop configurations, help file, issue file, hostname file)
    sudo rm "${squashfs}"/root/install.txt
    sudo cp "${working_dir}"/extra/shellrc/.zshrc "${squashfs}"/root/
    sudo cp "${working_dir}"/extra/.help "${working_dir}"/extra/.dialogrc "${squashfs}"/root/
    sudo cp "${working_dir}"/extra/shellrc/.zshrc "${squashfs}"/etc/zsh/zshrc
    sudo cp -r "${working_dir}"/extra/shellrc/. "${squashfs}"/usr/share/archer/extra/
    sudo cp -r "${working_dir}"/extra/desktop "${working_dir}"/extra/wallpapers "${working_dir}"/extra/fonts "${working_dir}"/extra/archer-icon.png "${squashfs}"/usr/share/archer/extra/
    cat "${working_dir}"/extra/.helprc | sudo tee -a "${squashfs}"/root/.zshrc >/dev/null
    sudo cp "${working_dir}"/etc/hostname "${working_dir}"/etc/issue_cli "${working_dir}"/etc/lsb-release "${working_dir}"/etc/os-release "${squashfs}"/etc/
    sudo cp -r "${working_dir}"/boot/splash.png "${working_dir}"/boot/loader/ "${squashfs}"/usr/share/archer/boot/
    sudo cp "${working_dir}"/etc/nvidia340.xx "${squashfs}"/usr/share/archer/etc/

    # Copy over built packages and create repository
    sudo mkdir "${custom_iso}"/arch/"${system_architecture}"/squashfs-root/usr/share/archer/pkg

    for pkg in $(echo "${local_aur_packages[@]}"); do
        sudo cp /tmp/"${pkg}"/*.pkg.tar.xz "${squashfs}"/usr/share/archer/pkg/
    done

    cd "${squashfs}"/usr/share/archer/pkg || exit
    sudo repo-add archer-local.db.tar.gz *.pkg.tar.xz
    echo -e "\n[archer-local]\nServer = file:///usr/share/archer/pkg\nSigLevel = Never" | sudo tee -a "${squashfs}"/etc/pacman.conf >/dev/null
    cd "${working_dir}" || exit

    if [[ "${system_architecture}" == "i686" ]]; then
        sudo rm -r "${squashfs}"/root/.gnupg
        sudo rm -r "${squashfs}"/etc/pacman.d/gnupg
        sudo linux32 fakechroot "${squashfs}" dirmngr </dev/null
        sudo linux32 fakechroot "${squashfs}" pacman-key --init
        sudo linux32 fakechroot "${squashfs}" pacman-key --populate archlinux32
        sudo linux32 fakechroot "${squashfs}" pacman-key --refresh-keys
    fi
    echo "Done"
    echo ""
}

build_system() { # prev: build_sys
    echo "Installing packages to new system ..."
    # Install fonts, fbterm, fetchmirrors etc.
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -Sy terminus-font acpi zsh-syntax-highlighting pacman-contrib
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -U /tmp/fetchmirrors/*.pkg.tar.xz
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" -Sl | awk '/\[installed\]$/ {print $1 "/" $2 "-" $3}' > "${custom_iso}"/arch/pkglist."${system_architecture}".txt
    sudo pacman --root "${squashfs}" --cachedir "${squashfs}"/var/cache/pacman/pkg  --config "${pacman_config}" --noconfirm -Scc
    sudo rm -f "${squashfs}"/var/cache/pacman/pkg/*
    echo "Done"
    echo ""

    # cd back into root system directory, remove old system
    cd "${custom_iso}"/arch/"${system_architecture}" || exit
    rm airootfs.sfs

    # Recreate the iso using compression, remove unsquashed system, generate checksums
    echo "Recreating ${system_architecture} image ..."
    sudo mksquashfs squashfs-root airootfs.sfs -b 1024k -comp xz
    sudo rm -r squashfs-root
    md5sum airootfs.sfs > airootfs.md5
    echo "Done"
    echo ""
}

configure_boot() {
    echo "Configuring boot ..."
    arch_iso_label=$(<"${custom_iso}"/loader/entries/archiso-x86_64.conf awk 'NR==6{print $NF}' | sed 's/.*=//')
    arch_iso_hex=$(<<<"${arch_iso_label}" xxd -p)
    archer_iso_hex=$(<<<"${archer_iso_label}" xxd -p)
    cp "${working_dir}"/boot/splash.png "${custom_iso}"/arch/boot/syslinux/
    cp "${working_dir}"/boot/iso/archiso_head.cfg "${custom_iso}"/arch/boot/syslinux/
    sed -i "s/${arch_iso_label}/${archer_iso_label}/;s/Arch Linux archiso/Archer Linux/" "${custom_iso}"/loader/entries/archiso-x86_64.conf
    sed -i "s/${arch_iso_label}/${archer_iso_label}/;s/Arch Linux/Archer Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_sys.cfg
    sed -i "s/${arch_iso_label}/${archer_iso_label}/;s/Arch Linux/Archer Linux/" "${custom_iso}"/arch/boot/syslinux/archiso_pxe.cfg
    cd "${custom_iso}"/EFI/archiso/ || exit
    echo -e "Replacing label hex in efiboot.img...\n${arch_iso_label} ${arch_iso_hex} > ${archer_iso_label} ${archer_iso_hex}"
    xxd -c 256 -p efiboot.img | sed "s/${arch_iso_hex}/${archer_iso_hex}/" | xxd -r -p > efiboot1.img
    if ! (xxd -c 256 -p efiboot1.img | grep "${archer_iso_hex}" &>/dev/null); then
        echo "\nError: failed to replace label hex in efiboot.img"
        echo "Press any key to continue." ; read input
    fi
    mv efiboot1.img efiboot.img
    echo "Done"
    echo ""
}

create_iso() {
    echo "Creating new Archer Linux image ..."
    cd "${working_dir}" && mkdir build && cd build || exit
    xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "${archer_iso_label}" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr customiso/isolinux/isohdpfx.bin \
    -eltorito-alt-boot \
    -e EFI/archiso/efiboot.img \
    -no-emul-boot -isohybrid-gpt-basdat \
    -output "${archer_iso_name}" \
    "${custom_iso}"

    if [[ "$?" -eq "0" ]]; then
        rm -rf "${custom_iso}"
        generate_checksums
    else
        echo "Error: Image creation failed, exiting."
        exit 4
    fi
}

generate_checksums() {
    echo "Generating image checksums..."
    local sha_256_sum=$(sha256sum "${archer_iso_name}")
    echo "${sha_256_sum}" > "${archer_iso_name}".sha256sum
    echo "Done"
    echo ""
}

usage() {
    clear
    echo "Usage: iso-generator.sh [architecture]"
    echo "  --i686)     create i686 (32-bit) installer"
    echo "  --x86_64)   create x86_64 (64-bit) installer (default)"
    echo ""
}

if (<<<"$@" grep "\-\-i686" >/dev/null); then
    system_architecture=i686 # prev: sys
    pacman_config=etc/i686-pacman.conf # prev: paconf
    sudo wget "https://raw.githubusercontent.com/archlinux32/packages/master/core/pacman-mirrorlist/mirrorlist" -O /etc/pacman.d/mirrorlist32
    sudo sed -i 's/#//' /etc/pacman.d/mirrorlist32
else
    system_architecture=x86_64
    pacman_config=/etc/pacman.conf
fi

while (true); do
    case "$1" in
        --i686|--x86_64)
            shift
        ;;
        -h|--help)
            usage
            exit 0
        ;;
        *)
            prettify
            set_version
            init
            extract_arch_iso
            copy_config_files
            build_system
            configure_boot
            create_iso
            echo "${archer_iso_name} image generated successfully."
            exit 0
        ;;
    esac
done

# vim: ai:ts=4:sw=4:et
