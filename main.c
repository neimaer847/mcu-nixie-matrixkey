#include <REGX52.H>
#include "Delay.h"
#include "MatrixKey.h"

/*
 * 任务：4x4矩阵键盘坐标显示在数码管上
 * 显示格式：数码管第1位显示行号，第2位显示"-"，第3位显示列号
 * 例如按下第2行第3列的按键 → 数码管显示 "2-3"
 *
 * 键码与坐标对应关系（MatrixKey返回1~16）：
 *   行 = (KeyNum - 1) / 4 + 1
 *   列 = (KeyNum - 1) % 4 + 1
 */

/* 数码管段码表（共阴极）：0~9 及 "-" */
unsigned char NixieTable[] = {
    0x3F, /* 0 */
    0x06, /* 1 */
    0x5B, /* 2 */
    0x4F, /* 3 */
    0x66, /* 4 */
    0x6D, /* 5 */
    0x7D, /* 6 */
    0x07, /* 7 */
    0x7F, /* 8 */
    0x6F, /* 9 */
    0x40  /* - (索引10) */
};

/* 当前显示的行号、列号（0表示还未按下任何键） */
unsigned char Row = 0;
unsigned char Col = 0;

/**
  * @brief  数码管动态显示驱动
  * @param  Location 位号 1~8（从左到右）
  * @param  Number   段码表索引（0~10，其中10为"-"）
  */
void Nixie(unsigned char Location, unsigned char Number)
{
    switch(Location)    /* 位码输出（P2_4 P2_3 P2_2 = 译码器输入） */
    {
        case 1: P2_4=1; P2_3=1; P2_2=1; break;
        case 2: P2_4=1; P2_3=1; P2_2=0; break;
        case 3: P2_4=1; P2_3=0; P2_2=1; break;
        case 4: P2_4=1; P2_3=0; P2_2=0; break;
        case 5: P2_4=0; P2_3=1; P2_2=1; break;
        case 6: P2_4=0; P2_3=1; P2_2=0; break;
        case 7: P2_4=0; P2_3=0; P2_2=1; break;
        case 8: P2_4=0; P2_3=0; P2_2=0; break;
    }
    P0 = NixieTable[Number]; /* 段码输出 */
    Delay(1);                /* 保持亮约1ms */
    P0 = 0x00;               /* 消影，防止鬼影 */
}

void main()
{
    unsigned char KeyNum;

    while(1)
    {
        /* 1. 扫描矩阵键盘 */
        KeyNum = MatrixKey();
        if(KeyNum)
        {
            /* 2. 键码转换为行列坐标 */
            Row = (KeyNum - 1) / 4 + 1; /* 行：1~4 */
            Col = (KeyNum - 1) % 4 + 1; /* 列：1~4 */
        }

        /* 3. 动态刷新数码管（每次主循环都刷新，保持显示） */
        if(Row != 0)
        {
            Nixie(1, Row); /* 第1位显示行号 */
            Nixie(2, 10);  /* 第2位显示 "-" */
            Nixie(3, Col); /* 第3位显示列号 */
        }
    }
}
