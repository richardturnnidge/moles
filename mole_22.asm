	; AGON CONSOLE8
	; Mouse test game
	; Richard Turnnidge 2023

	; uses less sprites.
	; v0.20 stripped out debugging and commented code

	include "macros.inc"

	.assume adl=1					; big memory mode
	.org $40000					; load code here

	jp start_here					; jump to start of code

	.align 64					; MOS header
	.db "MOS",0,1

; ---------------------------------------------
;
;	INITIAL SETUP CODE HERE
;
; ---------------------------------------------
	; extra code files needed for sub-routines
	include "math_routines.asm"
	include "font_routines.asm"
	include "debug_routines.asm"
	include "delay_routines.asm"
	include "display_routines.asm"			

start_here:
							; store everything as good practice
							; pop back when we return from code later
	push af
	push bc
	push de
	push ix
	push iy


	MOSCALL $08             			; get IX pointer to sysvars

; ---------------------------------------------
;
;	PREP
;
; ---------------------------------------------

							; sets to MODE 2
	ld hl, setupScreen				; start of data to send
	ld bc, endSetupScreen - setupScreen		; length of data to send
	rst.lil $18					; send data

	ld a, 12
	rst.lil $10					; CLS

	call hidecursor
	call initMouse
	call setUpBuffer
	call loadBitmaps
	call setupSprites
	call load_font	
	call defineDiamondChar				; old code, but sets up customer UDG
	
							; try loading high score file
	ld hl, fname           				; file name
	ld de, highScore      				; were to load data
	ld bc, 1                			; bytes to read

	MOSCALL $01

	cp 0
	jr z, gotFile   				; file opened ok

							; if not, create it

	ld hl, fname            			; file name
	ld de, highScore        			; were to get data
	ld bc, 1                			; bytes to read

	MOSCALL $02  ; save

gotFile:
							; finally ready to begin :-)

; ---------------------------------------------
;
;	ENTER MENU SCREEN
;
; ---------------------------------------------

	ld a, 80					; set vertical position of big title graphic
	ld (titlePos + 1),a 
	call predrawTitle				; prep data fro big graphic
	call drawTitle					; draw big graphical title

							; show other title text on screen
	ld hl, title_str				; data to send
	ld bc, end_title - title_str			; length of data
	rst.lil $18
	call hideTheSprites
	call quickRefresh
; ---------------------------------------------
;
;	MENU SCREEN LOOP
;
; ---------------------------------------------

MENU_LOOP:						; check keys pressed

	MOSCALL $08					; get IX pointer to sysvars
	ld a, (ix + 05h)				; ix+5h is 'last key pressed'

	cp 27						; is it ESC key?
	jp z, exit_here					; if so exit cleanly

	cp 115						; is it 'S' key to start? 115 is lower case S
	jr nz, MENU_LOOP				; if not, wait in this loop

; ---------------------------------------------
;
;	ENTER GAME SETUP
;
; ---------------------------------------------

ENTER_GAME:

	ld a,0
	ld (end_game),a 				; reset flag

	ld a,0
	ld (start_game),a 				; reset flag

	ld a,0
	ld (moleScore),a 				; reset current score

	or a 
	ld a, $31
	daa
	ld (currentTimer),a 				; reset timer

	call draw_cobbles				; draw background texture full screen
	call moveMoles					; set mole positions on screen

	ld a, spadeSprite				; set default mouse position
	ld (which_sprite),a 

	ld a, 100
	ld (sprite_x),a 				; put byte into x pos LSB

	ld a, 0
	ld (sprite_x + 1),a 				; put byte into x pos MSB

	ld a, 100
	ld (sprite_y),a 				; put byte into y pos LSB

	ld a, 0
	ld (sprite_y + 1),a 				; put byte into y pos MSB

	call draw_sprite				; draw the spade sprite 

					
	ld hl, clockData				; init clock data
	MOSCALL $08					; get IX pointer to sysvars
	ld ix, clockData
	ld a, (ix + 23)					; seconds counter in string
	ld (lastTick),a 				; set initial tick

					
	ld hl, showSpade				; show spade cursor
	ld bc, endShowSpade - showSpade
 	rst.lil $18					

 							
	ld hl, game_str					; show game text at bottom of screen
	ld bc, end_game_str - game_str			
	rst.lil $18

	ld a, 0						; set vertical position of big title graphic
	ld (titlePos + 1),a 
	call drawTitle					; draw big title

	call printScore					; print current score
	call printHighScore				; print high score

; ---------------------------------------------
;
;	MAIN GAME LOOP
;
; ---------------------------------------------

MAIN_LOOP:

	call checkForTick				; every second it will tick

get_key_input:
	MOSCALL $08					; get IX pointer to sysvars
	ld a, (ix + 05h)				; ix+5h is 'last key pressed'

	cp 27						; is it ESC key?
	jp z, exit_here					; if so exit cleanly

	call check_mouse				; check for all mouse movements and button clicks
				
	ld a, 00000100b					; delay byte, wait for this bit to change in clock
	call multiPurposeDelay				; delay so not too fast		

	ld a, (currentTimer)				; get countdown timer
	cp 0						
	jr z, ENTER_END_GAME				; end game if got to 0

	jp MAIN_LOOP					; loop round during game

; ---------------------------------------------
;
;	END GAME SETUP
;
; ---------------------------------------------

ENTER_END_GAME:

	call hideTheSprites
	call quickRefresh
	MAKEARECT 55,102,131,226,29 			; draw green drop shadow
	MAKEARECT 53,100,129,224,0			; draw black box

	ld hl, start_overlay
	ld bc, end_overlay - start_overlay
	rst.lil $18					; print overlay text

							; try to save high score, whether any better or not

	ld hl, fname            			; file name
	MOSCALL $05  					; delete old file	

	ld a, 00010000b
	call multiPurposeDelay				; wait a moment for MOS & SD to catch up


	ld hl, fname            			; file name
	ld de, highScore       				; were to get data
	ld bc, 1                			; bytes to save

	MOSCALL $02  					; save new file

							; Now go into overlay and wait 

