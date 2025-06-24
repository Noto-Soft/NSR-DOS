#!/bin/bash
for file in "$@"; do
  if [[ -f "$file" ]]; then
    size=$(stat -c %s "$file")
    pad=$(( (512 - (size % 512)) % 512 ))
    cat "$file"
    if [[ $pad -ne 0 ]]; then
      dd if=/dev/zero bs=1 count=$pad status=none
    fi
  else
    echo "Warning: '$file' is not a regular file or does not exist." >&2
  fi
done