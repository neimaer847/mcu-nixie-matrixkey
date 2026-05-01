;---------------------------------------------------------
; 8051 Assembly equivalent of the Matrix Keyboard Nixie Display
; 
; 任务：4x4矩阵键盘坐标显示在数码管上
; 显示格式：数码管第1位显示行号，第2位显示"-"，第3位显示列号
; 例如按下第2行第3列的按键 → 数码管显示 "2-3"
;---------------------------------------------------------

    ORG 0000H       ; 程序起始地址设为 0000H（复位后从这里开始执行）
    LJMP MAIN       ; 长跳转到主程序 MAIN 处，跳过中断向量表区域

    ORG 0030H       ; 主程序实际起始地址设在 0030H，避开 0000H~002FH 的中断向量区
MAIN:
    ; 初始化变量（使用寄存器存储状态）
    MOV R0, #0      ; 将寄存器 R0 清零，用作 Row (当前行号)，0 表示未按过任何键
    MOV R1, #0      ; 将寄存器 R1 清零，用作 Col (当前列号)

MAIN_LOOP:
    ; 1. 扫描矩阵键盘
    LCALL MATRIX_KEY; 调用矩阵键盘扫描子程序 MATRIX_KEY
    MOV A, R2       ; 将子程序返回的键码（存在 R2 中）转移到累加器 A
    JZ  REFRESH_NIXIE ; 如果 A=0 (没有按键按下)，则直接跳转去刷新数码管，不更新行列值
    
    ; 2. 有按键按下，计算行列坐标
    ; 键码与坐标对应关系: Row = (KeyNum - 1) / 4 + 1; Col = (KeyNum - 1) % 4 + 1
    DEC A           ; A = KeyNum - 1 （为了方便计算，先把键码 1~16 变成 0~15）
    MOV B, #4       ; 将寄存器 B 赋值为 4（矩阵键盘一行的按键数）
    DIV AB          ; 触发除法指令 A/B：商 (Row-1) 存入 A，余数 (Col-1) 存入 B
    INC A           ; A = A + 1，得到实际的行号 (Row)
    MOV R0, A       ; 将计算好的行号存入 R0，更新显示的行坐标
    INC B           ; B = B + 1，得到实际的列号 (Col)
    MOV R1, B       ; 将计算好的列号存入 R1，更新显示的列坐标

REFRESH_NIXIE:
    ; 3. 动态刷新数码管（每次主循环都刷新，保持显示不灭）
    MOV A, R0       ; 把当前行号 R0 取出到 A 中
    JZ  MAIN_LOOP   ; 如果 A=0（即 Row=0），说明开机到现在还没按过任何键，跳回继续扫描，暂不显示

    ; 显示第1位：行号
    ; 对应 C 语言: Nixie(1, Row)
    MOV A, R0       ; 取出当前行号 Row
    MOV R7, A       ; 将要显示的数字 (Row) 存入 R7，作为 NIXIE 子程序的 Number 参数
    MOV R6, #1      ; 将显示位置 1 存入 R6，作为 NIXIE 子程序的 Location 参数
    LCALL NIXIE     ; 调用数码管显示子程序

    ; 显示第2位："-"
    ; 对应 C 语言: Nixie(2, 10)
    MOV R7, #10     ; 将数字 10（在段码表中对应 "-"）存入 R7 作为参数
    MOV R6, #2      ; 将显示位置 2 存入 R6 作为参数
    LCALL NIXIE     ; 调用数码管显示子程序

    ; 显示第3位：列号
    ; 对应 C 语言: Nixie(3, Col)
    MOV A, R1       ; 取出当前列号 Col
    MOV R7, A       ; 将要显示的数字 (Col) 存入 R7 作为参数
    MOV R6, #3      ; 将显示位置 3 存入 R6 作为参数
    LCALL NIXIE     ; 调用数码管显示子程序

    SJMP MAIN_LOOP  ; 短跳转回 MAIN_LOOP，开启下一轮键盘扫描和数码管刷新