; ---------------------------------------------
;
;	END GAME LOOP
;
; ---------------------------------------------

END_GAME_OVERLAY:

	ld a, (end_game)				; check if exit flag was set
	cp 1
	jp z, exit_here					; if so, exit cleany

	call check_keyboard_input			; check if player wants another go or exit

	ld a, (start_game)				; check if startgame flag was set
	cp 1
	jp z, ENTER_GAME				; start game again

	jr END_GAME_OVERLAY				; wait in this loop

quickRefresh:
				; this routine makes no sense at all, but was needed
				; it just printed a SPACE at the bottom right of the screen
	push af			; store AF

	ld a, 31		; TAB at x,y
	rst.lil $10
	ld a, 33		; x=33
	rst.lil $10
	ld a, 29		; y=24
	rst.lil $10		

	ld a, 32
	rst.lil $10		; print 'SPACE'

	pop af 			; ***
	ret 

; ---------------------------------------------

start_overlay:

	.db	17,15					; Text Colour white
 	.db	31,13,07				; tab pos
 	.db	"%$$$$$$$$$$$$$%"
 	.db	31,13,08				; tab pos
 	.db	"#             #"
	.db	31,13,9					; tab pos
	.db	"#  GAME OVER  #"
 	.db	31,13,10				; tab pos
 	.db	"#             #"
	.db	31,13,11				; tab pos
	.db	"# S to Start  #"
 	.db	31,13,12				; tab pos
 	.db	"#             #"
	.db	31,13,13				; tab pos
	.db	"# ESC to Quit #"
 	.db	31,13,14				; tab pos
 	.db	"#             #"
 	.db	31,13,15				; tab pos
 	.db	"%$$$$$$$$$$$$$%"

end_overlay:

end_game:	.db 	0				; exit game flag
start_game:	.db 	0				; start game flag

; ---------------------------------------------

check_keyboard_input:
	MOSCALL $08					; get IX pointer to sysvars
	ld a, (ix + 18h)				; get key state, 0 or 1
	cp 0						; are keys up, none currently pressed?
	ret z 						; nothing is currently pressed

	MOSCALL $08					; get IX pointer to sysvars
	ld a, (ix + 05h)				; ix+5h is 'last key pressed'

	cp 115						; is it 's'
	jr nz , chk1					; nope

	ld a,1						; was ESC key
	ld (start_game),a
	ret 

chk1:
	cp 27						; is it 'ESC'
	ret nz 						; nope

	ld a,1						; was s key
	ld (end_game),a 				; set flag to start again

	ret 

; ---------------------------------------------

updateClock:

	ld hl, clockData
	MOSCALL $08					; clock string up to 32 bytes gets loaded to HL memory location

	ld ix, clockData
	ld a, (ix + 23)					; +23 is last digit, of the second counter

	ret 

clockData:						
	.ds 32,32 					; string of bytes for data to live in from sys clock

; ---------------------------------------------

checkForTick:

	ld hl, clockData
	MOSCALL $12					; get RTC string and put into HL
	ld ix, clockData
	ld b, (ix + 23)					; second counter in string AT clockData

	ld a, (lastTick)
	cp b 						; is it the same as before

	ret z 						; yes, so step out
		
	ld a,b						; not same, so time has ticked
	ld (lastTick),a 				; update last tick
	call tick					; call tick routine

	ret 

lastTick: .db 0

; ---------------------------------------------

tick:							; called once per second

	or a 						; clear flags or DAA doesn't work correctly
	ld a, (currentTimer)

	dec a 
	daa 
	ld (currentTimer),a 				; update time in decimal

	call printTimer

	LD A, (currentMoleTime) 			; which event we are doing
							; check next sprite to show and update them. 
	ld b, 0 					; Assume 8 moles.
	ld ix, moleTimings				; list of binary moles
							; loop through each bit and set visible of each mole

	ld (moleIndex + 2), a
moleIndex:
	ld a, (ix + 0)					; mole index DD 7E xx so set xx (+2 offset) to current binary	
							; a should now have byte of next vsible moles
	ld (moleBinary),a 
	ld (currentMoleBinary),a 			; store for use if clicking
moleLoop:
	ld a, (moleBinary)	
	push af
	ld a, b 					; a now has mole number
	ld (whichMole), a 				; select the mole we want
	pop af						; A has binary again

	bit 0, a 					; set or not?

	jr z, mHide
mShow:
	ld a, 11
	ld (showHideMole),a 				; 11 is to show
	jr mDone

mHide:
	ld a, 12 					; 12 is to hide
	ld (showHideMole),a

mDone:
	push bc 
	ld hl, toggleMole
	ld bc, endToggleMole - toggleMole
	rst.lil $18					; call the hide/show mole routine
	pop bc

	ld a, (moleBinary)
	rra 						; shift binary ready for nwext mole check
	ld (moleBinary),a

	inc b  
	ld a, b 
	cp 8 						; have we done all 8 moles?
	jr nz, moleLoop


				
	ld a, (currentMoleTime) 
	inc a 						; increase position counter in list
	cp 30
	jr nz, tick2

	ld a,0						; reset if reached end of list (30 items)
tick2:		
	
	ld (currentMoleTime),a 				; update currentMoleTime

	ret 

; ---------------------------------------------

currentMoleBinary:	.db 0				; store current moles visible
moleCount:		.db 0

; ---------------------------------------------

toggleMole:
			.db 	23,27,4			; select mole
whichMole:		.db 	0

			.db 	23,27,10,0 		; set frame 0

			.db 	23,27			; show/hide visibility
showHideMole:		.db 	11			; 11 to show, 12 to hide

endToggleMole:


moleBinary:
			.db 	00000000b		; store current binary of events here

; ---------------------------------------------

