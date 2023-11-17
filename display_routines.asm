; ---------------------------------------------
;
;	A SET OF SCREEN and DSIPLAY  ROUTINES TO INCLUDE
;
; ---------------------------------------------

drawRect:
                                             ; prepare data to send
     ld ix, rectData

     ld a, (rectColour)

     ld (ix+2), a                            ; set colour of plot
     ld (ix+23), a                           ; set colour of plot

     ld a, (rectTop)
     ld (ix+7), a
     ld (ix+13), a
     ld (ix+40), a

     ld a, (rectLeft)
     ld (ix+5), a
     ld (ix+32), a
     ld (ix+38), a

     ld a, (rectBottom)
     ld (ix+19), a
     ld (ix+28), a
     ld (ix+34), a

     ld a, (rectRight)
     ld (ix+11), a 
     ld (ix+17), a 
     ld (ix+26), a

sendRectData:
     ld hl, rectData
     ld bc, endrectData - rectData
     rst.lil $18
     ret 

rectData:                               ; triangle updated from VDP 80 to 85
                                        ; ink colour
     .db 18, 0, 4                       ; IX, IX+2
                                        ; triangle 1
     .db  25,4,0,0,0,0                  ; LL +5, TT+7
     .db  25,4,0,0,0,0                  ; RR +11, TT +13
     .db  25,85,0,0,0,0                 ; RR +17, BB +19

tempend:
     .db 18, 0, 6                       ; IX, IX+2 21, 22,23
                                        ; triangle 2
     .db  25,4,0,0,0,0                  ; RR +26, BB +28
     .db  25,4,0,0,0,0                  ; LL +32, BB +34
     .db  25,85,0,0,0,0                 ; LL +38, TT +40
endrectData:

; in ADL mode we might need 3 bytes to store BC, etc
rectTop:       .db 0,0,0
rectLeft:      .db 0,0,0
rectBottom:    .db 0,0,0
rectRight:     .db 0,0,0

rectColour:    .db 0


; ---------------------------------------------

my_CLS:
    ; make sure cursor is hidden
    ; VDU 23,1,0
    ld a, 23
    rst.lil $10
    ld a, 1
    rst.lil $10
    ld a,0
    rst.lil $10 

    ; tab to 0,0
    ; VDU 31,13,0 ; tab pos
    ld a, 31
    rst.lil $10
    ld a, 0
    rst.lil $10
    ld a, 0
    rst.lil $10

    ld b, 30    ; number of lines, 25 on full screen, 40 columns wide. 30 for 320x240 v1.04

loophere:
    push bc
    ld hl, lineofspaces
    ld bc, endline - lineofspaces
    rst.lil $18
    pop bc
    djnz loophere

    ld a, 31
    rst.lil $10
    ld a, 0
    rst.lil $10
    ld a, 0
    rst.lil $10
    ret 

lineofspaces:

    .ds 40,32
endline:
     
; ---------------------------------------------

slow_CLS:
    ; make sure cursor is hidden
    ; VDU 23,1,0
    ld a, 23
    rst.lil $10
    ld a, 1
    rst.lil $10
    ld a,0
    rst.lil $10 

    ; tab to 0,0
    ; VDU 31,13,0 ; tab pos
    ld a, 31
    rst.lil $10
    ld a, 0
    rst.lil $10
    ld a, 0
    rst.lil $10

    ld b, 30    ; number of lines, 25 on full screen, 40 columns wide. 30 for 320x240

loophere2:
    push bc
    ld hl, lineofspaces
    ld bc, endline - lineofspaces
    rst.lil $18
 

    ld a, 00000100b
    call multiPurposeDelay

    pop bc
    djnz loophere2

    ld a, 31
    rst.lil $10
    ld a, 0
    rst.lil $10
    ld a, 0
    rst.lil $10
    ret 

; ---------------------------------------------

letterbox_CLS:
    ; make sure cursor is hidden
    ; VDU 23,1,0
    ld a, 23
    rst.lil $10
    ld a, 1
    rst.lil $10
    ld a,0
    rst.lil $10 



    ld b, 13    ; number of lines, 25 on full screen, 40 columns wide

letterbox2:
 
     ; tab to 0,0
     ; VDU 31,13,0 ; tab pos
     ld a, 31
     rst.lil $10
     ld a, 0
     rst.lil $10
     ld a, 13
     sub b 
     rst.lil $10

     push bc
     ld hl, lineofspaces
     ld bc, endline - lineofspaces
     rst.lil $18
     pop bc 

     ; tab to 0,0
     ; VDU 31,13,0 ; tab pos
;           ld a, 31
;           rst.lil $10
;           ld a, 0
;           rst.lil $10
;           ld a, 11
;           add a,b
;           rst.lil $10

;           push bc
;           ld hl, lineofspaces
;           ld bc, endline - lineofspaces
;           rst.lil $18
;           pop bc 

     push bc 
     ld a, 00001000b
     call multiPurposeDelay
     pop bc

     djnz letterbox2

     ld a, 31
     rst.lil $10
     ld a, 0
     rst.lil $10
     ld a, 0
     rst.lil $10    ; reset cursor position

     ret 

; ---------------------------------------------
;    SMOOTH CLEAR

smoothClear:
     ld bc, 0 
     ld (rectTop),bc
     ld bc, 0 
     ld (rectLeft),bc
     ld bc, 2 
     ld (rectBottom),bc
     ld bc, 800
     ld (rectRight),bc

     ld b, 198
     ld de, 2
smoothLoop:
     ld (rectBottom), de 

     push bc 
     push de 
     call drawRect
     pop de 
     pop bc 

     inc de         ; do next line

;      push bc 
;      ld a, 00000010b
;      call multiPurposeDelay
;      pop bc

     djnz smoothLoop

     ret 
; ---------------------------------------------

; colour test

coltest:
     ld a, 31  
     rst.lil $10
     ld a, 0
     rst.lil $10
     ld a, 0
     rst.lil $10    ; print at 0,0
     ; show colours in mode
     ld b, 64

colLoop:
     ld a, 17
     rst.lil $10    
     ld a, 64
     sub b     
     rst.lil $10    ; colour b
     ld a, 42
     rst.lil $10    ; send char *

     djnz colLoop


     ret 