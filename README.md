# 2-factor authentication with dm-crypt/LUKS

    Add 2-factor authentication, full disk encryption with dm-crypt/LUKS
    by booting from encrypted keyfile available on a USB key.

    This script will create a bootable USB key, with a modified initramfs
    image which includes a custom initramfs rom, GPG, and a keyfile.

    The unencrypted keyfile will be only available in RAM, and passed to
    cryptsetup on boot.

Incomplete code.
