;---------------------------------------------------------
; 8051 Assembly equivalent of the Matrix Keyboard Nixie Display
; 
; 任务：4x4矩阵键盘坐标显示在数码管上
; 显示格式：数码管第1位显示行号，第2位显示"-"，第3位显示列号
; 例如按下第2行第3列的按键 → 数码管显示 "2-3"
;---------------------------------------------------------

    ORG 0000H
    LJMP MAIN

    ORG 0030H
MAIN:
    ; 初始化变量
    MOV R0, #0    ; R0 用作 Row (当前行号, 0表示未按下)
    MOV R1, #0    ; R1 用作 Col (当前列号)

MAIN_LOOP:
    ; 1. 扫描矩阵键盘
    LCALL MATRIX_KEY
    MOV A, R2     ; R2 存储 MATRIX_KEY 返回的键码
    JZ  REFRESH_NIXIE ; 如果 R2 == 0, 没有按键按下，直接刷新显示
    
    ; 2. 有按键按下，计算行列坐标
    ; 键码与坐标对应关系: Row = (KeyNum - 1) / 4 + 1; Col = (KeyNum - 1) % 4 + 1
    DEC A         ; A = KeyNum - 1
    MOV B, #4
    DIV AB        ; A = (KeyNum-1)/4 (即 Row-1), B = (KeyNum-1)%4 (即 Col-1)
    INC A
    MOV R0, A     ; R0 = Row
    INC B
    MOV R1, B     ; R1 = Col

REFRESH_NIXIE:
    ; 3. 动态刷新数码管（每次主循环都刷新，保持显示）
    MOV A, R0
    JZ  MAIN_LOOP ; 如果 Row == 0, 说明还没按过键，跳回继续扫描，不显示

    ; Nixie(1, Row)
    MOV A, R0
    MOV R7, A     ; R7 传参: Number
    MOV R6, #1    ; R6 传参: Location (第1位)
    LCALL NIXIE

    ; Nixie(2, 10) ; 显示 "-"
    MOV R7, #10   ; R7 传参: Number (10 为 "-" 在段码表的索引)
    MOV R6, #2    ; R6 传参: Location (第2位)
    LCALL NIXIE

    ; Nixie(3, Col)
    MOV A, R1
    MOV R7, A     ; R7 传参: Number
    MOV R6, #3    ; R6 传参: Location (第3位)
    LCALL NIXIE

    SJMP MAIN_LOOP

;---------------------------------------------------------
; void Nixie(Location, Number)
; Location 存在 R6, Number 存在 R7
;---------------------------------------------------------
NIXIE:
    ; 选择位码: switch(Location) -> P2_4 P2_3 P2_2
    MOV A, R6
    CJNE A, #1, NIXIE_L2
    SETB P2.4
    SETB P2.3
    SETB P2.2
    SJMP NIXIE_SHOW
NIXIE_L2:
    CJNE A, #2, NIXIE_L3
    SETB P2.4
    SETB P2.3
    CLR  P2.2
    SJMP NIXIE_SHOW
NIXIE_L3:
    CJNE A, #3, NIXIE_L4
    SETB P2.4
    CLR  P2.3
    SETB P2.2
    SJMP NIXIE_SHOW
NIXIE_L4:
    CJNE A, #4, NIXIE_L5
    SETB P2.4
    CLR  P2.3
    CLR  P2.2
    SJMP NIXIE_SHOW
NIXIE_L5:
    CJNE A, #5, NIXIE_L6
    CLR  P2.4
    SETB P2.3
    SETB P2.2
    SJMP NIXIE_SHOW
NIXIE_L6:
    CJNE A, #6, NIXIE_L7
    CLR  P2.4
    SETB P2.3
    CLR  P2.2
    SJMP NIXIE_SHOW
NIXIE_L7:
    CJNE A, #7, NIXIE_L8
    CLR  P2.4
    CLR  P2.3
    SETB P2.2
    SJMP NIXIE_SHOW
NIXIE_L8:
    CLR  P2.4
    CLR  P2.3
    CLR  P2.2
NIXIE_SHOW:
    ; 输出段码: P0 = NixieTable[Number]
    MOV DPTR, #NIXIE_TABLE
    MOV A, R7
    MOVC A, @A+DPTR
    MOV P0, A
    
    ; 延时: Delay(1)
    MOV R5, #1
    LCALL DELAY
    
    ; 消影: P0 = 0x00
    MOV P0, #0
    RET

