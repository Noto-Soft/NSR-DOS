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
}

catza() {
	cat "$@"
	printf '\0'
}

if [ "$JUST_TEST" = false ]; then
	mkdir -p build
	mkdir -p build/bitmaps

	fasm src/boot.asm build/boot.bin
	fasm src/kernel.asm build/kernel.sys
	catza assets/text/boot/logo.txt >> build/kernel.sys
	catza assets/text/boot/text.txt >> build/kernel.sys
	fasm src/command.asm build/command.sys
	fasm src/unreal.asm build/unreal.sys
	fasm src/helloworld.asm build/helloworld.exe
	fasm src/graphix.asm build/graphix.exe
	fasm src/basic.asm build/basic.exe
	fasm src/allocator.asm build/allocator.exe
	fasm src/chkhdr.asm build/chkhdr.exe
	cat build/boot.bin >> build/chkhdr.exe
	fasm src/shell.asm build/shell.exe
	fasm src/music.asm build/music.exe

	python3 tools/thinfs.py createbootable nsr-dos.img build/boot.bin NSRDOS
	add_to_disk nsr-dos.img \
		build/kernel.sys \
		build/command.sys \
		build/unreal.sys \
		build/helloworld.exe \
		build/allocator.exe \
		build/shell.exe \
		build/chkhdr.exe \
		build/music.exe \
		$(find assets/speaker_music -maxdepth 1 -type f)
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
