主要实现了IPL（initial program loader）和操作系统内核文件的分文件编写。
启动本操作系统有两种方式，一是制作标准fat12格式软盘映像文件，二是直接将IPL和Kernel代码直接连接到一块，本质区别只是执行完ipl后跳转的地址不同！
注：到此不理解ipl和mbr区别，文中提到的mbr和ipl都是指bios加载的那512B的文件
- Loader.asm: ipl程序，其产生的二进制文件Loader.bin也是fat12软盘的引导区文件，制作软盘映像时记得设置引导产区属性

- Kernel.asm: 内核源文件
- Loader1.asm: ipl程序，其二进制文件Loader1.bin需要和Kernel.bin用 ·copy /b Loader1.bin+Kernel.bin Boot1.img·直接连接来作为软盘映像


