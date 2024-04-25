jmp kernelstart
; 打印欢迎信息
kernelwelcome: db 'here is kernel area...$'
; 最长显示目录100个字符
curpath: db '/$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$', \
           '$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$$'
; 显示的目录名后的前缀
pwdinfo: db '>>$'
; ls命令后如果是目录会显示这个前缀
dirnamepre:  db '<DIR>         ', '$'
; ls命令后如果是普通文件会显示一些空格前缀
filenamepre: db '      size:?? ', '$'
; /的dirid=0，根目录的父目录的id为0
; 在目录结构数据扇区，将未占用的记录项的dirid记为 -index，index是这个记录项是第几个记录项，start at 0 
; 当前目录的dirid
curdirid: db 0
; 总共的目录元数据的条数
totaldirnum: db 200
; 总共的文件元数据的条数
totalfilenum: db 200
; 指令的最长长度为20字符
inputcom: db '$$$$$$$$$$$$$$$$$$$$$'
clscom: db 'cls'
; format指令用于格式化文件系统，具体来说：
; 第一个扇区置0
; 2-12为文件扇区占用标记，置0
; 13-16为目录数据结构
; 17-26为文件数据结构
; 接下来4000个扇区为文件扇区，也置0吧(其实不必置0)
formatcom: db 'format'
lscom: db 'ls'
mkdircom: db 'mkdir'
touchcom: db 'torch'
cdcom: db 'cd'
rmcom: db 'rm'
rmdircom: db 'rmdir'

kernelstart:
	; 初始化寄存器
	mov ax, 0x0820
	mov ds, ax
	mov es, ax
	; 打印欢迎信息
	mov si, kernelwelcome
	call k_printstr
	call k_newline

filesystem:
	; 打印当前目录
	mov si, curpath
	call k_printstr
	mov si, pwdinfo
	call k_printstr
	; 在usrinput需要置si为0
	mov si, 0
usrinput: 
	mov ah,0
	int 16h                        ;从键盘读字符 ah=扫描码 al=字符码(al中存读到的字符)
	mov ah,0eh                     ;把键盘输入的字符显示出来 
	int 10h
	cmp    al, 0dh                 ;回车作为输入结束标记
	je     inputover
	mov    [inputcom+si],al
	inc    si
	jmp    usrinput
inputover:
ifclscom:
	; 判断是否为cls命令
	mov cx, formatcom-clscom
	mov si, 0 
clscomnextchar:
	mov byte ah, [clscom+si]
	mov byte al, [inputcom+si]
	cmp ah, al
	jne ifformatcom
	inc si
	loop clscomnextchar
	jmp cls
; 清屏命令
cls:
	call clsdeal
	jmp comdealover
ifformatcom:
	; 判断是否为format命令
	mov cx, lscom-formatcom
	mov si, 0 
formatcomnextchar:
	mov byte ah, [formatcom+si]
	mov byte al, [inputcom+si]
	cmp ah, al
	jne iflscom
	inc si
	loop formatcomnextchar
	jmp format
; format命令
format:
	call formatdeal
	call k_newline
	jmp comdealover
iflscom:
	; 判断是否为ls命令
	mov cx, mkdircom-lscom
	mov si, 0
lscomnextchar:
	mov byte ah, [lscom+si]
	mov byte al, [inputcom+si]
	cmp ah, al
	jne ifmkdircom
	inc si
	loop lscomnextchar
	jmp ls
; ls命令
ls:
    call k_newline
    call lsdeal
    call k_newline
    jmp comdealover
ifmkdircom:
; 判断是否为mkdir命令
    mov cx, touchcom-mkdircom
    mov si, 0 
mkdircomnextchar:
    mov byte ah, [mkdircom+si]
    mov byte al, [inputcom+si]
    cmp ah, al
    jne iftouchcom
    inc si
    loop mkdircomnextchar
    jmp mkdir
; mkdir指令的格式 mkdir dirname 中间用一个半角空格隔开，dirname最长8字节，最短1字节
mkdir:
    
    call mkdirdeal
    call k_newline
    jmp comdealover
