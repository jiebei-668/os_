主要实现了IPL（initial program loader）和操作系统内核文件的分文件编写以及自制简易文件系统并初步实现简易DOS
启动本操作系统有是直接将IPL和Kernel代码直接连接到一块
注：到此不理解ipl和mbr区别，文中提到的mbr和ipl都是指bios加载的那512B的文件

- Kernel.asm: 内核源文件
- Loader.asm: ipl程序，其二进制文件Loader.bin需要和Kernel.bin用 ·copy /b Loader.bin+Kernel.bin Boot1.img·直接连接来作为软盘映像
- testReadHd.asm: 一个测试文件，本程序将用来制作硬盘映像启动文件和内核文件，将本程序编译后的二进制文件直接写入硬盘就可以从硬盘启动，内核部分主要是用int 13h中断读取硬盘内容