;---------------------------------------------------------
; 子程序：Nixie 数码管单管显示
; 功能：在指定位置显示指定数字
; 参数传入：Location 存在 R6 中, Number（显示的数字或符号）存在 R7 中
;---------------------------------------------------------
NIXIE:
    ; (1) 根据位置 Location (R6) 选择对应的位码 (74HC138 译码器输入 P2.4, P2.3, P2.2)
    MOV A, R6       ; 将 Location 取出到 A 中
    CJNE A, #1, NIXIE_L2 ; 如果 Location 不等于 1，则跳转到 NIXIE_L2 检查是否为 2
    ; Location == 1 时执行以下指令：
    SETB P2.4       ; P2.4 = 1 (对应 74HC138 的 C 引脚)
    SETB P2.3       ; P2.3 = 1 (对应 74HC138 的 B 引脚)
    SETB P2.2       ; P2.2 = 1 (对应 74HC138 的 A 引脚) (CBA=111, 选中第1位数码管)
    SJMP NIXIE_SHOW ; 位码设置完毕，跳转到段码输出部分
NIXIE_L2:
    CJNE A, #2, NIXIE_L3 ; 如果 Location 不等于 2，跳转到下一层判断
    SETB P2.4       ; C = 1
    SETB P2.3       ; B = 1
    CLR  P2.2       ; A = 0 (CBA=110, 选中第2位数码管)
    SJMP NIXIE_SHOW
NIXIE_L3:
    CJNE A, #3, NIXIE_L4
    SETB P2.4       ; C = 1
    CLR  P2.3       ; B = 0
    SETB P2.2       ; A = 1 (CBA=101, 选中第3位数码管)
    SJMP NIXIE_SHOW
NIXIE_L4:
    CJNE A, #4, NIXIE_L5
    SETB P2.4       ; C = 1
    CLR  P2.3       ; B = 0
    CLR  P2.2       ; A = 0 (CBA=100, 选中第4位数码管)
    SJMP NIXIE_SHOW
NIXIE_L5:
    CJNE A, #5, NIXIE_L6
    CLR  P2.4       ; C = 0
    SETB P2.3       ; B = 1
    SETB P2.2       ; A = 1 (CBA=011, 选中第5位数码管)
    SJMP NIXIE_SHOW
NIXIE_L6:
    CJNE A, #6, NIXIE_L7
    CLR  P2.4       ; C = 0
    SETB P2.3       ; B = 1
    CLR  P2.2       ; A = 0 (CBA=010, 选中第6位数码管)
    SJMP NIXIE_SHOW
NIXIE_L7:
    CJNE A, #7, NIXIE_L8
    CLR  P2.4       ; C = 0
    CLR  P2.3       ; B = 0
    SETB P2.2       ; A = 1 (CBA=001, 选中第7位数码管)
    SJMP NIXIE_SHOW
NIXIE_L8:           ; 如果上面的都不匹配，默认就是第 8 位
    CLR  P2.4       ; C = 0
    CLR  P2.3       ; B = 0
    CLR  P2.2       ; A = 0 (CBA=000, 选中第8位数码管)

NIXIE_SHOW:
    ; (2) 输出段码：根据 Number 查表，点亮对应笔段
    MOV DPTR, #NIXIE_TABLE ; 将段码表的首地址送入数据指针 DPTR
    MOV A, R7       ; 将要显示的数字 Number 送入 A
    MOVC A, @A+DPTR ; 查表指令：A = 程序存储器中地址为 (DPTR + A) 处的数据
    MOV P0, A       ; 将查到的段码输出到 P0 端口，点亮数码管对应段
    
    ; (3) 显示延时：保持一小段时间让肉眼能看到光亮
    MOV R5, #1      ; 传入延时参数 xms = 1
    LCALL DELAY     ; 调用延时 1ms 子程序
    
    ; (4) 消影处理：关闭段码输出，防止下一位显示时发生重影（拖尾现象）
    MOV P0, #0      ; 将 P0 端口清零（共阴极数码管送低电平关闭所有段）
    RET             ; 子程序返回

; 共阴极数码管段码表：索引对应 0~9, 10对应"-"
NIXIE_TABLE:
    ;   0    1    2    3    4    5    6    7    8    9    "-"
    DB 3FH, 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H, 7FH, 6FH, 40H

