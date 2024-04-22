all: Boot.img testReadHd.bin
Boot.img: Loader.bin Kernel.bin
	copy /b Loader.bin+Kernel.bin Boot.img
Loader.bin: Loader.asm
	nasm -o Loader.bin Loader.asm
Kernel.bin: Kernel.asm
	nasm -o Kernel.bin Kernel.asm
testReadHd.bin: testReadHd.asm
	nasm -o testReadHd.bin testReadHd.asm