#!/bin/sh
# File stat helper for polling mode.
# $1 = file path. Outputs mtime:size:inode token, or "missing".
[ ! -e "$1" ] && echo missing && exit 0
stat -Lc '%Y:%s:%i' "$1" 2>/dev/null && exit 0
stat -c '%Y:%s:%i' "$1" 2>/dev/null && exit 0
echo present
