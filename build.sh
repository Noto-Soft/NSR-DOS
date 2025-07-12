nasme() {
    nasm -o $2 -f bin $1
    echo $2
}

nasme boot.asm boot.bin
nasme kernel.asm kernel.bin
nasme command.asm command.exe
nasme helloworld.asm helloworld.exe
nasme graphix.asm graphix.exe
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