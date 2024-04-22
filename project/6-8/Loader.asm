org 0x7c00
jmp start 

NUMsector EQU 15       ; 最大扇区编号 这个值暂时应该由kernel二进制文件大小和mbr程序大小共同决定
NUMheader EQU 0        ; 最大磁头编号
NUMcylind EQU 0        ; 设置读取到的柱面编号

loaderseg equ 800h     ; 从软盘读取LOADER到内存的段地址
kernalseg equ 0820h    ; 内核段地址,因为本文件最后生成的二进制文件要直接和内核二进制文件连接，不用fat格式 



   
welcome db 'Welcome jiebei OS!','$'
fyread  db 'Now Floppy Read Loader:','$'
cylind  db 'cylind:?? $',0    ; 设置开始读取的柱面编号
header  db 'header:?? $',0    ; 设置开始读取的磁头编号
sector  db 'sector:?? $',1    ; 设置开始读取的扇区编号
FloppyOK db '---Floppy Read OK','$'
Fyerror db '---Floppy Read Error' ,'$'
Fycontent db 'Floppy Content is:' ,'$'         
start:
     ; 注意：sp不能在函数中初始化，否则函数无法返回
     ; 初始化段寄存器，注意cs不要初始化，初始化sp后栈顶为0x7c20，栈大小为约30kb，0x500-0x7bff都可用
     ; 将ds ss ax置0， es置0x0800 将sp置 0x7c20
     xor ax, ax
     mov ds, ax
     mov ss, ax
     mov ax, 0x0800
     mov es, ax
     mov sp, 0x7c00
     call showwelcome    ;打印必要信息 
     call loader         ;执行loader,把现在这张软盘的数据全部读到8000h开始。 
     jmp  kernalseg:0    ;跳转到内核。物理地址为8200h=8000h+0200h；8000为loader代码的存放地址
;注意jmp指令的操作后果,该跳转之后,CS=kernalseg=8200h,IP=0,DS,ES保持不变。 


; 打印欢迎信息
showwelcome: 
     mov   si,welcome
     call  printstr
     call  newline
     ret

loader:
     mov   si, fyread
     call  printstr
     call  newline
     call  folppyload    ;将软盘的数据全部load到内存，从物理地址8000h开始 
     mov   si, Fycontent
     call  printstr
     call  showdata      ;可以验证一下从软盘读入的kernal程序数据是否正确(二进制) 
     ret


; 将软盘数据读到内存0x8000起始处
; 本程序会修改es寄存器，假设读取软盘内容到0x8000-0x_pos，那么es最终为0x_pos-512
folppyload:                       
     call    read1sector
     MOV     AX,ES
     ADD     AX,0x0020
     MOV     ES,AX                ;一个扇区占512B=200H，刚好能被整除成完整的段,因此只需改变ES值，无需改变BP即可。 
     inc   byte [sector+11]
     cmp   byte [sector+11],NUMsector+1
     jne   folppyload             ;读完一个扇区
     mov   byte [sector+11],1
     inc   byte [header+11]
     cmp   byte [header+11],NUMheader+1
     jne   folppyload             ;读完一个磁头
     mov   byte [header+11],0
     inc   byte [cylind+11]
     cmp   byte [cylind+11],NUMcylind+1
     jne   folppyload             ;读完一个柱面

     ret
     
;将2位数的10进制数分解成ASII码才能正常显示。输入在cl中，如柱面56 分解成出口ascii: ah:35,al:36 高位对高位，低位对低位
; 本程序修改cx，其是输出, ch放10位数，cl放个位数
numtoascii:
     push bx     
     mov ax,0
     mov al,cl  ;输入cl
     mov bl,10
     div bl
     add ax,3030h
     mov bh, al
     mov bl, ah
     mov al, bl
     mov ah, bh
     pop bx
     ret

;显示当前读到哪个扇区、哪个磁头、哪个柱面 
readinfo:       
     mov si,cylind
     call  printstr
     mov si,header
     call  printstr
     mov si,sector
     call  printstr
     ret


;读取一个扇区的通用程序。扇区参数由 sector header  cylind控制
read1sector:                      

       mov   cl, [sector+11]      ;为了能实时显示读到的物理位置
       call  numtoascii
       mov   [sector+7],ah
       mov   [sector+8],al

       mov   cl,[header+11]
       call  numtoascii
       mov   [header+7],ah
       mov   [header+8],al

       mov   cl,[cylind+11]
       call  numtoascii
       mov   [cylind+7],ah
       mov   [cylind+8],al

       MOV        CH,[cylind+11]    ; 柱面从0开始读
       MOV        DH,[header+11]    ; 磁头从0开始读
       mov        cl,[sector+11]    ; 扇区从1开始读        

        call       readinfo        ;显示软盘读到的物理位置
        mov        di,0
retry:
        MOV        AH,02H            ; AH=0x02 : AH设置为0x02表示读取磁盘
        MOV        AL,1            ; 要读取的扇区数
        mov        BX,    0         ; ES:BX表示读到内存的地址 0x0800*16 + 0 = 0x8000
        MOV        DL,00H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
        INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
        JNC        READOK           ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x00         ; A驱动器
           INT     0x13            ; 重置驱动器
           cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃 
           jne     retry

           mov     si, Fyerror
           call    printstr
           call    newline
           jmp     exitread
READOK:    mov     si, FloppyOK
           call    printstr
           call    newline
exitread:
           ret

; 打印si内存地址处的字符串，字符串以'$'结尾
; 本函数会改变寄存器si的值，最后si的值为本字符串的结尾$的内存地址
printstr:
     push ax
     mov al,[si]
     cmp al,'$'
     je disover
     mov ah,0eh
     int 10h
     inc si
     pop ax
     jmp printstr
disover:
     pop ax
     ret
;显示回车换行
; 本程序不会修改任何寄存器
newline:    
     push ax
     mov ah,0eh
     mov al,0dh
     int 10h
     mov al,0ah
     int 10h
     pop ax
     ret

showdata:  mov  si,0             ;验证显示从软盘读取到内存的数据 
           mov  ax, loaderseg 
           mov  es,ax
           mov  cx,100             ;控制输出的数据长度 
nextchar:  mov al,[es:si]
           mov ah,0eh
           int 10h
           inc si
           loop nextchar
           call newline
           ret




times 510-($-$$) db 0
                 db 0x55,0xaa