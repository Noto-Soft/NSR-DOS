mkdir -p build

nasm src/boot.asm -f bin -o build/boot.bin
nasm src/kernel.asm -f bin -o build/kernel.bin
nasm src/command.asm -f bin -o build/command.exe
nasm src/helloworld.asm -f bin -o build/helloworld.exe
nasm src/graphix.asm -f bin -o build/graphix.exe

python3 tools/thinfs.py createbootable nsr-dos.img build/boot.bin NSRDOS
python3 tools/thinfs.py add nsr-dos.img build/kernel.bin KERNEL.SYS
python3 tools/thinfs.py add nsr-dos.img assets/text/boot.txt
python3 tools/thinfs.py add nsr-dos.img build/command.exe
python3 tools/thinfs.py add nsr-dos.img build/helloworld.exe
python3 tools/thinfs.py add nsr-dos.img assets/text/aldi.txt
python3 tools/thinfs.py add nsr-dos.img build/graphix.exe
python3 tools/thinfs.py add nsr-dos.img assets/images/nsrdos.bmp
python3 tools/thinfs.py add nsr-dos.img assets/images/wisconsin.bmp
python3 tools/thinfs.py add nsr-dos.img assets/images/meme.bmp
python3 tools/thinfs.py add nsr-dos.img build/heaptest.exe
truncate -s 1440k nsr-dos.img

nasm src/basic.asm -f bin -o build/basic.exe
nasm src/heaptest.asm -f bin -o build/heaptest.exe -w-zeroing
python3 tools/thinfs.py create disk-2.img BDRIVE
python3 tools/thinfs.py add disk-2.img assets/text/bdrive.txt
python3 tools/thinfs.py add disk-2.img build/basic.exe
python3 tools/thinfs.py add disk-2.img build/heaptest.exe
python3 tools/thinfs.py add disk-2.img assets/text/gg.txt
for FILE in docs/*; do
	if [ -f "$FILE" ]; then
		python3 tools/thinfs.py add disk-2.img $FILE
	fi
done
truncate -s 1440k disk-2.img

rm -rf build/

qemu-system-i386 -monitor stdio \
	-drive file=nsr-dos.img,if=floppy,format=raw \
	-drive file=disk-2.img,if=floppy,format=raw \
	-machine pcspk-audiodev=spk \
	-audiodev alsa,id=spk