iftouchcom:
    ;FIXME 完善touch命令
    jmp ifcdcom
ifcdcom:
;    判断是否cd命令
    mov cx, rmcom-cdcom
    mov si, 0
cdcomnextchar:
    mov byte ah, [cdcom+si]
    mov byte al, [inputcom+si]
    cmp ah, al
    jne ifrmcom
    inc si
    loop cdcomnextchar
    jmp cd
; cd命令
cd:
    call cddeal
    call k_newline
    jmp comdealover
ifrmcom:
    ; FIXME 完善rm命令
    jmp $
; 命令执行完成后，需要将inputcom全置为$
comdealover:
    mov cx, clscom-inputcom  ; 指令输入缓冲区的大小
comdealoverloop: 
    push cx
    push bx
    dec cx
    add cx, inputcom
    mov bx, cx
    mov byte [ds:bx], '$'
    pop bx
    pop cx
    loop comdealoverloop
    jmp filesystem



; 打印si内存地址处的字符串，字符串以'$'结尾
; 本函数会改变寄存器si的值，最后si的值为本字符串的结尾$的内存地址
k_printstr:
    push ax
    mov al,[ds:si]
    cmp al,'$'
    je k_disover
    mov ah,0eh
    int 10h
    inc si
    pop ax
    jmp k_printstr
k_disover:
    pop ax
    ret


;显示回车换行
; 本程序不会修改任何寄存器
k_newline:    
    push ax
    mov ah,0eh
    mov al,0dh
    int 10h
    mov al,0ah
    int 10h
    pop ax
    ret


;将2位数的10进制数分解成ASII码才能正常显示。输入在cl中，如柱面56 分解成出口ascii: ah:35,al:36 高位对高位，低位对低位
; 本程序修改cx，其是输出, ch放十位数，cl放个位数
k_numtoascii:
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



; 清屏命令
clsdeal:
    mov ah,00h
    mov al,03h  ;80*25标准彩色文本
    int 10h
    ret

; 具体执行format指令，就是将磁盘chs从0-0-1开始清零1+11个扇区
formatdeal:
; 一个变量，后面要用
hdsectortowrite: db 0
	; 将内存0x3000_0开始512字节置0
	mov ax, 0x3000
	mov es, ax
	mov al, 0
	mov bx, 0
	mov cx, 512
zeronextbyte:
	 mov byte [es: bx], al
	 inc bx
	 loop zeronextbyte
	 ; cx循环计数器, 将磁盘前12个扇区清零
	 mov cx, 12
	 ; hdsector记录要写入的扇区
	 mov byte [hdsectortowrite], 1
writezero:
    push cx
    mov al, 1
    mov ch, 0
    mov cl, [hdsectortowrite]
    mov dh, 0
    mov dl, 0x80
    mov bx, 0
    mov ah, 0x03   ; 03h表示写盘
    ; 写一个扇区，参数由 AL 表示要写入的扇区数量，CH 表示磁道号，CL 表示扇区号，DH 表示磁头号，DL 表示驱动器号。
    int 13h
    inc cl
    mov byte [hdsectortowrite], cl
    pop cx
    loop writezero

    ; 将4个目录结构区格式化，每个条目的格式为 起始第一个字节为序号的负数，序号从0开始，其中0为根目录，如果该目录项空闲则置为相反数，第0个是根目录，不空闲
    ; 将内存0x3000_0开始4个扇区格式化
    mov ax, 0x3000
    mov es, ax
    ; 用cx做外循环计数器4，用si做内循环计数器0-50
    mov cx, 4
dirformatloop1:
    mov si, 0
    mov bx, 0
