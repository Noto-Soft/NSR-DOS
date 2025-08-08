#!/bin/bash

SAVE_TEMPS=false
for arg in "$@"; do
	if [ "$arg" = "-save-temps" ]; then
		SAVE_TEMPS=true
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
    input_dir="assets/images/convert"
    output_dir="build/bitmaps"
    mkdir -p "$output_dir"

    for file in "$input_dir"/*.bmp; do
        filename=$(basename "$file")
        python3 tools/bmp_to_nsbmp.py "$file" "$output_dir/$filename" -c
    done
}

catza() {
	cat "$@"
	printf '\0'
}

mkdir -p build
mkdir -p build/bitmaps

nasm src/boot.asm -f bin -o build/boot.bin
nasm src/kernel.asm -f bin -o build/kernel.sys
catza assets/text/boot/logo.txt >> build/kernel.sys
catza assets/text/boot/text.txt >> build/kernel.sys
nasm src/command.asm -f bin -o build/command.exe
nasm src/helloworld.asm -f bin -o build/helloworld.exe
nasm src/graphix.asm -f bin -o build/graphix.exe

python3 tools/thinfs.py createbootable nsr-dos.img build/boot.bin NSRDOS
add_to_disk nsr-dos.img \
	build/kernel.sys \
	build/bootmsg.sys \
	build/command.exe \
	build/helloworld.exe \
	build/heaptest.exe \
	build/basic.exe
truncate -s 1440k nsr-dos.img

nasm src/basic.asm -f bin -o build/basic.exe
nasm src/heaptest.asm -f bin -o build/heaptest.exe -w-zeroing

cp assets/images/preconverted/* build/bitmaps
convert_images

python3 tools/thinfs.py create disk-2.img BDRIVE
add_to_disk disk-2.img \
	build/graphix.exe \
	$(find build/bitmaps/ -type f) \
	$(find docs/ -type f)
truncate -s 1440k disk-2.img

if [ "$SAVE_TEMPS" = false ]; then
	rm -rf build/
fi

qemu-system-i386 -monitor stdio \
	-drive file=nsr-dos.img,if=floppy,format=raw \
	-drive file=disk-2.img,if=floppy,format=raw \
	-machine pcspk-audiodev=spk \
	-audiodev alsa,id=spk \
	-vga std
