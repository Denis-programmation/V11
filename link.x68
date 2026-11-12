*-----------------------------------------------------------
* Title      :
* Written by :
* Date       :
* Description:
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

* Put program code here
    ANDI.W  #%1101111111111111, SR  ; switch to user mode
    MOVE.L  #$01010101, D0
    MOVE.L  #$02020202, D1
    MOVE.L  #$03030303, D2
    MOVE.L  #$04040404, D3
    MOVE.L  #$05050505, D4
    MOVE.L  #$06060606, D5
    MOVE.L  #$07070707, D6
    MOVE.L  #$08080808, D7
    MOVE.L  #$09090909, A0
    MOVE.L  #$10101010, A1
    MOVEM.L D0-A1, -(SP)
    LINK    A6, #-168
    MOVE.L  D0, (SP)
    MOVE.L  D1, 4(SP)
    MOVE.L  D2, 8(SP)
    MOVE.L  A1, 156(SP)
    MOVE.L  #$01234567, 160(SP)
    MOVE.L  #$98765432, 164(SP)





    UNLK    A6

    SIMHALT             ; halt simulator

* Put variables and constants here

    END    START        ; last line of source





*~Font name~Fixedsys~
*~Font size~9~
*~Tab type~1~
*~Tab size~4~