dirformatloop2:
    ; 将 （4-cx）*50+si的负数写入[es:bx]
    mov ax, cx
    neg al
    mov ah, 0
    add al, 4
    mov dx, 50
    mul dx    ; 低16位在ax，高16位在dx
    add ax, si
    neg al
    mov byte [es:bx], al
    ; 每个条目占10字节，所以要加10
    add bx, 10
    inc si
    cmp si, 50
    jne dirformatloop2
    ;  将这个扇区写入磁盘13+4-cx扇区开始的地方
    cmp cx, 4
    jne writenext
    ;  把根目录的目录项做好
    mov byte [es:0], 0
    mov byte [es:1], 0
    mov byte [es:2], '/'
    mov byte [es:3], '$'
writenext:
    push cx
    mov bx, 0
    mov al, 1
    mov ch, 0
    ;  扇区号为13+4-cx
    neg cl
    add cl, 17
    mov dh, 0
    mov dl, 0x80
    mov ah, 0x03   ; 03h表示写盘
    ; 写一个扇区，参数由 AL 表示要写入的扇区数量，CH 表示磁道号，CL 表示扇区号，DH 表示磁头号，DL 表示驱动器号。
    int 13h
    pop cx
    ; es定位到下一个扇区
    mov ax, es
    add ax, 0x0020
    mov es, ax
    
    loop dirformatloop1

    ; 将10个文件结构区格式化，每个条目的格式为 起始第一个字节为文件编号，从0开始，为序号的负数代表本目录空闲，暂时第0个文件结构不能用。。。
    ; 将内存0x3000_0开始的10个扇区格式化
    mov ax, 0x3000
    mov es, ax
    ; 用cx做外循环计数器10，用si做内循环计数器0-20
    mov cx, 10
dirformatloop3:
    mov si, 0
    mov bx, 0
dirformatloop4:
 ; 将 （10-cx）*20+si的负数写入[es:bx]
    mov ax, cx
    neg al
    mov ah, 0
    add al, 10
    mov dx, 20
    mul dx    ; 高16位在dx，低16位在ax
    add ax, si
    neg al
    mov byte [es:bx], al
    ; 每个条目占25字节，所以要加10  fileid-1B parentid-1B filename-2b(ascii) filesize-1B sector1-1B sector2-1B ... sector20-1B
    add bx, 25
    inc si
    cmp si, 20
    jne dirformatloop4
    ;  将这个扇区写入磁盘17+10-cx扇区开始的地方
    ; 写一个扇区，参数由 AL 表示要写入的扇区数量，CH 表示磁道号，CL 表示扇区号，DH 表示磁头号，DL 表示驱动器号。
    push cx
    mov bx, 0
    mov al, 1
    mov ch, 0
    neg cl
    add cl, 27
    mov dh, 0
    mov dl, 0x80
    mov ah, 0x03
    int 13H
    ; es定位到下一个扇区
    mov ax, es
    add ax, 0x0020
    mov es, ax
    pop cx
    loop dirformatloop3
    ret

;读取一个扇区的通用程序。扇区参数由 参数由 es：bx al:读取的扇区数量不用指定固定填1 ch:磁道号 cl：扇区号 dh：磁头号 dl：驱动器号不用指定固定0x80 di: 当一次读盘失败时指定最多可以读几次盘，5足够,固定填0！
hdread1sec:                     
	MOV        AH,02H            ; AH=0x02 : AH设置为0x02表示读取磁盘
	MOV        AL,1            ; 要读取的扇区数
	MOV        DL,80H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
	INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
	JNC        hdexitread1           ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
	inc     di
	MOV     AH,0x00
	MOV     DL,0x80         ; A驱动器
	INT     0x13            ; 重置驱动器
	cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃 
	jne     hdread1sec
  ; FIXME
  ; 5次都不成功的错误处理，这里暂时留空
 ;  mov     si, HDerror
 ;  call    k_printstr
 ;  call    k_newline
         
hdexitread1:
	ret



lsdeal:
    ; 先读取目录结构扇区，共4个，读到0x3000:0起始的位置
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
	call readdirmeta
    ; currentdirid存储了当前所在目录的id
    ; 遍历所有的目录结构区，如果dirid不是序号标号说明目录项空闲，跳过
    mov ax, 0x3000
    mov es, ax
    ; 注意：之后用bx必须入栈保存！
    mov bx, 0
    ; 外层循环计数器为cx 循环4次
    mov cx, 4