setUpBuffer:
	ld hl, bufferData				; prepare buffered bitmap area
	ld bc, endBufferData - bufferData
	rst.lil $18

	ret 

; ---------------------------------------------

bufferData:
		; write block to buffer

	.db 	23,0,$A0 				; write block
	.dw 	1 					; ID (word)
	.db 	0	 				; 'write' command
	.dw 	bufferDataEnd - bufferDataStart		; length
bufferDataStart:
	include "title.asm"
bufferDataEnd:
							; - convert buffer block to bitmap with ID
	.db 	23,27,$20 				; select buffer bitmap to use
	.dw 	10					; ID (word) will be added to 64000 = 64010 = $FA $0A

							; - create a bitmap from that ID
	.db 	23,27,$21 				; create bitmap from buffer
	.dw 	320, 48 				; width, height (both words)
	.db 	2 					; format (2=mono)		

endBufferData:

; ---------------------------------------------
;
;	CHECK MOUSE ROUTINES
;
; ---------------------------------------------

check_mouse:

	MOSCALL $08					; get IX pointer to sysvars

							; check if mouse has changed - only need to check LSB
	ld a,  (oldMouseX)
	cp (ix + 29h)					; mouse pos x LSB
	jr nz, updateSpadePosition

	ld a,  (oldMouseY)
	cp (ix + 2Bh)					; mouse pos x LSB
	jr nz, updateSpadePosition


	jp checkMouseButtons				; neither direction changed, so skip over to buttons


updateSpadePosition:
			
	ld hl, oldMouseX				; update mouse/spade position

	ld a, spadeSprite
	ld (which_sprite),a 

	ld a, (ix + 29h)
	ld (sprite_x),a 				; put byte into x pos LSB
	ld (hl), a 					; update old position
	inc hl

	ld a,  (ix + 2Ah)
	ld (sprite_x + 1),a 				; put byte into x pos MSB
	ld (hl), a 					; update old position
	inc hl

	ld a,  (ix + 2Bh)
	ld (sprite_y),a 				; put byte into y pos LSB
	ld (hl), a 					; update old position
	inc hl

	ld a,  (ix + 2Ch)
	ld (sprite_y + 1),a 				; put byte into y pos MSB
	ld (hl), a 					; update old position

	call draw_sprite				; move it to new position


checkMouseButtons:

	ld a, (ix + 2Dh)				; mouse button data
	and 00000001b					; isolate left button
	ld (btnStatus),a
	bit 0, a 					; is it pressed?

	jr z, saysUp					; or not


saysDown:

	ld hl, btnLast					; get btn last status mem loc
	ld a, (btnStatus)				; get current btn status
	cp (hl)						; are they the same?
	call nz, btnDown				; no? then we pressed DOWN

	jr endCheck

saysUp:	

	ld hl, btnLast					; get btn last status mem loc
	ld a, (btnStatus)				; get current btn status
	cp (hl)						; are they the same?
	call nz, btnUp					; no? then btn went UP

endCheck:

	ret

hitRange:	equ 	20				; how close a mouse hit needs to be

; ---------------------------------------------

btnDown:
	ld hl, btnLast
	ld (hl), 1 					; HL is btnLast status
	ld a, 0
	ld (localCount),a
	ld hl, molePositions 				; start of mole position data, XX, YY (words)
	ld a, (currentMoleBinary)			; binary list of visible moles C =mole binary
	ld (localBinary),a 				; just used in this loop


hitLoop:						; go round 8 times, each mole

	ld a, (hl)					; x pos of target n, low byte
	inc hl 
	inc hl 						; get HL ready for Y position

	add a, 20					; get centre, it is 40px wide

	ld d,a 						; D has X centre of a mole sprite

	ld a,  (oldMouseX)				; this is a word, LSB first, which we only need
	add a, 16					; get centre, it is 32px wide
	sub d 						; a = mouse - target

	call get_ABS_a					; make positive if neg. 
							; A is now difference bewteeen centre of mouse and centre of mole

	cp hitRange					; is it closer than '16' (or hitRange)

	jr nc, no_x_hit					; nope, try y pos next



	ld a, (hl)					; y pos of target X, low byte
	inc hl 
	inc hl 
	add a, 20					; get centre

	ld d,a
	ld a,  (oldMouseY)				; this is a word, LSB first, which we only need
	add a, 16					; get centre
	sub d 						; a = mouse - target

	call get_ABS_a					; check if neg
	cp hitRange					; is it closer than 32 (or hitRange)

	jr nc, no_hit					; nope, carry on then

							; GOT A HIT ! need to check if actually active

					
	ld a, (localBinary)				; check bit 0, then rra
	bit 0, a					; check binary of visible moles

	jr z, no_y_hit					; not active

							; active, so SCORED !

	call flashMole					; increase sprite frame to show hit mole image

;	pop af 					; why was this here

	or a
	ld a, (moleScore)				; get old score
	inc a 						; increase it
	daa						; adjust for digital binary
	ld (moleScore),a 				; store it


	ld b,a 
	ld a, (highScore)
	cp a,b 						; was current score higher than high score?
	jr nc, done_high				; no, carry on
	ld a,b 						; yes, update high score
	ld (highScore),a 

	call printHighScore

done_high:
	call playMouseHitSnd

	jp continue_here				; can jump out of loop, don't need to check the others

no_x_hit:
	inc hl 						; didn't check y, so need extra inc for HL
 	inc hl 						; get ready for next X position

no_y_hit:


no_hit:

	ld a, (localBinary)
	rra						; shift binary one place for next round
	ld (localBinary),a 

	ld a, (localCount)
	inc a 						; move to next mole number
	ld (localCount),a 
	cp 8 						; have we reached 8? if so exit loop
	jp nz, hitLoop

	call playMouseDownSnd				; ok done, carry on

continue_here:
	call printScore
	call mouseDownFrame				

	ret 

