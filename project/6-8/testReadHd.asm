; 本程序将用来制作硬盘映像启动文件和内核文件
; 将本程序编译后的二进制文件直接写入硬盘就可以从硬盘启动
; 内核部分主要是用int 13h中断读取硬盘内容

org 0x7c00
jmp    start             ; 为了制作PBP,第3个字节必须是 0x90。这里采用jmp short来占2字节 
welcome db 'Welcome OS!','$'
fyread  db 'Floppy Read Loader:','$'
cylind  db 'cylind:?? $',0    ; 设置开始读取的柱面编号
header  db 'header:?? $',0    ; 设置开始读取的磁头编号
sector  db 'sector:?? $',1    ; 设置开始读取的扇区编号
FloppyOK db 'OK','$'
Fyerror db 'Error' ,'$'
Fycontent db 'Content:' ,'$'
NUMsector      EQU    5       ; 最大扇区编号
NUMheader      EQU    0        ; 最大磁头编号
NUMcylind      EQU    0       ; 设置读取到的柱面编号

; mbrseg         equ    7c0h     ; 启动扇区存放段地址
loaderseg      equ    0800h     ; 从软盘读取LOADER到内存的段地址
kernalseg      equ    0820h    ; 内核段地址 



start:
; mbr程序会打印一些辅助信息，然后读取Numsector个软盘扇区到0x8000处，之后跳转到0x8200执行kernel代码

mov dx, cs
mov ch, 'c'
mov cl, 's'
call printregister
call newline
mov   ax,0 
mov   ds,ax   ;为显示各种提示信息做准备 
mov   es,ax
mov sp, 0x7c00
mov ss, ax
; 根据《30天》这里不能将cs置0！！！
; mov cs, ax

call showwelcome    ;初始化寄存器，打印必要信息 
call loader         ;执行loader,把现在这张软盘的数据全部读到8000h开始。 
jmp  kernalseg:0    ;跳转到内核。物理地址为c200h=8000h+4200h；8000为loader的
;开始地址,4200为kernal在FAT文件中的偏移地址
;注意jmp指令的操作后果,该跳转之后,CS=kernalseg=0c20h,IP=0,DS,ES保持不变。 

showwelcome: 
    ;  mov   ax,0 
    ;  mov   ds,ax   ;为显示各种提示信息做准备 
    ;  mov   es,ax
    ;  mov sp, 0x7c00
    ;  mov ss, ax
    ;  mov cs, ax
     mov   ax,loaderseg 
     mov   es,ax   ;为读软盘数据到内存做准备，因为读软盘需地址控制---ES:BX
     
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



folppyload:                       
     call    read1sector
     MOV     AX,ES
     ADD     AX,0x0020
     MOV     ES,AX                ;一个扇区占512B=200H，刚好能被整除成完整的段,因此只需改变ES值，无需改变BP即可。 
    ;  mov dx, es
    ; mov ch, 'e'
    ; mov cl, 's'
    ; call printregister
    ; call newline
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
     
     
numtoascii:     ;将2位数的10进制数分解成ASII码才能正常显示。如柱面56 分解成出口ascii: al:35,ah:36
     mov ax,0
     mov al,cl  ;输入cl
     mov bl,10
     div bl
     add ax,3030h
     ret

; readinfo:       ;显示当前读到哪个扇区、哪个磁头、哪个柱面 
;      mov si,cylind
;      call  printstr
;      mov si,header
;      call  printstr
;      mov si,sector
;      call  printstr
;      ret


 
read1sector:                      ;读取一个扇区的通用程序。扇区参数由 sector header  cylind控制

       mov   cl, [sector+11]      ;为了能实时显示读到的物理位置
       call  numtoascii
       mov   [sector+7],al
       mov   [sector+8],ah

       mov   cl,[header+11]
       call  numtoascii
       mov   [header+7],al
       mov   [header+8],ah

       mov   cl,[cylind+11]
       call  numtoascii
       mov   [cylind+7],al
       mov   [cylind+8],ah

       MOV        CH,[cylind+11]    ; 柱面从0开始读
       MOV        DH,[header+11]    ; 磁头从0开始读
       mov        cl,[sector+11]    ; 扇区从1开始读        

        ; call       readinfo        ;显示软盘读到的物理位置
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


