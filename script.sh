gpg_url="https://www.gnupg.org/ftp/gcrypt/gnupg/gnupg-1.4.19.tar.bz2"
keyfile="/tmp/key"

boot_2_usb()
{
    local number=1
    local device_partition=$usb_device$number
    local tmpfile=$(mktemp)
    
    for n in /dev/$usb_device* ; do umount $n; done
    dd if=/dev/zero of=/dev/$usb_device count=1000 bs=1024 2>/dev/null

    echo -e "o\nn\np\n1\n\n\nw" | fdisk /dev/$usb_device 2>/dev/null
    mkfs.ext4 -q /dev/$device_partition
    mkdir /tmp/new_boot 2>/dev/null
    mount /dev/$device_partition /tmp/new_boot
    cd /boot && cp -ax . /tmp/new_boot

    sed '/\/boot/d' /etc/fstab > $tmpfile
    cat $tmpfile > /etc/fstab
    
    local uuid=$(blkid -oexport /dev/$device_partition | sed -n 's/^UUID=//p')
    printf "%s\t%s\t%s\t%s" "UUID=$uuid" "/boot" "ext4" "defaults" >> /etc/fstab
    
    grub-install /dev/$device_partition
}


create_key_file()
{
    dd if=/dev/urandom of=$keyfile count=1 bs=8192 2>/dev/null
    /tmp/gpg --passphrase $1 --symmetric $keyfile 2>/dev/null
}


check_device_usb()
{
    local removable=$(cat /sys/block/$1/removable)
    if [[ $removable -eq 0 ]]; then
        echo "Specfied USB device is probably not a USB device.."
        return -1
    fi
}


fix_gpg()
{
    if hash curl 2>/dev/null; then
        curl $gpg_url -o gnupgp.tar.bz2 2>/dev/null
    elif hash wget 2>/dev/null; then
        wget $gpg_url -O gnupgp.tar.bz2 2>/dev/null
    else
        return -1
    fi

    if [ $? -ne 0 ]; then
        echo "gnupg download failed."
        return -1
    fi

    tar -xf gnupgp.tar.bz2 && cd gnupg-1.4.19 && ./configure CFLAGS="-static"
    make -j2 && cp g10/gpg /tmp && chmod +x /tmp/gpg 
}


get_password()
{
    echo -n "Enter your keyfile passphrase [ENTER]: "
    read -s keyfile_passphrase_1
    echo -n -e "\nEnter your keyfile passphrase again [ENTER]: "
    read -s keyfile_passphrase_2
    echo

    if [ $keyfile_passphrase_1 != $keyfile_passphrase_2 ]; then
        echo -e "Passwords are not equal!"
        get_password
    fi
}



check_dependacies()
{
    local required="cryptsetup gcc curl update-initramfs"
    for r in $required; do
        if ! type "$r" > /dev/null; then
            exit -1
        fi
    done
}

check_device()
{
    if [ ! -b $1 ]; then
        echo "Device ($1) not found!"
        return -1
    fi

    dmsetup info $1 &> /dev/null
    if [ $? -ne 0 ]; then
        echo "That drive is not encrypted"
        return -1
    fi
}

cat  << EOF
    Add 2-factor authentication, full disk encryption with dm-crypt/LUKS
    by booting from encrypted keyfile available on a USB key.

    This script will create a bootable USB key, with a modified initramfs
    image which includes a custom initramfs rom, GPG, and a keyfile.

    The unencrypted keyfile will be only available in RAM, and passed to
    cryptsetup on boot.

    This script will make the following changes to your system:
        - Reformat and install grub2 on an inserted USB key
        - Move the /boot mount point to the USB key
        - Modify the initramfs image to include gpg
        - Generate and store a keyfile on the USB key
        - Modify the initramfs cryptroot script to:
            1) ask for a passphrase to decrypt the keyfile with gpg
            2) pass the unecrypted keyfile to crpytsetup
        - Remove the passphrase via LUKS, leaving only the keyfile
        
EOF

if [ $(id -u) -ne 0 ]; then
    echo "You must be root to run this script" && exit -1
fi

check_dependacies
check_device /dev/sda

echo -n "Enter usb block device (ex: sdb): "
read usb_device

check_device_usb $usb_device
get_password
passphrase=$keyfile_passphrase_2
create_key_file $passphrase
#fix_gpg


