#!/usr/bin/env python3
import sys
import os
import struct

SECTOR_SIZE = 512
INFO_SECTOR_OFFSET = 1
ENTRY_SECTOR_OFFSET = 2
MAX_ENTRIES = 255

def pad(data, size):
    return data + b"\x00" * (size - len(data))

def to_upper_ascii(name):
    return os.path.basename(name).upper()

def create_image(img_name, bootloader_path, fs_name):
    # FS name must be 11 bytes (padded with spaces)
    fs_name = fs_name.upper().ljust(11).encode("ascii")[:11]

    # Read bootloader
    with open(bootloader_path, "rb") as f:
        bootloader = f.read()
    if len(bootloader) > SECTOR_SIZE:
        raise ValueError("Bootloader too large")

    # Prepare image file
    with open(img_name, "wb") as f:
        # Boot sector (sector 0)
        f.write(pad(bootloader, SECTOR_SIZE))

        # Info sector (sector 1)
        f.write(b"\x90\x90")       # Optional short jump
        f.write(fs_name)          # FS name
        f.write(b"\x03")          # number of entry sectors (default: 3)
        f.write(b"\x00" * (SECTOR_SIZE - 2 - 11 - 1))  # pad rest of sector

        # Empty entry sectors (sectors 2–4)
        f.write(b"\x00" * SECTOR_SIZE * 3)

        # Pad with empty sectors to make it at least a few KB
        f.write(b"\x00" * SECTOR_SIZE * 10)  # start of file area

    print(f"[OK] Created {img_name} with FS name '{fs_name.decode().strip()}'")

def add_file(img_name, input_file, output_name=None):
    if not output_name:
        output_name = to_upper_ascii(input_file)
    else:
        output_name = output_name.upper()

    # Read the file to add
    with open(input_file, "rb") as f:
        file_data = f.read()
    file_sectors = (len(file_data) + SECTOR_SIZE - 1) // SECTOR_SIZE

    # Open image
    with open(img_name, "r+b") as f:
        f.seek(SECTOR_SIZE * INFO_SECTOR_OFFSET)
        info_sector = f.read(SECTOR_SIZE)
        num_entry_sectors = info_sector[13]  # 14th byte is number of entry sectors

        # Find next free entry position
        entry_base = ENTRY_SECTOR_OFFSET * SECTOR_SIZE
        f.seek(entry_base)
        entry_data = f.read(num_entry_sectors * SECTOR_SIZE)

        pos = 0
        entries = 0
        while pos < len(entry_data):
            if entry_data[pos] == 0x00:
                break
            filename_length = entry_data[pos + 3]
            pos += 4 + filename_length
            entries += 1

        if entries >= MAX_ENTRIES:
            raise RuntimeError("Too many entries")

        # Compute LBA of next free file sector
        file_area_start = (ENTRY_SECTOR_OFFSET + num_entry_sectors)
        f.seek(0, os.SEEK_END)
        image_size = f.tell()
        next_file_sector = image_size // SECTOR_SIZE
        if next_file_sector < file_area_start:
            next_file_sector = file_area_start

        # Write file at the end
        f.seek(next_file_sector * SECTOR_SIZE)
        f.write(pad(file_data, file_sectors * SECTOR_SIZE))

        # Write entry
        f.seek(entry_base + pos)
        entry = struct.pack("<HBB", next_file_sector, file_sectors, len(output_name) + 1)
        entry += output_name.encode("ascii") + b"\x00"
        f.write(entry)

    print(f"[OK] Added {input_file} as '{output_name}' at LBA {next_file_sector} ({file_sectors} sectors)")

def usage():
    print("Usage:")
    print("  thinfs.py create <image> <bootloader> <fs_name>")
    print("  thinfs.py add <image> <file.in> [FILE.OUT]")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        usage()
        sys.exit(1)

    command = sys.argv[1]

    if command == "create" and len(sys.argv) == 5:
        _, _, img, bootloader, fs_name = sys.argv
        create_image(img, bootloader, fs_name)
    elif command == "add" and (len(sys.argv) == 4 or len(sys.argv) == 5):
        _, _, img, file_in, *rest = sys.argv
        output_name = rest[0] if rest else None
        add_file(img, file_in, output_name)
    else:
        usage()
        sys.exit(1)