printstr:                  ;显示指定的字符串, 以'$'为结束标记 
      mov al,[si]
      cmp al,'$'
      je disover
      mov ah,0eh
      int 10h
      inc si
      jmp printstr
disover:
      ret

newline:                     ;显示回车换行
      mov ah,0eh
      mov al,0dh
      int 10h
      mov al,0ah
      int 10h
      ret
; showdata不会改变es
showdata:  mov  si,0             ;验证显示从软盘读取到内存的数据 
           mov  ax, kernalseg 
           push es
           mov  es,ax
           mov  cx,0x001f             ;控制输出的数据长度 
nextchar:  mov al,[es:si]
           mov ah,0eh
           int 10h
           inc si
           loop nextchar
           pop es
           RET


; 打印某寄存器的值，寄存器的值放在dx中，寄存器的名称放在cx中，以ascii形式存放，最终输出格式为`??=0x????`
printregister:
    mov ah, 0eh
    mov al, ch
    int 10h
    mov ah, 0eh
    mov al, cl
    int 10h
    mov ah, 0eh
    mov al, '='
    int 10h
    mov ah, 0eh
    mov al, '0'
    int 10h
    mov ah, 0eh
    mov al, 'x'
    int 10h
    ; first-4 bit
    mov ax, dx
    and ax, 0xf000
    shr ax, 12
    cmp al, 10
    jl .addzero1
    add al, 7
.addzero1:
    add al, '0'
    mov ah, 0eh
    int 10h
    ; second-4 bit
    mov ax, dx
    and ax, 0x0f00
    shr ax, 8
    cmp al, 10
    jl .addzero2
    add al, 7
.addzero2:
    add al, '0'
    mov ah, 0eh
    int 10h
    ; third-4 bit
    mov ax, dx
    and ax, 0x00f0
    shr ax, 4
    cmp al, 10
    jl .addzero3
    add al, 7
.addzero3:
    add al, '0'
    mov ah, 0eh
    int 10h
     ; fourth-4 bit
    mov ax, dx
    and ax, 0x000f
    shr ax, 0
    cmp al, 10
    jl .addzero4
    add al, 7
.addzero4:
    add al, '0'
    mov ah, 0eh
    int 10h
    ret




times 510-($-$$) db 0
                 db 0x55,0xaa


jmp kernel
; 注：kernel区代码如果要使用数据那么mov si，label+1024
validata: db 'if you see this, floppy disk is loaded ok', '$'
hdcylind  db 'cylind:?? $',0    ; 设置开始读取的柱面编号
hdheader  db 'header:?? $',0    ; 设置开始读取的磁头编号
hdsector  db 'sector:?? $',1    ; 设置开始读取的扇区编号
HdOK db 'OK','$'
HdError db 'Error' ,'$'
HdContent db 'Content:' ,'$'
hdstate db 'hdstate=0x$'
kernel:
    call k_newline
    ; 打印cs
    mov ah, 0eh
    mov al, '>'
    int 10h
    mov dx, cs
    mov ch, 'c'
    mov cl, 's'
    call k_printregister
    call k_newline
    ; 打印ds
    mov ah, 0eh
    mov al, '>'
    int 10h
    mov dx, ds
    mov ch, 'd'
    mov cl, 's'
    call k_printregister
    call k_newline
    ; 打印es
    mov ah, 0eh
    mov al, '>'
    int 10h
    mov dx, es
    mov ch, 'e'
    mov cl, 's'
    call k_printregister
    call k_newline
    call k_read1hdsector
    jmp $
; 打印某寄存器的值，寄存器的值放在dx中，寄存器的名称放在cx中，以ascii形式存放，最终输出格式为`??=0x????`
k_printregister:
    mov ah, 0eh
    mov al, ch
    int 10h
    mov ah, 0eh
    mov al, cl
    int 10h
    mov ah, 0eh
    mov al, '='
    int 10h
    mov ah, 0eh
    mov al, '0'
    int 10h
    mov ah, 0eh
    mov al, 'x'
    int 10h
    ; first-4 bit
    mov ax, dx
    and ax, 0xf000
    shr ax, 12
    cmp al, 10
    jl k_.addzero1
    add al, 7
k_.addzero1:
    add al, '0'
    mov ah, 0eh
    int 10h
    ; second-4 bit
    mov ax, dx
    and ax, 0x0f00
    shr ax, 8
    cmp al, 10
    jl k_.addzero2
    add al, 7