btnUp:
	ld hl, btnLast
	ld (hl), 0 					; HL is btnLast status

	call mouseUpFrame

	ret 

flashMole:						; make mole go to frame 1

	ld a, 23
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 4
	rst.lil $10					; select sprite X
	
	ld a, (localCount)
	rst.lil $10
	
	ld a, 23
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 8
	rst.lil $10					; select next frame - there are only 2 frames

	ret 

oldMouseX:	.dw 0
oldMouseY:	.dw 0
localBinary:	.db 0
localCount: 	.db 	0

; ---------------------------------------------

mouseDownFrame:
	ld a, 23					; select sprite  number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 4		
	rst.lil $10	
	ld a, spadeSprite
	rst.lil $10	

	ld a, 23					; select sprite frame number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 10		
	rst.lil $10	
	ld a, 1						; set new frame
	rst.lil $10	

	ret 

mouseUpFrame:
	ld a, 23					; select sprite  number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 4		
	rst.lil $10	
	ld a, spadeSprite
	rst.lil $10	

	ld a, 23					; select sprite frame number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 10		
	rst.lil $10	
	ld a, 0						; set new frame
	rst.lil $10	

	ret 

moleUp:
							; A is frame to set
	ld a, 23					; select sprite  number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 4		
	rst.lil $10	
	ld a, moleSprite
	rst.lil $10	

	ld a, 23					; select sprite frame number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 11 					; show it		
	rst.lil $10	

	ret 

; ---------------------------------------------

moleDown:
							; A is frame to set

	ld a, 23					; select sprite  number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 4		
	rst.lil $10	
	ld a, moleSprite
	rst.lil $10	

	ld a, 23					; select sprite frame number
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 12 					; hide it		
	rst.lil $10	

	ret 
; ---------------------------------------------
;
;	EXIT CODE CLEANLY
;
; ---------------------------------------------

exit_here:

	call restore_font				; restore original BBC Basic font

	ld a, 17
	rst.lil $10					
	ld a, 15
	rst.lil $10					; Colour  bright white
	
	ld a, 12
	rst.lil $10					; CLS
							; reset all values before returning to MOS
	pop iy
	pop ix
	pop de
	pop bc
	pop af
	ld hl,0

	ret						; return to MOS here

; ---------------------------------------------
;
;	MOUSE INIT
;
; ---------------------------------------------

disableMouse:

	ld a, 23
	rst.lil $10
	ld a, 0
	rst.lil $10
	ld a, 89h
	rst.lil $10
	ld a, 1						; 1 or 0
	rst.lil $10					; disable mouse command

	ret 

initMouse:


	ld a, 23
	rst.lil $10
	ld a, 0
	rst.lil $10
	ld a, 89h
	rst.lil $10
	ld a, 0						; 1 or 0
	rst.lil $10					; enable mouse command

	ld a, 00010000b					; delay byte
	call multiPurposeDelay				; waits for pre-define z80 clock



	ld a, 23			  		; set mouse style
	rst.lil $10
	ld a, 0
	rst.lil $10
	ld a, 89h
	rst.lil $10
	ld a, 3						; setCursor
	rst.lil $10
	ld a, 255					; fab-gl style number, or my own defined ones
	rst.lil $10
	ld a, 255					; 0 as 16 bit number - blank 65525
	rst.lil $10

	ret 

hidecursor:
	push af
	ld a, 23
	rst.lil $10
	ld a, 1
	rst.lil $10
	ld a,0
	rst.lil $10					; VDU 23,1,0
	pop af
	ret

; ---------------------------------------------
;
;	SOUND PLAYING
;
; ---------------------------------------------

playMouseDownSnd:
	push hl 
	push bc 

	ld hl, startMouseSnd
	ld bc, endMouseSnd - startMouseSnd
 	rst.lil $18

 	pop bc 
 	pop hl
 	ret 

startMouseSnd:	
	.db 23,0,$85		; do sound
	.db 0			; channel
	.db 4,0			; code, waveform

	.db 23,0,$85		; do sound
	.db 0			; channel
	.db 0,127		; code, volume
	.dw 300			; freq
	.dw 50			; duration
endMouseSnd:

; ---------------------------------------------

playMouseHitSnd:
	push hl 
	push bc 

	ld hl, startMouseHit
	ld bc, endMouseHit - startMouseHit
 	rst.lil $18

 	pop bc 
 	pop hl
 	ret 

startMouseHit:	
	.db 23,0,$85		; do sound
	.db 0			; channel
	.db 4,0			; code, waveform

	.db 23,0,$85		; do sound
	.db 0			; channel
	.db 0,127		; code, volume
	.dw 3000			; freq
	.dw 50			; duration
endMouseHit:

; ---------------------------------------------

playMouseUpSnd:
	push hl 
	push bc 

	ld hl, startMouseSnd2
	ld bc, endMouseSnd2 - startMouseSnd2
 	rst.lil $18

 	pop bc 
 	pop hl
 	ret 

startMouseSnd2:	
	.db 23,0,$85		; do sound
	.db 0			; channel
	.db 4,0			; code, waveform

	.db 23,0,$85		; do sound
	.db 0			; channel
	.db 0,127		; code, volume
	.dw 1000			; freq
	.dw 50			; duration
endMouseSnd2:

; ---------------------------------------------
;
;	DATA & STRINGS
;
; ---------------------------------------------

title_str:
	.db	17,15					; Colour  bright white
	.db	31,11,8					; TAB to 0,0
	.db "Mole Game v0.20"				; text to show

	.db	31,09,17				; TAB to 0,0
	.db "Press 'S' to start"			; text to show


	.db	17,29					; Colour  grey, khaki
	.db	31,4,27					; TAB to 0,0
	.db "This Console8 game uses a mouse"		; text to show


	.db	31,10,29				; TAB to 0,0
	.db "© R.Turnnidge 2023"			; text to show
	.db	17,15					; Colour  bright white
end_title:

btnLast:	.db 		0
btnStatus:	.db 		0


