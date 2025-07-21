nasm boot.asm -f bin -o boot.bin
nasm kernel.asm -f bin -o kernel.bin
nasm command.asm -f bin -o command.exe
nasm helloworld.asm -f bin -o helloworld.exe
nasm graphix.asm -f bin -o graphix.exe
python3 tools/thinfs.py createbootable nsr-dos.img boot.bin NSRDOS
python3 tools/thinfs.py add nsr-dos.img kernel.bin KERNEL.SYS
python3 tools/thinfs.py add nsr-dos.img boot.txt
python3 tools/thinfs.py add nsr-dos.img command.exe
python3 tools/thinfs.py add nsr-dos.img helloworld.exe
python3 tools/thinfs.py add nsr-dos.img aldi.txt
python3 tools/thinfs.py add nsr-dos.img graphix.exe
python3 tools/thinfs.py add nsr-dos.img nsrdos.bmp
python3 tools/thinfs.py add nsr-dos.img wisconsin.bmp
python3 tools/thinfs.py add nsr-dos.img meme.bmp
truncate -s 1440k nsr-dos.img
python3 tools/thinfs.py create disk-2.img DISK2
python3 tools/thinfs.py add disk-2.img bdrive.txt
truncate -s 1440k disk-2.img
for FILE in docs/*; do
    if [ -f "$FILE" ]; then
        python3 tools/thinfs.py add disk-2.img $FILE
    fi
done
qemu-system-i386 -monitor stdio \
    -drive file=nsr-dos.img,if=floppy,format=raw \
    -drive file=disk-2.img,if=floppy,format=raw \
    # -machine pcspk-audiodev=spk \
    # -audiodev alsa,id=spk