;---------------------------------------------------------
; 子程序：MatrixKey 矩阵键盘扫描
; 功能：扫描 4x4 矩阵键盘，返回按下按键的键码 (1~16)
; 返回值：键码保存在 R2 中，若无按键按下则返回 0
;---------------------------------------------------------
MATRIX_KEY:
    MOV R2, #0      ; 初始化返回值 R2 = 0，默认认为无按键按下

    ; 扫描第1行 (R1): 将 P1.3 拉低，其他列默认拉高
    MOV P1, #0FFH   ; 先将 P1 端口全置 1 (1111 1111)
    CLR P1.3        ; P1.3 = 0，使得第一行输出低电平
    JB P1.7, MK_R1_C2 ; 如果 P1.7 为高电平 (没按下第1列)，跳转去测第2列
    MOV R2, #1      ; 如果 P1.7 为低，说明 (第1行, 第1列) 按键按下，键码置为 1
    LJMP MK_FOUND_P17 ; 长跳转到去抖动和松手检测逻辑 (对应 P1.7 列)
MK_R1_C2:
    JB P1.6, MK_R1_C3 ; 检查 P1.6 (第2列)，若未按下则跳过
    MOV R2, #5      ; (第1行, 第2列) 键码为 5
    LJMP MK_FOUND_P16 ; 跳转去松手检测
MK_R1_C3:
    JB P1.5, MK_R1_C4 ; 检查 P1.5 (第3列)
    MOV R2, #9      ; (第1行, 第3列) 键码为 9
    LJMP MK_FOUND_P15
MK_R1_C4:
    JB P1.4, MK_R2_START ; 检查 P1.4 (第4列)，若全都没按，跳去扫描第 2 行
    MOV R2, #13     ; (第1行, 第4列) 键码为 13
    LJMP MK_FOUND_P14

MK_R2_START:
    ; 扫描第2行 (R2): 将 P1.2 拉低
    MOV P1, #0FFH   ; P1 全置 1，恢复上一行的状态
    CLR P1.2        ; P1.2 = 0，使得第二行输出低电平
    JB P1.7, MK_R2_C2 ; 检查第1列 (P1.7)
    MOV R2, #2      ; (第2行, 第1列) 键码为 2
    LJMP MK_FOUND_P17
MK_R2_C2:
    JB P1.6, MK_R2_C3 ; 检查第2列 (P1.6)
    MOV R2, #6      ; (第2行, 第2列) 键码为 6
    LJMP MK_FOUND_P16
MK_R2_C3:
    JB P1.5, MK_R2_C4 ; 检查第3列 (P1.5)
    MOV R2, #10     ; (第2行, 第3列) 键码为 10
    LJMP MK_FOUND_P15
MK_R2_C4:
    JB P1.4, MK_R3_START ; 检查第4列 (P1.4)
    MOV R2, #14     ; (第2行, 第4列) 键码为 14
    LJMP MK_FOUND_P14

MK_R3_START:
    ; 扫描第3行 (R3): 将 P1.1 拉低
    MOV P1, #0FFH   ; 恢复 P1
    CLR P1.1        ; P1.1 = 0，使得第三行输出低电平
    JB P1.7, MK_R3_C2 ; 检查第1列
    MOV R2, #3      ; (第3行, 第1列) 键码为 3
    LJMP MK_FOUND_P17
MK_R3_C2:
    JB P1.6, MK_R3_C3 ; 检查第2列
    MOV R2, #7      ; (第3行, 第2列) 键码为 7
    LJMP MK_FOUND_P16
MK_R3_C3:
    JB P1.5, MK_R3_C4 ; 检查第3列
    MOV R2, #11     ; (第3行, 第3列) 键码为 11
    LJMP MK_FOUND_P15
MK_R3_C4:
    JB P1.4, MK_R4_START ; 检查第4列
    MOV R2, #15     ; (第3行, 第4列) 键码为 15
    LJMP MK_FOUND_P14

MK_R4_START:
    ; 扫描第4行 (R4): 将 P1.0 拉低
    MOV P1, #0FFH   ; 恢复 P1
    CLR P1.0        ; P1.0 = 0，使得第四行输出低电平
    JB P1.7, MK_R4_C2 ; 检查第1列
    MOV R2, #4      ; (第4行, 第1列) 键码为 4
    LJMP MK_FOUND_P17