lsoutloop:
; 内层循环计数器为si 循环50次
    mov si, 0
lsinloop:
    ; 当前处理的记录的编号本来是 （4-cx）*50+si
    ; 比较dirid和原本编号是否相同
    mov ax, cx
    neg al
    add al, 4
    mov dx, 50
    mul dx    ;低16位结果在ax，高16位结果在dx中
    add ax, si

    mov byte dh, [es:bx]
    cmp al, dh
    ; 相等就去判断parentid currentid是否相等
    ; 不相等就更新bx的值后继续循环, bx加上一条记录的长度
    jne lsinloopnext
    mov byte dh, [es:bx+1]
    mov dl, [curdirid]
    cmp dh, dl
    ; 相等就打印该目录名
    ; 不相等就处理下一个目录
    jne lsinloopnext
    ; 打印目录名
    push si
    push ax
    push bx
    push cx
    mov si, dirnamepre
    call k_printstr
    add bx, 2
    mov si, bx
    mov cx, 8 ;目录名最长为8个字符
printdirnext:
    mov al, [es:si]
    cmp al, '$'
    je printdirover
    mov ah, 0eh
    int 10h
    inc si
    loop printdirnext
printdirover:
    pop cx
    pop bx
    pop ax
    pop si
    call k_newline
lsinloopnext:
    add bx, 10
    inc si
    cmp si, 50
    jne lsinloop
    ; 相等就需要更新es的值，去处理下一个扇区数据
    mov ax, es
    add ax, 0x0020
    mov es, ax
    loop lsoutloop

    ; 再读取文件结构扇区，共10个，读到0x3000:0起始的位置
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
	call readfilemeta
    ; currentdirid存储了当前所在目录的id
    ; 遍历所有的文件结构区，如果fileid不是序号标号说明该文件数据项空闲，跳过
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
    ; 外层循环计数器为cx 循环10次
    mov cx, 10
lsoutloop1:
; 内层循环计数器为si 循环20次
    mov si, 0
lsinloop1:
    ; 当前处理的记录的编号本来是 （10-cx）*20+si
    ; 比较fileid和原本编号是否相同
    mov byte dh, [es:bx]
    push dx
    mov ax, cx
    neg ax
    add ax, 10
    mov bx, 20
    mul bx    ;低16位结果在ax，高16位结果在dx中
    mov bx, si
    add al, bl
    pop dx
    cmp al, dh
    ; 相等就去判断parentid currentid是否相等
    ; 不相等就更新bx的值后继续循环, bx加上一条记录的长度
    jne lsinloop1next
    mov byte dh, [es:bx+1]
    mov dl, curdirid
    cmp dh, dl
    ; 相等就打印该文件名
    ; 不相等就处理下一个文件项
    jne lsinloop1next
    ; 打印文件名
    ; FIXME 打印文件名的部分继续完善
lsinloop1next:
    add bx, 25
    inc si
    cmp si, 20
    jne lsinloop1
    ; 相等就需要更新es的值，去处理下一个扇区数据
    mov ax, es
    add ax, 0x0020
    mov es, ax
    loop lsoutloop1
    ret



mkdirdeal:
    
    ; 将目录结构的4个数据读到0x3000_0
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
	call readdirmeta
    ; 遍历所有目录项，找到空的目录项
         ; curdirid存储了当前所在目录的id
    mov ax, 0x3000
    mov es, ax
    ; 注意：之后用bx必须入栈保存！
    mov bx, 0
    ; 外层循环计数器为cx 循环4次
    mov cx, 4
mkdiroutloop:
; 内层循环计数器为si 循环50次
    mov si, 0
