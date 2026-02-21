#!/bin/bash

# manage_disk.sh
# Usage:
#   list                -> Returns JSON of block devices
#   mount <dev> <point> -> Persistently mounts <dev> to <point> (requires root/pkexec)

ACTION="$1"
DEVICE="$2"
MOUNTPOINT="$3"

if [ "$ACTION" == "list" ]; then
    lsblk -J -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,UUID,LABEL,MODEL
    exit 0
fi

if [ "$ACTION" == "mount" ]; then
    if [ -z "$DEVICE" ] || [ -z "$MOUNTPOINT" ]; then
        echo "Error: Device and Mountpoint required."
        exit 1
    fi

    # Ensure we are root
    if [ "$EUID" -ne 0 ]; then
        echo "Error: Permission denied. Run with pkexec."
        exit 1
    fi

    # 1. Create mount point
    mkdir -p "$MOUNTPOINT"
    if [ $? -ne 0 ]; then
         echo "Error: Failed to create mount point $MOUNTPOINT"
         exit 1
    fi

    # 2. Backup fstab
    cp /etc/fstab /etc/fstab.bak.$(date +%s)

    # 3. Get UUID
    UUID=$(blkid -s UUID -o value "$DEVICE")
    FSTYPE=$(blkid -s TYPE -o value "$DEVICE")

    if [ -z "$UUID" ]; then
        # Fallback to device path if no UUID (risky if device order changes, but valid)
        echo "$DEVICE $MOUNTPOINT $FSTYPE defaults 0 0" >> /etc/fstab
    else
        echo "UUID=$UUID $MOUNTPOINT $FSTYPE defaults 0 0" >> /etc/fstab
    fi

    # 4. Mount
    mount -a
    
    if mountpoint -q "$MOUNTPOINT"; then
        echo "Success: Mounted $DEVICE at $MOUNTPOINT"
        exit 0
    else
        echo "Error: Mount failed even after fstab update."
        # Restore backup? Maybe too aggressive to auto-restore. 
        exit 1
    fi
fi

echo "Usage: $0 {list|mount <device> <point>}"
exit 1