MK_R4_C2:
    JB P1.6, MK_R4_C3 ; 检查第2列
    MOV R2, #8      ; (第4行, 第2列) 键码为 8
    LJMP MK_FOUND_P16
MK_R4_C3:
    JB P1.5, MK_R4_C4 ; 检查第3列
    MOV R2, #12     ; (第4行, 第3列) 键码为 12
    LJMP MK_FOUND_P15
MK_R4_C4:
    JB P1.4, MK_END ; 检查第4列，如果也未按，跳转到 MK_END (返回 0)
    MOV R2, #16     ; (第4行, 第4列) 键码为 16
    LJMP MK_FOUND_P14

MK_END:
    MOV R2, #0      ; 如果 16 个按键都没按下，确认键码为 0
    RET             ; 子程序返回，带回 R2=0

; 按键去抖动及松手检测逻辑
; 因为 4 列分别对应 P1.7 ~ P1.4 引脚，需要分类处理等待对应引脚变为高电平（松手）
MK_FOUND_P17:
    MOV R5, #20     ; 设置参数 xms = 20
    LCALL DELAY     ; 延时 20ms (按键按下消抖)
MK_WAIT_P17:
    JNB P1.7, MK_WAIT_P17 ; 如果 P1.7==0 (还按着)，就在这里死循环等待松手
    MOV R5, #20     ; 松手后
    LCALL DELAY     ; 延时 20ms (按键松开消抖)
    RET             ; 返回子程序，此时 R2 中已经保存了检测到的键码

MK_FOUND_P16:
    MOV R5, #20     ; 按下消抖
    LCALL DELAY     
MK_WAIT_P16:
    JNB P1.6, MK_WAIT_P16 ; 循环等待 P1.6 引脚变高电平 (松手)
    MOV R5, #20     ; 松开消抖
    LCALL DELAY     
    RET             

MK_FOUND_P15:
    MOV R5, #20     ; 按下消抖
    LCALL DELAY     
MK_WAIT_P15:
    JNB P1.5, MK_WAIT_P15 ; 循环等待 P1.5 引脚变高电平 (松手)
    MOV R5, #20     ; 松开消抖
    LCALL DELAY     
    RET             

MK_FOUND_P14:
    MOV R5, #20     ; 按下消抖
    LCALL DELAY     
MK_WAIT_P14:
    JNB P1.4, MK_WAIT_P14 ; 循环等待 P1.4 引脚变高电平 (松手)
    MOV R5, #20     ; 松开消抖
    LCALL DELAY     
    RET             

;---------------------------------------------------------
; 子程序：Delay 软件延时 (适用于 11.0592MHz / 12MHz 晶振)
; 功能：提供 x 毫秒级别的延时
; 参数传入：延时毫秒数存在 R5 中
;---------------------------------------------------------
DELAY:
    MOV A, R5       ; 将延时参数移动到 A 中以判断是否为 0
    JZ DELAY_END    ; 如果 R5 是 0，则不需要延时，直接跳到末尾返回
DELAY_LOOP1:        ; 外层循环，控制毫秒数 (对应 C 中的 while(xms--))
    MOV R4, #2      ; i = 2 （内层循环变量初始化）
DELAY_LOOP2:        ; 中层循环 (对应 C 中的 while(--i))
    MOV R3, #239    ; j = 239 （最内层循环变量初始化）
DELAY_LOOP3:        ; 最内层循环 (对应 C 中的 while(--j))
    DJNZ R3, DELAY_LOOP3 ; j 自减并判断，如果不为 0 则继续执行本条指令 (耗费 2 个机器周期)
    DJNZ R4, DELAY_LOOP2 ; i 自减并判断，不为 0 则跳回内层初始化处
    DJNZ R5, DELAY_LOOP1 ; 毫秒数自减并判断，不为 0 则跳回外层初始化处
DELAY_END:
    RET             ; 延时完毕，返回主程序

    END             ; 告诉汇编器源码到此结束
