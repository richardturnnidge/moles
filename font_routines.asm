; ---------------------------------------------
;
;	FONT LOAD ROUTINE
;	Load UDG as a font
;
;	for each UDG we need
;	VDU 23, charnum (128-255), 8x bytes
;	Our font file has just the raw 8 bytes x number chars
;	Principle:
;		load font data
;		iterate loop 8 bytes at a time for 128 iterations (if enough), maybe count length of data first and div by 8?
;		send VDU code, char code, then 8 bytes in a loop inside a loop
;
;	* Here, we load 96 characters from 32-127
;
; ---------------------------------------------

						; HL should contain start of font data
						; eg.	ld hl, timesFontLabel

load_custom_font:
	inc h 					; * adds 256 to HL, to miss first 32 chars
	ld d, 32				; initial char code to replace with user font, skip first 32
	ld b, 96				; number of chars to import

udgloop:	
	push bc 				; store loop count
	ld b, 8					; number of bytes to loop through
	ld a, 23
	rst.lil $10				; send VDU 23
	ld a, d 
	rst.lil $10				; send UDG code
	inc d					; inc UDG code for next one
loop8bytes:
	ld a, (hl)				; send byte value
	rst.lil $10
	inc hl 					; step on one byte
	djnz loop8bytes				; loop for 8 bytes
	pop bc 
	djnz udgloop				; go round next UDG char

	ret 

