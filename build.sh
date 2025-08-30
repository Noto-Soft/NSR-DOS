#!/bin/bash

SAVE_TEMPS=false
JUST_TEST=false
NO_TEST=false
WINDOWS=false
for arg in "$@"; do
	if [ "$arg" = "-save-temps" ]; then
		SAVE_TEMPS=true
	elif [ "$arg" = "-t" ]; then
		JUST_TEST=true
	elif [ "$arg" = "-w" ]; then
		WINDOWS=true
	elif [ "$arg" = "-n" ]; then
		NO_TEST=true
	fi
done

add_to_disk() {
	disk_image="$1"
	shift
	for file in "$@"; do
		python3 tools/thinfs.py add "$disk_image" "$file"
	done
}

convert_images() {
    input_dir="assets/images/convert8bpp"
    output_dir="build/bitmaps"
    mkdir -p "$output_dir"

    for file in "$input_dir"/*.bmp; do
        filename=$(basename "$file")
        python3 tools/bmp_to_nsbmp.py "$file" "$output_dir/$filename"
    done

	input_dir="assets/images/convert4bpp"

    for file in "$input_dir"/*.bmp; do
        filename=$(basename "$file")
        python3 tools/bmp_to_nsbmp.py "$file" "$output_dir/$filename" -s
    done

	input_dir="assets/images/convert1bpp"

    for file in "$input_dir"/*.bmp; do
        filename=$(basename "$file")
        python3 tools/bmp_to_nsbmp.py "$file" "$output_dir/$filename" -m
    done

	input_dir="assets/images/convert2bpp"

    for file in "$input_dir"/*.bmp; do
        filename=$(basename "$file")
        python3 tools/bmp_to_nsbmp.py "$file" "$output_dir/$filename" -t
    done
}

catza() {
	cat "$@"
	printf '\0'
}

assemble() {
    while [ $# -gt 0 ]; do
        infile="$1"
        shift
        outfile=""

        # Default extension is .exe
        ext=".exe"

        # If next arg starts with "-e", override extension
        if [ $# -gt 0 ] && [[ "$1" =~ ^-e ]]; then
            ext=".${1#-e}"
            shift
        fi

        # Build output path
        base=$(basename "$infile" .asm)
        outfile="build/$base$ext"

        fasm "$infile" "$outfile"
    done
}

if [ "$JUST_TEST" = false ]; then
	mkdir -p build
	mkdir -p build/bitmaps

	assemble \
		src/bootloader/boot.asm -ebin \
		src/kernel/kernel.asm -esys \
		src/kernel/command.asm -esys \
		src/kernel/unreal.asm -esys \
		src/misc/helloworld.asm \
		src/misc/graphix.asm \
		src/misc/basic.asm \
		src/misc/allocator.asm \
		src/misc/chkhdr.asm \
		src/misc/shell.asm \
		src/misc/music.asm \
		src/misc/keystrk.asm \
		src/misc/shapez.asm

	catza assets/text/boot/logo.txt >> build/kernel.sys
	catza assets/text/boot/text.txt >> build/kernel.sys
	cat build/boot.bin >> build/chkhdr.exe

	python3 tools/thinfs.py createbootable nsr-dos.img build/boot.bin NSRDOS
	add_to_disk nsr-dos.img \
		build/kernel.sys \
		build/command.sys \
		build/unreal.sys \
		build/helloworld.exe \
		build/allocator.exe \
		build/shell.exe \
		build/chkhdr.exe \
		build/keystrk.exe \
		build/shapez.exe \
		build/music.exe \
		$(find assets/speaker_music -maxdepth 1 -type f) \
		assets/text/semi.txt
	truncate -s 1440k nsr-dos.img

	cp assets/images/preconverted/* build/bitmaps
	convert_images

	python3 tools/thinfs.py create disk-2.img BDRIVE
	add_to_disk disk-2.img \
		build/basic.exe \
		build/graphix.exe \
		$(find build/bitmaps/ -type f)
	truncate -s 1440k disk-2.img

	if [ "$SAVE_TEMPS" = false ]; then
		rm -rf build/
	fi
fi

if [ "$NO_TEST" = false ]; then
	if [ "$WINDOWS" = true ]; then
		qemu-system-i386.exe \
			-drive file=A:/Noto-Soft/NSR-DOS/nsr-dos.img,if=floppy,format=raw \
			-drive file=disk-2.img,if=floppy,format=raw \
			-machine pcspk-audiodev=spk \
			-audiodev sdl,id=spk \
			
	else
		qemu-system-i386 \
			-monitor stdio \
			-cpu 486 \
			-m 8M \
			-drive file=nsr-dos.img,if=floppy,format=raw \
			-drive file=disk-2.img,if=floppy,format=raw \
			-machine pcspk-audiodev=spk \
			-audiodev alsa,id=spk \

	fi
fi