; 共阴极数码管段码表 0~9 及 "-" (索引10)
NIXIE_TABLE:
    DB 3FH, 06H, 5BH, 4FH, 66H, 6DH, 7DH, 07H, 7FH, 6FH, 40H

;---------------------------------------------------------
; unsigned char MatrixKey()
; 返回值存在 R2 中，无按键按下则返回 0
;---------------------------------------------------------
MATRIX_KEY:
    MOV R2, #0    ; 默认键码 0

    ; 扫描第1行: P1_3 = 0
    MOV P1, #0FFH
    CLR P1.3
    JB P1.7, MK_R1_C2
    MOV R2, #1
    SJMP MK_FOUND_P17
MK_R1_C2:
    JB P1.6, MK_R1_C3
    MOV R2, #5
    SJMP MK_FOUND_P16
MK_R1_C3:
    JB P1.5, MK_R1_C4
    MOV R2, #9
    SJMP MK_FOUND_P15
MK_R1_C4:
    JB P1.4, MK_R2_START
    MOV R2, #13
    SJMP MK_FOUND_P14

MK_R2_START:
    ; 扫描第2行: P1_2 = 0
    MOV P1, #0FFH
    CLR P1.2
    JB P1.7, MK_R2_C2
    MOV R2, #2
    SJMP MK_FOUND_P17
MK_R2_C2:
    JB P1.6, MK_R2_C3
    MOV R2, #6
    SJMP MK_FOUND_P16
MK_R2_C3:
    JB P1.5, MK_R2_C4
    MOV R2, #10
    SJMP MK_FOUND_P15
MK_R2_C4:
    JB P1.4, MK_R3_START
    MOV R2, #14
    SJMP MK_FOUND_P14

MK_R3_START:
    ; 扫描第3行: P1_1 = 0
    MOV P1, #0FFH
    CLR P1.1
    JB P1.7, MK_R3_C2
    MOV R2, #3
    SJMP MK_FOUND_P17
MK_R3_C2:
    JB P1.6, MK_R3_C3
    MOV R2, #7
    SJMP MK_FOUND_P16
MK_R3_C3:
    JB P1.5, MK_R3_C4
    MOV R2, #11
    SJMP MK_FOUND_P15
MK_R3_C4:
    JB P1.4, MK_R4_START
    MOV R2, #15
    SJMP MK_FOUND_P14

MK_R4_START:
    ; 扫描第4行: P1_0 = 0
    MOV P1, #0FFH
    CLR P1.0
    JB P1.7, MK_R4_C2
    MOV R2, #4
    SJMP MK_FOUND_P17
MK_R4_C2:
    JB P1.6, MK_R4_C3
    MOV R2, #8
    SJMP MK_FOUND_P16
MK_R4_C3:
    JB P1.5, MK_R4_C4
    MOV R2, #12
    SJMP MK_FOUND_P15
MK_R4_C4:
    JB P1.4, MK_END
    MOV R2, #16
    SJMP MK_FOUND_P14

MK_END:
    MOV R2, #0
    RET

; 按键去抖动及松手检测逻辑 (按键按下后的处理)
; 根据具体哪一列触发 (P1.7 ~ P1.4) 分别等待对应引脚释放
MK_FOUND_P17:
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
MK_WAIT_P17:
    JNB P1.7, MK_WAIT_P17 ; while(P1_7==0)
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
    RET

MK_FOUND_P16:
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
MK_WAIT_P16:
    JNB P1.6, MK_WAIT_P16 ; while(P1_6==0)
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
    RET

MK_FOUND_P15:
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
MK_WAIT_P15:
    JNB P1.5, MK_WAIT_P15 ; while(P1_5==0)
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
    RET

MK_FOUND_P14:
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
MK_WAIT_P14:
    JNB P1.4, MK_WAIT_P14 ; while(P1_4==0)
    MOV R5, #20
    LCALL DELAY           ; Delay(20)
    RET

;---------------------------------------------------------
; void Delay(unsigned int xms)
; 延时参数存在 R5 中
;---------------------------------------------------------
DELAY:
    MOV A, R5
    JZ DELAY_END          ; 如果 R5 是 0，直接返回
DELAY_LOOP1:
    MOV R4, #2            ; i = 2
DELAY_LOOP2:
    MOV R3, #239          ; j = 239
DELAY_LOOP3:
    DJNZ R3, DELAY_LOOP3  ; while(--j)
    DJNZ R4, DELAY_LOOP2  ; while(--i)
    DJNZ R5, DELAY_LOOP1  ; while(xms--)
DELAY_END:
    RET

    END
