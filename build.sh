nasm -o boot.bin -f bin boot.asm
nasm -o kernel.bin -f bin kernel.asm
nasm -o command.com -f bin command.asm
./padup.sh boot.bin kernel.bin boot.txt command.com > nsr-dos.img
truncate -s 1440k nsr-dos.img
qemu-system-i386 -drive file=nsr-dos.img,if=floppy,format=raw -monitor stdio -cpu 486 -icount shift=3