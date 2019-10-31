#!/usr/bin/env bash

# Read a vault pass from the clipboard and write it to a file on RAM disk. The
# access rights for the file are set so that it is accessible from a deployment
# container.

print_usage_and_exit()
{
    me=$(basename "$0")
    echo
    echo "Usage: $me [options]"
    echo "  where options are"
    echo "  -i vault_id id for the vault file (optional)"
    echo "              this will be appended to the base vaultpass filename"
    echo "              with a separating dash (e.g. /dev/shm/secret/vaultpass-prod)"
    echo "  -h          print this help an exit"
    echo "Example:"
    echo "  $me -i prod"
    echo
    exit 1
}

# Ensure we are running as root and thus can set file access rights correctly:
if [ "$EUID" -ne 0 ]; then
  echo "Please run this script as root so it can set file access rights"
  echo "correctly."
  echo
  echo "The vault pass has NOT been written to RAM disk."
  exit 1
fi

vaultpass_file_name='vaultpass'

# Process options
while getopts "i:h" opt; do
    case $opt in
        i)
            vaultpass_file_name="${vaultpass_file_name}-${OPTARG}"
            ;;
        *)
            print_usage_and_exit
            ;;
    esac
done
shift "$((OPTIND-1))"

# Check the OS
OS="$(uname -s)"

case "${OS}" in
    Darwin*)
        # Create a 10mb RAM disk if it doesn't exist
        if [ ! -d "/Volumes/rRAMDisk" ]; then
            dev=$(hdiutil attach -nomount ram://$((20480)))
            diskutil eraseVolume HFS+ rRAMDisk $dev
        fi
        disk='/Volumes/rRAMDisk'
        ;;
    Linux*)
        disk='/dev/shm'
        ;;
    *)
        echo "Only Darwin and Linux supported"
        exit 1
        ;;
esac

secret_dir="${disk}/secret"
vaultpass_file_path="${secret_dir}/${vaultpass_file_name}"

# Create a directory on ramdisk and change the group to match
# the gid of user 'deployer' in the deployment container
mkdir -p $secret_dir
chmod 750 $secret_dir
chgrp 29295 $secret_dir

# Prepare the password file, chown to deployer
touch $vaultpass_file_path
chmod 640 $vaultpass_file_path
chgrp 29295 $vaultpass_file_path

echo "Make sure the vault pass is in the clipboard, then press enter."
read

case "${OS}" in
    Darwin*)
        # Populate the password from a password manager with pbpaste:
        pbpaste > $vaultpass_file_path

        # Clear the vault pass from the clipboard
        pbcopy < /dev/null
        ;;
    Linux*)
        # SELinux setting
        chcon -Rt svirt_sandbox_file_t $vaultpass_file_path

        # Populate the password from a password manager with xclip:
        xclip -o > $vaultpass_file_path

        # Clear the vault pass from the clipboard
        echo -n "empty" | xclip -selection clipboard
        echo -n "empty" | xclip -selection primary
        echo -n "empty" | xclip -selection secondary
esac

echo "Wrote the vaultpass onto RAM disk to"
echo "   $vaultpass_file_path"
echo "and cleared it from the clipboard."
echo
echo "Happy deployments!"
echo