game_str:						; text on screen during a game
	.db	31,0,0					; TAB to 0,29
	.ds 	40, 32					; 32 x SPACES, just to clear the line
	.db	31,0,1					; TAB to 0,29
	.ds 	40, 32					; 32 x SPACES, just to clear the line
	.db	31,0,2					; TAB to 0,29
	.ds 	40, 32					; 32 x SPACES, just to clear the line
	.db	31,0,3					; TAB to 0,29
	.ds 	40, 32					; 32 x SPACES, just to clear the line
	.db	31,0,4					; TAB to 0,29
	.ds 	40, 32					; 32 x SPACES, just to clear the line



	.db	31,0,29					; TAB to 0,29
	.ds 	40, 32					; 32 x SPACES, just to clear the line
	.db	31,0,28					; TAB to 0,28
	.ds 	40, 32					; 32 x SPACES, just to clear the line

	.db	31,0,29						; TAB to 0,0
	.db 	"Countdown:       Score:         High: "	; text to show

end_game_str:

; ---------------------------------------------
	
moveMoles:						; put all moles in correct positions

	ld b, 0 					; 8 moles to move
	ld hl, molePositions				; place we store all x,y positions of moles

mmLoop:
	ld a, b
	ld (which_sprite),a 

	ld a, (hl)
	ld (sprite_x),a 				; put byte into x pos LSB
	sub a, 12 					; bitmap is offset by 12 px horizontally
	ld (bitmap_x),a 				; put byte into x pos LSB

	inc hl
	ld a, (hl)
	ld (sprite_x + 1),a 				; put byte into x pos MSB
	ld (bitmap_x + 1),a 				; put byte into x pos MSB

	inc hl
	ld a, (hl)
	ld (sprite_y),a 				; put byte into y pos LSB
	ld (bitmap_y),a 				; put byte into y pos LSB

	inc hl
	ld a, (hl)
	ld (sprite_y + 1),a 				; put byte into y pos MSB
	ld (bitmap_y + 1),a 				; put byte into y pos MSB

	call draw_mole_sprites				; position sprites and blit mound bitmaps

	inc hl 						; get ready for next mole positions
	inc b 
	ld a, b 
	cp 8 						; check if all 8 done
	ret z 

	jp mmLoop					; loop round if not

; ---------------------------------------------

draw_sprite:
	push bc
	push hl 

	ld hl, drawSpriteStart
	ld bc, endSprite - drawSpriteStart
 	rst.lil $18					; send data

	pop hl 
	pop bc
	ret


draw_mole_sprites:
	push bc
	push hl 

	ld hl, drawSpriteStart
	ld bc, drawSpriteEnd - drawSpriteStart
 	rst.lil $18	; send data

	pop hl 
	pop bc
	ret

drawSpriteStart:					; this contains stream of data to update a sprite and blitz a bitmap

		.db 23, 27,4				; select sprite
which_sprite:	.db 	0 				; sprite number
		.db 23, 27, 13				; move sprite
sprite_x:	.dw 100					; to x pos (a word, not byte)
sprite_y:	.dw 100					; and y pos (a word, not byte)
	
endSprite:						; next do mounds
		.db 23, 27,0				; select sprite
which_bitmap:	.db 	0 				; bitmap number
		.db 23, 27, 3				; draw bitmap at X,Y
bitmap_x:	.dw 100					; to x pos (a word, not byte)
bitmap_y:	.dw 100					; and y pos (a word, not byte)

drawSpriteEnd:

; ---------------------------------------------

loadBitmaps:
	ld hl, loadGraphics				; start of data to send
	ld bc, endLoadGraphics - loadGraphics		; length of data to send
	rst.lil $18					; send data
	ret 

; ---------------------------------------------

loadGraphics:						; this is a load of data which gets send to VDP

	DEFBITMAPMOLE 0, "resources/mole64_mound_dithered.data"

	DEFBITMAP40 5, "resources/just_mole.data"
	DEFBITMAP40 6, "resources/just_mole_hit.data"

	DEFBITMAP32 3, "resources/spade_cursor1.data"
	DEFBITMAP32 4, "resources/spade_cursor2.data"
	DEFBITMAP64 9, "resources/wide_grass.data"	; note 64 bit wide/32 bit high

endLoadGraphics:

; ---------------------------------------------

setupSprites:						; this routine defines sprites
						
	ld hl, defineSprites				; start of data to send
	ld bc, endDefineSprites - defineSprites		; length of data to send
	rst.lil $18		
	ret 

; ---------------------------------------------

defineSprites:
							;  make mole sprites
	.db 23,27,17							; MAKE_SPRITE spriteNum, bitmapNum
	MAKE_SPRITE moleSprite, 5
	ADD_SPRITE_FRAME 6				; ADD_SPRITE_FRAME bitmapNum. Adding mole hit frame
	MAKE_SPRITE moleSprite + 1, 5
	ADD_SPRITE_FRAME 6
	MAKE_SPRITE moleSprite + 2, 5
	ADD_SPRITE_FRAME 6
	MAKE_SPRITE moleSprite + 3, 5
	ADD_SPRITE_FRAME 6
	MAKE_SPRITE moleSprite + 4, 5
	ADD_SPRITE_FRAME 6
	MAKE_SPRITE moleSprite + 5, 5
	ADD_SPRITE_FRAME 6
	MAKE_SPRITE moleSprite + 6, 5
	ADD_SPRITE_FRAME 6
	MAKE_SPRITE moleSprite + 7, 5
	ADD_SPRITE_FRAME 6


	MAKE_SPRITE spadeSprite, 3

	.db 23,27,4,1
	;SEL_SPRITE 1
	.db 23,27,4,spadeSprite
	;SEL_SPRITE spadeSprite

	;CLEAR_CURRENT_SPRITE	
	;ADD_SPRITE_FRAME 3				; add bitmap as frame
	ADD_SPRITE_FRAME 4 				; add all frames to mole



	ACTIVATE_SPRITES 9 				; total number of sprites
	.db 23,27,15					; update sprites in GPU. We haven't set all positions yet though