k_.addzero2:
    add al, '0'
    mov ah, 0eh
    int 10h
    ; third-4 bit
    mov ax, dx
    and ax, 0x00f0
    shr ax, 4
    cmp al, 10
    jl k_.addzero3
    add al, 7
k_.addzero3:
    add al, '0'
    mov ah, 0eh
    int 10h
     ; fourth-4 bit
    mov ax, dx
    and ax, 0x000f
    shr ax, 0
    cmp al, 10
    jl k_.addzero4
    add al, 7
k_.addzero4:
    add al, '0'
    mov ah, 0eh
    int 10h
    ret

k_newline:                     ;显示回车换行
      mov ah,0eh
      mov al,0dh
      int 10h
      mov al,0ah
      int 10h
      ret

; 读取第一个磁盘的扇区1
k_read1hdsector:                      ;读取一个扇区的通用程序。扇区参数由 sector header  cylind控制

       mov   cl, [hdsector+11]      ;为了能实时显示读到的物理位置
       call  k_numtoascii
       mov   [hdsector+7],al
       mov   [hdsector+8],ah

       mov   cl,[hdheader+11]
       call  k_numtoascii
       mov   [hdheader+7],al
       mov   [hdheader+8],ah

       mov   cl,[hdcylind+11]
       call  k_numtoascii
       mov   [hdcylind+7],al
       mov   [hdcylind+8],ah

       MOV        CH,[hdcylind+11]    ; 柱面从0开始读
       MOV        DH,[hdheader+11]    ; 磁头从0开始读
       mov        cl,[hdsector+11]    ; 扇区从1开始读        

        ; call       readinfo        ;显示软盘读到的物理位置
        mov        di,0
k_retry:
        MOV        AH,02H            ; AH=0x02 : AH设置为0x02表示读取磁盘
        MOV        AL,1            ; 要读取的扇区数
        mov dx, es
        mov ch, 'e'
        mov cl, 's'
        call k_printregister
        call k_newline
        mov        BX,    0         ; ES:BX表示读到内存的地址 0x0800*16 + 0 = 0x8000
        MOV        DL,80H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
        INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
        JNC        k_READOK           ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
           inc     di
           MOV     AH,0x00
           MOV     DL,0x80         ; A驱动器
           INT     0x13            ; 重置驱动器
           cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃 
           jne     k_retry

           mov     si, HdError+1024
           call    k_printstr
           call    k_newline
           ; 打印磁盘状态
           mov si, hdstate+1024
           call k_printstr
           mov ah, 01h
           mov dl, 80h
           int 13H
            push dx
            push cx
            mov cl, al
            xor dx, dx
            mov dl, al
            shr dx, 0x0004
            mov ah, 0eh
            add dl, '0'
            cmp dl, '9'
            jbe k_next1
            add dl, 7
k_next1:
            mov al, dl
            int 10h
            xor dx, dx
            mov dl, cl
            add dl, 0x0f
            mov ah, 0eh
            add dl, '0'
            cmp dl, '9'
            jbe k_next2
            add dl, 7
k_next2:
            mov al, dl
            int 10h
            push cx
            pop dx
           jmp     k_exitread
k_READOK:    mov     si, HdOK+1024
           call    k_printstr
           call    k_newline
k_exitread:
           ret

k_printstr:                  ;显示指定的字符串, 以'$'为结束标记 
      mov al,[si]
      cmp al,'$'
      je k_disover
      mov ah,0eh
      int 10h
      inc si
      jmp k_printstr
k_disover:
      ret

k_numtoascii:     ;将2位数的10进制数分解成ASII码才能正常显示。如柱面56 分解成出口ascii: al:35,ah:36
     mov ax,0
     mov al,cl  ;输入cl
     mov bl,10
     div bl
     add ax,3030h
     ret

; showdata不会改变es
k_showdata:  mov  si,0             ;验证显示从软盘读取到内存的数据 
           mov  ax, kernalseg 
           push es
           mov  es,ax
           mov  cx,0x00ff            ;控制输出的数据长度 
k_nextchar:  mov al,[es:si]
           mov ah,0eh
           int 10h
           inc si
           loop k_nextchar
           pop es
           RET
times 1474560-($-$$) db 0