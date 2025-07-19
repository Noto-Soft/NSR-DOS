nasm boot.asm -f bin -o boot.bin
nasm kernel.asm -f bin -o kernel.bin
nasm command.asm -f bin -o command.exe
nasm helloworld.asm -f bin -o helloworld.exe
nasm graphix.asm -f bin -o graphix.exe
python3 tools/thinfs.py create nsr-dos.img boot.bin NSRDOS
python3 tools/thinfs.py add nsr-dos.img kernel.bin KERNEL.SYS
python3 tools/thinfs.py add nsr-dos.img boot.txt
python3 tools/thinfs.py add nsr-dos.img command.exe
python3 tools/thinfs.py add nsr-dos.img helloworld.exe
python3 tools/thinfs.py add nsr-dos.img graphix.exe
python3 tools/thinfs.py add nsr-dos.img nsrdos.bmp
python3 tools/thinfs.py add nsr-dos.img aldi.txt
python3 tools/thinfs.py add nsr-dos.img wisconsin.bmp
qemu-system-i386 -drive file=nsr-dos.img,if=floppy,format=raw -monitor stdio \
    -machine pcspk-audiodev=spk \
    -audiodev alsa,id=spk