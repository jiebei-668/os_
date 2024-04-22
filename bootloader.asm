org 0x7c00
jmp start
msgwelcome: db 'welcome to here', '$'
start:
    ; 初始化寄存器 很重要
    mov ax, 0
    mov ds, ax
    mov es, ax
    mov ss, ax
    mov sp, 0x7c00
    ; 打印cs值
    mov ch, 'c'
    mov cl, 's'
    mov dx, cs
    call printregister
    call newline
    ; 打印ds值
    mov ch, 'd'
    mov cl, 's'
    mov dx, ds
    call printregister
    call newline
    ; 打印es值
    mov ch, 'e'
    mov cl, 's'
    mov dx, es
    call printregister
    call newline
    ; 打印ss值
    mov ch, 's'
    mov cl, 's'
    mov dx, ss
    call printregister
    call newline
    ; 打印sp值
    mov ch, 's'
    mov cl, 'p'
    mov dx, sp
    call printregister
    call newline
    ; 打印欢迎信息
    mov si, msgwelcome
    ; lea si, msgwelcome
    call printstr
    call newline
    jmp $
    


       
; 打印si地址开头的字符串，字符串以'$'结尾
; si存首地址
; int 10h中 al放字符 ah放功能
printstr:
    mov al, [si]
    cmp al, '$'
    je .printstrover
    mov ah, 0eh
    int 10h
    inc si
    jmp printstr
.printstrover:
    ret

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

newline:
    mov ah, 0eh
    mov al, 13
    int 10h
    mov ah, 0eh
    mov al, 10
    int 10h



; al中存放的8位二进制数的高4位和低四位分别转化为16进制数以ascii形式存放，存放到dh和dl中，如0b1100_0011 -> c3
binarytohex:
    ; 提取高四位并转换为 ASCII 码
    mov ah, al        ; 将 al 中的值移动到 ah 寄存器中，备份 al 的值
    shr ah, 4         ; 将 ah 寄存器中的值右移 4 位，提取高四位
    and ah, 0x0F      ; 将 ah 寄存器中的值与 0x0F 进行按位与运算，保留低 4 位的值，高 4 位清零
    add ah, '0'       ; 将提取的四位值转换为 ASCII 码，'0' 的 ASCII 码值为 48
    cmp ah, '9'       ; 检查是否需要将字母 'A'-'F' 转换为相应的 ASCII 码
    jbe .convert_next  ; 如果小于等于 '9'，直接跳转到下一步
    add ah, 7         ; 如果大于 '9'，调整为 'A'-'F' 对应的 ASCII 码值
.convert_next:
    mov dh, ah        ; 将转换后的 ASCII 码值移动到 dh 寄存器中

    ; 提取低四位并转换为 ASCII 码
    mov al, al        ; 复制 al 中的值到 al 寄存器中，不进行任何操作
    and al, 0x0F      ; 将 al 寄存器中的值与 0x0F 进行按位与运算，保留低 4 位的值，高 4 位清零
    add al, '0'       ; 将提取的四位值转换为 ASCII 码
    cmp al, '9'       ; 检查是否需要将字母 'A'-'F' 转换为相应的 ASCII 码
    jbe .convert_done  ; 如果小于等于 '9'，直接跳转到结束
    add al, 7         ; 如果大于 '9'，调整为 'A'-'F' 对应的 ASCII 码值
.convert_done:
    mov dl, al        ; 将转换后的 ASCII 码值移动到 dl 寄存器中
    ret               ; 返回，结束函数


times 510-($-$$) db 0
db 0x55,0xaa

times 1474560-($-$$) db 0