mkdirinloop:
    ; 当前处理的记录的编号本来是 （4-cx）*50+si
    ; 比较dirid和原本编号是否相同
    mov ax, cx
    neg al
    add al, 4
    mov dx, 50
    mul dx    ;低16位结果在ax，高16位结果在dx中
    add ax, si

    mov byte dh, [es:bx]
    cmp al, dh
    ; 相等就说明目录项不空闲，继续下一条
    ; 不相等就说明目录项空闲，准备制作新目录项
    jne mkdirinloopnext
    add bx, 10
    inc si
    cmp si, 50
    jne mkdirinloop
    mov ax, es
    add ax, 0x0020
    mov es, ax
    mov bx, 0
    loop mkdiroutloop
    ; FIXME 完善200个目录项全满的情况
    jmp mkdirfailed
mkdirinloopnext:
	push si
    push di
    push ax
    push bx
    push cx
    push dx
    mov cx, 8     ; al中存放最长的目录名长度
    mov si, inputcom+6  ; 目录名的起始位置，mkdir是5个字符，中间有一个空格一个字符
parsedirname:
    mov dl, [si]        ; dl存放读到的字符，如果是$代表读完
    cmp dl, '$'
    je mkdirnext1
    push cx
    push bx
    neg cx
    add cx, 10
    add bx, cx
    ; 将目录名存入目录记录中，格式为dirname$ 如果目录名长度为8则没有问号
    mov byte [es:bx], dl
    pop bx
    pop cx
    inc si
    loop parsedirname
mkdirnext1:
    cmp cx, 0
    je mkdirnext2  ; 如果目录名长度为8则不用写末尾的$
    ; 如果目录名长度小于8则写末尾的$
    neg cx
    add cx, 10
    add bx, cx
    mov byte [es:bx], '$'
mkdirnext2:
; 对应pardirname前的入栈
    pop dx
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ; 将空的目录项的dirid置为序号
    ; 将parentid置为curdirid
    mov byte dh, [es:bx]
    neg dh
    mov byte [es:bx], dh
    ; mov si, curdirid
    mov byte dl, [curdirid]
    mov byte [es:bx+1], dl
    ; 将修改过的目录项所在扇区写入磁盘
    push bx
    push cx
    mov bx, 0
    mov ch, 0
    mov dh, 0
    neg cl
    add cl, 17
    mov di, 0
    call hdwrite1sec
    pop cx
    pop bx
    ret
mkdirfailed:
; FIXME 完善200个目录项全满的处理代码
    ret

cddeal:
    ; 将4个扇区的目录结构区读到0x3000_0起始位置
    ; 将目录结构的4个数据读到0x3000_0
    mov ax, 0x3000
    mov es, ax
    mov bx, 0
	call readdirmeta
	; FIXME 完善 cd .
	; 处理 cd ..
	call ifcdupdir
	jne commoncd
	; 修改curpath
	; 如果当前已经是根目录，则什么都不需要变
	mov byte al, [curpath+1]
	mov ah, '$'
	cmp ah, al
	je roottoret
	; 从前到后找到第一个$,再从后到前置为$直到字符为/
	mov si, curpath
tofindend:
	mov byte al, [si]
	cmp byte al, '$'
	je toclearpathchar
	inc si
	jmp tofindend
toclearpathchar:
	dec si
	mov ax, [si]
	cmp byte al, '/'
	; 注意，如果上一级目录是根目录，则保留/，否则删除/，这部分放在updatecurdirid中处理
	je updatecurdirid
	mov byte [si], '$'
	jmp toclearpathchar
updatecurdirid:
	; 修改curdirid
	xor ax, ax
	mov byte al, [curdirid]
	mov dx, 10
	mul dx ; 高16在dx，低16在ax
	mov bx, ax
	mov ax, 0x3000
	mov es, ax
	mov al, [es:bx+1]
	mov byte [curdirid], al
	; 注意，如果上一级目录是根目录，则保留/，否则删除/
	cmp al, 0
	je updatecurdiridover
	; 注意，si从toclearpathchar到这里一直不能改变，其要存放要处理的/地址
	mov byte [si], '$'
updatecurdiridover:
	ret