endDefineSprites:

; ---------------------------------------------
showTheSprites:
	ld hl, showSprites
	ld bc, endShowSprites - showSprites
 	rst.lil $18	
 	call quickRefresh				; send data
	ret 

hideTheSprites:
	ld hl, hideSprites
	ld bc, endHideSprites - hideSprites
 	rst.lil $18		
 	call quickRefresh			; send data
	ret 

; ---------------------------------------------
hideSprites:
	.db 23,27,4,moleSprite
	;SELECT_SPRITE moleSprite 	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4,moleSprite +1	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4,moleSprite +2	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4,moleSprite +3	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4,moleSprite +4	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4,moleSprite +5	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4,moleSprite +6	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4,moleSprite +7	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,4, spadeSprite 	; 0
	HIDE_CURRENT_SPRITE
	.db 23,27,15

endHideSprites:

; ---------------------------------------------

showSprites:
; 	SELECT_SPRITE moleSprite			;  NOTE, in this game, all are hidden and come on in turn
; ;	SHOW_CURRENT_SPRITE
; 	SELECT_SPRITE moleSprite +1		
; ;	SHOW_CURRENT_SPRITE
; 	SELECT_SPRITE moleSprite +2		
; ;	SHOW_CURRENT_SPRITE
; 	SELECT_SPRITE moleSprite +3		
; ;	SHOW_CURRENT_SPRITE
; 	SELECT_SPRITE moleSprite +4		
; ;	SHOW_CURRENT_SPRITE
; 	SELECT_SPRITE moleSprite +5		
; ;	SHOW_CURRENT_SPRITE
; 	SELECT_SPRITE moleSprite +6		
; ;	SHOW_CURRENT_SPRITE
; 	SELECT_SPRITE moleSprite +7		
; ;	SHOW_CURRENT_SPRITE
	.db 23,27,4,spadeSprite
	;SELECT_SPRITE spadeSprite		
	.db 23,27,11
	;SHOW_CURRENT_SPRITE

endShowSprites:

showSpade:
	.db 23,27,4,spadeSprite
	;SELECT_SPRITE spadeSprite		
	.db 23,27,11 ;SHOW_CURRENT_SPRITE
endShowSpade:

; ---------------------------------------------

setupScreen:
	.db	22, 8 					; set screen mode 8 + 128 for double-buffered
	.db	23, 0, 192, 0				; set to non-scaled graphics
	.db 	17,15					; ink bright white
	.db 	23,16, 00001111b			; set screen to non-scaled
endSetupScreen:

; ---------------------------------------------

moleSprite:	EQU	0		; 0-7
moleX:		.dw 	70
moleY:		.dw 	50
spadeSprite:	equ 	8		; 10
spadeX:		.dw 	50
spadeY:		.dw 	50

molePositions:						; list of all 8 mole positions, X/Y as words
x0:		.dw 	60
y0:		.dw 	40	
x1:		.dw 	180
y1:		.dw 	40	
x2:		.dw 	20
y2:		.dw 	100	
x3:		.dw 	90
y3:		.dw 	90	
x4:		.dw 	160
y4:		.dw 	120	
x5:		.dw 	240
y5:		.dw 	100	
x6:		.dw 	70
y6:		.dw 	150	
x7:		.dw 	200
y7:		.dw 	170	


; ---------------------------------------------

draw_cobbles:						; try to draw grid of background graphics to fill texture
	ld a, 23	
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 0
	rst.lil $10
	ld a, 9						; select bitmap 7 (grass)
	rst.lil $10

	ld b, 8						; number of rows
cob_outer:
	push bc
	ld a, b 
	dec a
	or a						; clear carry flag
	rla 
	rla 
	rla 
	rla 
	rla 

	ld (cobble_y),a 	
	ld b,8						; number of columns

cob_loop:						; do a loop of row
	ld a, b 
	dec a
	or a						; clear carry flags
	rla 
	rla 
	rla 
	rla 
	rla
	rla 

	ld (cobble_x),a 
	push bc 
	ld hl, startCob
	ld bc, endCob - startCob
 	rst.lil $18

 	pop bc
 	djnz cob_loop
 
 							; HACK add one extra column here?
 	ld a, 0
 	ld (cobble_x),a
 	ld a, 1
 	ld (cobble_x+1),a 

	push bc 
	ld hl, startCob
	ld bc, endCob - startCob
 	rst.lil $18
 	pop bc

 	ld a, 0
 	ld (cobble_x+1),a 

	pop bc
 	djnz cob_outer

 	ret 


startCob:
			.db	23, 27, 3		; draw bitmap at x,y
cobble_x:		.dw 0
cobble_y:		.dw 0
endCob:


; ---------------------------------------------
;
;	DRAW TITLE
;
; ---------------------------------------------


predrawTitle:
	call doSetupBuffer
	call writeData
	call doConvertBuffer

	ret

drawTitle:					; now lets ty drawing it to the screen
	ld a, 23
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 0
	rst.lil $10
	ld a, 10
	rst.lil $10				; selct bitmap ID 10

	ld a, 23
	rst.lil $10
	ld a, 27
	rst.lil $10
	ld a, 3
	rst.lil $10
	ld a, 0
	rst.lil $10
	ld a, 0
	rst.lil $10
titlePos:	ld a, 0
	rst.lil $10
	ld a, 0
	rst.lil $10				; draw bitmap at X,Y = 0,0 (words)

	ret 

; ---------------------------------------------
;
;	SETUP BUFFER
;
; ---------------------------------------------

doSetupBuffer:

	ld hl, setupBuffer
	ld bc, endSetupBuffer - setupBuffer
	rst.lil $18
	ret 

; ---------------------------------------------

setupBuffer:					; create buffer
		.db 	23,0,$A0 		; write block
