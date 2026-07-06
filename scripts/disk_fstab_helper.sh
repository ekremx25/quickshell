#!/usr/bin/env bash
set -euo pipefail

action="${1:-}"
shift || true

backup_fstab() {
  cp /etc/fstab "/etc/fstab.quickshell.bak.$(date +%s)"
}

remove_uuid_from_fstab() {
  local uuid="$1"
  local tmp
  tmp="$(mktemp)"
  grep -Ev "^[[:space:]]*UUID=${uuid}([[:space:]]|$)" /etc/fstab > "$tmp" || true
  cat "$tmp" > /etc/fstab
  rm -f "$tmp"
}

case "$action" in
  bind)
    uuid="${1:?uuid required}"
    mountpoint="${2:?mountpoint required}"
    fstype="${3:?fstype required}"
    opts="${4:?opts required}"

    mkdir -p "$mountpoint"
    if grep -Eq "^[[:space:]]*UUID=${uuid}[[:space:]]" /etc/fstab; then
      mount "$mountpoint" 2>/dev/null || mount -U "$uuid" 2>/dev/null || true
      echo "EXISTS"
      exit 0
    fi

    backup_fstab
    printf '\nUUID=%s %s %s %s 0 0\n' "$uuid" "$mountpoint" "$fstype" "$opts" >> /etc/fstab
    mount "$mountpoint"
    echo "ADDED"
    ;;

  mount)
    uuid="${1:?uuid required}"
    mountpoint="${2:?mountpoint required}"
    mount "$mountpoint" 2>/dev/null || mount -U "$uuid"
    echo "MOUNTED"
    ;;

  unmount-remove)
    uuid="${1:?uuid required}"
    mountpoint="${2:?mountpoint required}"
    devpath="${3:?devpath required}"
    backup_fstab
    umount "$mountpoint" 2>/dev/null || udisksctl unmount -b "$devpath" >/dev/null 2>&1 || umount -l "$mountpoint" 2>/dev/null || true
    remove_uuid_from_fstab "$uuid"
    echo "REMOVED"
    ;;

  unmount)
    mountpoint="${1:?mountpoint required}"
    devpath="${2:?devpath required}"
    umount "$mountpoint" 2>/dev/null || udisksctl unmount -b "$devpath" >/dev/null 2>&1 || umount -l "$mountpoint"
    echo "UNMOUNTED"
    ;;

  *)
    echo "Usage: $0 {bind|mount|unmount-remove|unmount} ..." >&2
    exit 2
    ;;
esac
