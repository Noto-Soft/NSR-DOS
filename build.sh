add_to_disk() {
  	disk_image="$1"
  	shift
  	for file in "$@"; do
    	python3 tools/thinfs.py add "$disk_image" "$file"
  	done
}

mkdir -p build

nasm src/boot.asm -f bin -o build/boot.bin
nasm src/kernel.asm -f bin -o build/kernel.sys
nasm src/command.asm -f bin -o build/command.exe
nasm src/helloworld.asm -f bin -o build/helloworld.exe
nasm src/graphix.asm -f bin -o build/graphix.exe

python3 tools/thinfs.py createbootable nsr-dos.img build/boot.bin NSRDOS
add_to_disk nsr-dos.img \
  	build/kernel.sys \
  	assets/text/boot.txt \
  	build/command.exe \
  	build/helloworld.exe \
  	assets/text/aldi.txt \
  	build/graphix.exe \
  	assets/images/nsrdos.bmp \
  	assets/images/wisconsin.bmp \
  	assets/images/meme.bmp
truncate -s 1440k nsr-dos.img

nasm src/basic.asm -f bin -o build/basic.exe
nasm src/heaptest.asm -f bin -o build/heaptest.exe -w-zeroing
python3 tools/thinfs.py create disk-2.img BDRIVE
add_to_disk disk-2.img \
	assets/text/bdrive.txt \
	build/basic.exe \
	build/heaptest.exe \
	assets/text/gg.txt \
	$(find docs/ -maxdepth 1 -type f -print)
truncate -s 1440k disk-2.img

rm -rf build/

qemu-system-i386 -monitor stdio \
	-drive file=nsr-dos.img,if=floppy,format=raw \
	-drive file=disk-2.img,if=floppy,format=raw \
	-machine pcspk-audiodev=spk \
	-audiodev alsa,id=spk