bufID:		.dw 	64010 			; ID (word)
		.db 	3	 		; 'create' command
bufLen:		.dw 	61440			; length 320 x 48 x 4 bytes

						; clear in case VDP already has one
		.db 	23,0,$A0 		; write block
bufLen2:	.dw 	64010 			; ID (word)
		.db 	2	 		; 'create' command
endSetupBuffer:

; ---------------------------------------------
;
;	WRITE TO BUFFER
;
; ---------------------------------------------

writeData:

	ld hl, doWriteData
	ld bc, endWriteData - doWriteData
	rst.lil $18

	call sendBufferData
	ret 

; ---------------------------------------------

doWriteData:					; write block to buffer
		.db 	23,0,$A0 		; write block
bufID2:		.dw 	64010 			; ID (word)
		.db 	0	 		; 'write' command
bufLen3:	.dw 	61440 			; length 320 x 48 x 4 bytes

						; next the actual data... 1920 x 4 bytes x 8 (RGBA) 
						; to be sent in code one by one
endWriteData:

; ---------------------------------------------

sendBufferData:					; send big title to a buffer
						; read through data file, then send either geeen or blank pixle as RGBA

	ld de, imgData				; start of image data to plot
	ld bc, 0 				; first byte
byteLoop:
	push bc
	ld a, (de)  				; get current byte to split and send

	ld b, 8 				; loop through it 8 times
	ld (currentByte),a

pixelLoop:
	push bc 

	ld a, (currentByte)			; grab byte again
	bit 7,a 				; check bit 7

	jr nz, sendBlank			; decide if 1 or 0


sendPixel:
	ld a, (setRed)
	rst.lil $10
	ld a, (setGreen)
	rst.lil $10
	ld a, (setBlue)
	rst.lil $10
	ld a, (setAlpha)
	rst.lil $10				; send RGBA 0,ff,0,ff

	jr allSent

sendBlank:				
	ld a, blank
	rst.lil $10
	ld a, blank
	rst.lil $10
	ld a, blank
	rst.lil $10
	ld a, blank
	rst.lil $10				; send RGBA 0,0,0,0

allSent:
	ld a, (currentByte)
	rla 					; shift left byte so we can check next pixel bit
	ld (currentByte),a 			; store new byte A
	pop bc

	djnz pixelLoop				; B is counter from 8 down

	pop bc 					; BC is counting bytes in source file
	inc bc

	inc de

	ld hl, 1920 				; DEFFILESIZE
	or a 
	sbc hl, bc 				; have all bytes been converted?

	jp nz, byteLoop

	ret 

blank: 	equ 0
full: 	equ 255

; ---------------------------------------------

imgData:					; the actual image data as binary 1 bit PBM file			
	incbin "resources/title_target.pbm" 		

endImgData:

currentByte:	.db 	0			; byte currently splitting into bits
DEFWIDTH:	equ	320			; bytes, not pixels
DEFHEIGHT:	equ	48			; pixel lines
DEFBUFFERSIZE:	equ 	DEFFILESIZE * 32	; file size x 8 bits x 4 colours RGBA  ; 61440	; 320 x 48 x 4 bytes
DEFFILESIZE:	equ	endImgData - imgData 	; DEFBUFFERSIZE/32

; ---------------------------------------------

; preparation for general purpose routines

; colours must be: $00, $55, $AA   , $FF
setRed:			.db 	$ff
setGreen:		.db 	$ff
setBlue:		.db 	$ff
setAlpha:		.db 	$FF

imgWidth:		.dw 	320
imgHeight:		.dw 	48
						; if we know image width and height, we could work out the other params in code
bufferSize:		.dw 	61440		; used for definition and creating the bitmap
fileSize:		.dw 	1920		; used to count bytes during scan
imgID:			.dw 	64010		; needs to be 64000 + ID - 8 bit ID for calling
moleScore:		.db 	0		; running score


; ---------------------------------------------

doConvertBuffer:
	ld hl, convertBuffer
	ld bc, endConvertBuffer - convertBuffer
	rst.lil $18
	ret 

convertBuffer:
   						; convert buffer block to bitmap with ID
	.db 	23,27,$20 			; select buffer bitmap to use
	.dw 	64010				; ID (word) will be added to 64000 = 64010

						; create a bitmap from that ID
	.db 	23,27,$21 			; create bitmap from buffer
	.dw 	DEFWIDTH, DEFHEIGHT 		; width, height (both words)
	.db 	0 				; format (0=RGBA)	

endConvertBuffer:



; ---------------------------------------------

currentMoleTime:	 .db 0

moleTimings: 					; enough for 30 changes. List of which moles visible at each cycle
	.db 	00000001b
	.db 	10010000b
	.db 	00001010b
	.db 	10001000b
	.db 	00000010b
	.db 	01000001b
	.db 	10000001b
	.db 	00001000b
	.db 	00010000b
	.db 	10000010b
	.db 	00101001b
	.db 	00000110b
	.db 	00000100b
	.db 	00000001b
	.db 	01001100b
	.db 	10000000b
	.db 	00000010b
	.db 	00101000b
	.db 	00100010b
	.db 	10010001b
	.db 	10101100b
	.db 	00010000b
	.db 	00000010b
	.db 	00000001b
	.db 	00101000b
	.db 	10000001b
	.db 	01000110b
	.db 	00000100b
	.db 	00100000b

; ---------------------------------------------
;
;	Print Score Routine
;
; ---------------------------------------------

printScore:					; print 2 digit score/countdown to screen
						; bodScore can be decimal from 0-99

						; start with rightmost nibble
	ld a, (moleScore)			; get A from variable, then split into two nibbles
	and 11110000b				; get higher nibble
	rra
	rra
	rra
	rra					; move across to lower nibble
	add a,48				; increase to ascii code range 0-9

	ld (scoreHB), a 			; set first High Byte digit

						; next do leftmost nibble
	ld a, (moleScore)			; get A back again
	and 00001111b				; now just get lower nibble
	add a,48				; increase to ascii code range 0-9

	ld (scoreLB), a 			; set second Low Byte digit

						; now send whole string to VDP
	ld hl, scoreStart
	ld bc, scoreEnd - scoreStart
	rst.lil $18	; print score
	ret			; head back

