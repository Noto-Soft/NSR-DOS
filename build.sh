nasm -o boot.bin -f bin boot.asm
nasm -o kernel.bin -f bin kernel.asm
nasm -o command.exe -f bin command.asm
nasm -o helloworld.exe -f bin helloworld.asm
nasm -o graphix.exe -f bin graphix.asm
./tools/padup.sh boot.bin kernel.bin boot.txt command.exe helloworld.exe graphix.exe nsrdos.bmp > nsr-dos.img
truncate -s 1440k nsr-dos.img
qemu-system-i386 -drive file=nsr-dos.img,if=floppy,format=raw -monitor stdio