roottoret:
	ret
commoncd:
    ; 遍历目录结构项，先看dirid是否为序号
    mov ax, 0x3000
    mov es, ax
    ; 注意：之后用bx必须入栈保存！
    mov bx, 0
    ; 外层循环计数器为cx 循环4次
    mov cx, 4
cdoutloop:
; 内层循环计数器为si 循环50次
    mov si, 0
cdinloop:
    ; 当前处理的记录的编号本来是 （4-cx）*50+si
    ; 比较dirid和原本编号是否相同
    
    mov ax, cx
    neg al
    add al, 4
    mov dx, 50
    mul dx    ;低16位结果在ax，高16位结果在dx中
    add ax, si

    mov byte dh, [es:bx]
    cmp al, dh
    ; 相等则说明目录项不为空，继续判断parentid是否等于curdirid，目录项为空则继续下一次循环
    je cdinloopnext1
cdinloopnext:
    add bx, 10
    inc si
    cmp si, 50
    jne cdinloop
    mov ax, es
    add ax, 0x0020
    mov es, ax
    mov bx, 0
    loop cdoutloop
    ; FIXME 完善这里cd后的目录不存在的情况
    ret
cdinloopnext1:
    mov byte dl, [es:bx+1]
    mov byte dh, [curdirid]
    cmp dh, dl
    ; parentid不等于curdirid则下一次循环
    jne cdinloopnext
    ; parentid等于curdirid则判断目录参数名和该目录名是否相同，不同则继续循环
    ; 目录名起始地址为inputcom+3
    xor ax, ax
cdinloopnext1loop:
    mov di, inputcom+3
    add di, ax
    mov byte dh, [di]
    cmp dh, '$'
    je cdcomappend
    push bx
    add bx, ax
    add bx, 2
    mov byte dl, [es:bx]
    cmp dh, dl
    pop bx
    jne cdinloopnext
    inc ax
    jmp cdinloopnext1loop
    ; 目录参数名和该目录名相同则在curpath后续写cd后的目录参数名
cdcomappend:
    ; 找到第一个$
    mov di, curpath
cdcomappendnext:
    mov dh, [di]
    cmp dh, '$'
    je cdcomappendnext1
    inc di
    jmp cdcomappendnext
cdcomappendnext1:
	; 如果当前目录不是根目录就先写一个 /
	mov byte al, [curdirid]
	cmp al, 0
	je afterslash
	mov byte [di], '/'
	inc di
afterslash:
    ; 从inputcom+3一直复制到$
    mov si, inputcom+3
cdcomappendnext2:
    mov byte dh, [si]
    cmp dh, '$'
    je cdcomover
    mov byte [di], dh
    inc di
    inc si
    jmp cdcomappendnext2
cdcomover:
    mov byte [di], '$'
    ; 改写curdirid
    mov byte dh, [es:bx]
    mov byte [curdirid], dh
    ret

; 这个函数将磁道号为ch 磁头号为dh 扇区号为cl开始  的al个扇区读入es:bx
; 这个函数不改变寄存器
readhdsectors:
    push si
    push di
    push ax
    push bx
    push cx
    push dx
    push es

    mov si, 0 ;循环计数器，循环al次， al存在di中
    xor ah, ah
    mov di, ax
readhdsectorsnext:
    ; cl 应该为 cl+si
    mov al, 1     
    push ax
    mov ax, si
    add cl, al
    pop ax
    ; 读取一个扇区，参数由 es：bx al:读取的扇区数量不用指定固定填1 ch:磁道号 cl：扇区号 dh：磁头号 dl：驱动器号不用指定固定0x80
    push di
    xor di, di
    call hdread1sec
    pop di
    mov ax, es
    add ax, 0x20
    mov es, ax
    inc si
    cmp si, di
    jne readhdsectorsnext
    pop es
    pop dx
    pop cx
    pop bx
    pop ax
    pop di
    pop si
    ret