scoreStart:
	.db	17,2				; Colour  green
	.db 	31, 24, 29			; print at: x,y
						; print this string
scoreHB:	.db 6				; default values, to be modified above
scoreLB:	.db 0


scoreEnd:

; ---------------------------------------------
;
;	Print Timer Routine
;
; ---------------------------------------------

printTimer:					; print 2 digit score/countdown to screen
						; bodScore can be decimal from 0-99

						; start with rightmost nibble
	ld a, (currentTimer)			; get A from variable, then split into two nibbles

	and 11110000b				; get higher nibble
	rra
	rra
	rra
	rra					; move across to lower nibble
	add a,48				; increase to ascii code range 0-9

	ld (timerHB), a 			; set first High Byte digit

						; next do leftmost nibble
	ld a, (currentTimer)			; get A back again
	and 00001111b				; now just get lower nibble
	add a,48				; increase to ascii code range 0-9

	ld (timerLB), a 			; set second Low Byte digit

						; now send whole string to VDP
	ld hl, timerStart
	ld bc, timerEnd - timerStart
	rst.lil $18				; print score
	ret					

timerStart:
	.db	17,2				; Colour  green
	.db 	31, 11, 29			; print at: x,y
						; print this string
timerHB:	.db 6				; default values, to be modified above
timerLB:	.db 0


timerEnd:
localTimer: 	.db 	0
currentTimer:	.db 	$30

; ---------------------------------------------
;
;	Print High Score Routine
;
; ---------------------------------------------

printHighScore:					
						; highScore can be decimal from 0-99

						; start with rightmost nibble
	ld a, (highScore)			; get A from variable, then split into two nibbles
	and 11110000b				; get higher nibble
	rra
	rra
	rra
	rra					; move across to lower nibble
	add a,48				; increase to ascii code range 0-9

	ld (hscoreHB), a 			; set first High Byte digit

						; next do leftmost nibble
	ld a, (highScore)			; get A back again
	and 00001111b				; now just get lower nibble
	add a,48				; increase to ascii code range 0-9

	ld (hscoreLB), a 			; set second Low Byte digit

						; now send whole string to VDP
	ld hl, hscoreStart
	ld bc, hscoreEnd - hscoreStart
	rst.lil $18				; print score
	ret					; head back

hscoreStart:
		.db 	31, 38, 29		; print at: x,y
		.db	17,2			; Colour  greeen
hscoreHB:	.db 	0			; default values, to be self modified
hscoreLB:	.db 	0

hscoreEnd:

highScore:	.db 	0			; store high score here
fname:		.db "moles.ini",0		; prefs file storing high score


; -----------------------------------
;
; 	LOAD CUSTOM FONTS
;
; -----------------------------------


load_font:
	ld hl, fontDataStart
	call load_custom_font			; in inc file
	ret 

restore_font:
	ld hl, defaultFontStart
	call load_custom_font			; in inc file
	ret 

fontDataStart:					; import the raw font data to use. 8 bytes x 128 chars, although first 32 are blank
						; fancy font
	incbin "8x8_fonts/xmilitary-8x8.font"	

fontDataEnd:

defaultFontStart: 				; import the raw font data to use. 8 bytes x 128 chars, although first 32 are blank
						; original BBC BASIC font
	incbin "8x8_fonts/bbcasc-8.bin"		

defaultFontEnd:

defineDiamondChar:
	ld hl, diamondChar			; source data
	ld d,35					; start char to re-define # $ %
	ld b,3 					; number of chars to re-define
	call udgloop				; call re-define function
	ret 

diamondChar:					; UDGs inplace of # $ %
	.db 	00000000b
	.db 	00011000b
	.db 	00011000b
	.db 	00011000b
	.db 	00011000b
	.db 	00011000b
	.db 	00011000b
	.db 	00000000b

	.db 	00000000b
	.db 	00000000b
	.db 	00000000b
	.db 	01111110b
	.db 	01111110b
	.db 	00000000b
	.db 	00000000b
	.db 	00000000b

	.db 	00000000b
	.db 	00011000b
	.db 	00011000b
	.db 	01111110b
	.db 	01111110b
	.db 	00011000b
	.db 	00011000b
	.db 	00000000b

endDiamondChar:

; ---------------------------------------------

; Cursor styles - for Reference


; 0 CursorPointerAmigaLike 	
; 11x11 Amiga like colored mouse pointer

; 1 CursorPointerSimpleReduced 	
; 10x15 mouse pointer

; 2 CursorPointerSimple 	
; 11x19 mouse pointer

; 3 CursorPointerShadowed 	
; 11x19 shadowed mouse pointer

; 4 CursorPointer 	
; 12x17 mouse pointer

; 5 CursorPen 	
; 16x16 pen

; 6 CursorCross1 	
; 9x9 cross

; 7 CursorCross2 	
; 11x11 cross

; 8 CursorPoint 	
; 5x5 point

; 9 CursorLeftArrow 	
; 11x11 left arrow

; 10 CursorRightArrow 	
; 11x11 right arrow

; 11 CursorDownArrow 	
; 11x11 down arrow

; 12 CursorUpArrow 	
; 11x11 up arrow

; 13 CursorMove 	
; 19x19 move

; 14 CursorResize1 	
; 12x12 resize orientation 1

; 15 CursorResize2 	
; 12x12 resize orientation 2

; 16 CursorResize3 	
; 11x17 resize orientation 3

; 17 CursorResize4 	
; 17x11 resize orientation 4

; 18 CursorTextInput 	
; 7x15 text input

; 65525 blank 