;向磁盘写一个扇区的通用程序。扇区参数由 参数由 es：bx al:读取的扇区数量不用指定固定填1 ch:磁道号 cl：扇区号 dh：磁头号 dl：驱动器号不用指定固定0x80 di: 当一次写盘失败时指定最多可以读几次盘，5足够,固定填0！
hdwrite1sec:                     
       MOV        AH,03H            ; AH=0x02 : AH设置为0x02表示读取磁盘
       MOV        AL,1            ; 要读取的扇区数
       MOV        DL,80H           ; 驱动器号，0表示第一个软盘，是的，软盘。。硬盘C:80H C 硬盘D:81H
       INT        13H               ; 调用BIOS 13号中断，磁盘相关功能
    ;    push ax
    ;    ; for debug
    ; mov ah, 0eh
    ; mov al, '('
    ; int 10h 
    ; pop ax
       JNC        hdexitwrite1           ; 未出错则跳转到READOK，出错的话则会使EFLAGS寄存器的CF位置1
    ;       push ax
    ;       ; for debug
    ; mov ah, 0eh
    ; mov al, ')'
    ; int 10h 
    ; pop ax
          inc     di
          MOV     AH,0x00
          MOV     DL,0x80         ; A驱动器
          INT     0x13            ; 重置驱动器
          cmp     di, 5           ; 软盘很脆弱，同一扇区如果重读5次都失败就放弃 
          jne     hdwrite1sec
          ; FIXME
          ; 5此都不成功的错误处理，这里暂时留空
         ;  mov     si, HDerror
         ;  call    k_printstr
         ;  call    k_newline
         
hdexitwrite1:
          ret

; 读取目录结构扇区到es：dx位置
readdirmeta:
	push ax
	push bx
	push cx
	push dx
	push es
	push si
	push di
    mov si, 0 ;循环计数器，循环4次
readdir:
    mov ch, 0
    mov dh, 0
    ; 扇区号是13+si
    mov ax, si
    mov cl, 13
    add cl, al
    mov di, 0
    ; 读取一个扇区，参数由 es：bx al:读取的扇区数量不用指定固定填1 ch:磁道号 cl：扇区号 dh：磁头号 dl：驱动器号不用指定固定0x80
    call hdread1sec
    mov ax, es
    add ax, 0x20
    mov es, ax
    inc si
    cmp si, 4
    jne readdir
	pop di
	pop si
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret
	
; 读取文件结构扇区到es：dx位置
readfilemeta:
	push ax
	push bx
	push cx
	push dx
	push es
	push si
	push di
    mov si, 0 ;循环计数器，循环10次
read1filesec:
    mov ch, 0
    mov dh, 0
    ; 扇区号是17+si
    mov ax, si
    mov cl, 17
    add cl, al
    mov di, 0
    ; 读取一个扇区，参数由 es：bx al:读取的扇区数量不用指定固定填1 ch:磁道号 cl：扇区号 dh：磁头号 dl：驱动器号不用指定固定0x80
    call hdread1sec
    mov ax, es
    add ax, 0x20
    mov es, ax
    inc si
    cmp si, 10
    jne read1filesec
	pop di
	pop si
	pop es
	pop dx
	pop cx
	pop bx
	pop ax
	ret

; cddeal的自函数，用于判断是否为 cd ..命令
; 本函数不改变任何寄存器，只会改变e标志，是则e标志为1，否则e标志为0
ifcdupdir:
	push ax
	mov al, [inputcom+2]
	cmp al, ' '
	jne notcdupdir
	mov al, [inputcom+3]
	cmp al, '.'
	jne notcdupdir
	mov al, [inputcom+4]
	cmp al, '.'
	jne notcdupdir
	mov al, [inputcom+5]
	cmp al, '$'
	jne notcdupdir
iscdupdir:
	mov ah, 0
	mov al, 0
	cmp ah, al
	pop ax
	ret
notcdupdir:
	mov ah, 0
	mov al, 1
	cmp ah, al
	pop ax
	ret


times 1474048-($-$$) db 0
