; zap: draw lines from orbs to targets

; orbs have max 4 targets so we need to store up to 4 coordinate pairs
; for drawing and subsequent erasure, plus the start point

; 5 pairs of character coordinates
.zap_xarray
	skip 5
.zap_yarray
	skip 5

; how many array entries used
.zapcount
	skip 1

; A*32+16
.mul32_add16
{
	ldx #0
	stx zp_temp
IF 0
	ldx #4
	clc
.loop
	rol a
	rol zp_temp
	dex
	bpl loop
ELSE ; +8 bytes for unrolled
	clc
	rol a
	rol zp_temp
	rol a
	rol zp_temp
	rol a
	rol zp_temp
	rol a
	rol zp_temp
	rol a
	rol zp_temp
ENDIF
	ora #16
	rts
}

; store start point, reset count
.zap_start
{
	lda #0
	sta zapcount
	ldx zp_tmpy
	ldy zp_tmpx
	
; store coords in array for later plotting
; X,Y reversed coords
; X,Y preserved, A corrupted
.*zap_to
	txa
	sta xtmp+1
	ldx zapcount
	; subtract y coord from 32
	eor #$1f
	; and store it
	sta zap_yarray,X
	tya
	; store x coord
	sta zap_xarray,X
	inc zapcount
.xtmp	ldx #0
	rts
}

.zap_start_plot
{
	; VDU 25,X = PLOT X,
	lda #25
	jsr oswrch
	txa
	jsr oswrch
.zap_do_coord_from_array
	lda zap_xarray,Y
	jsr zap_do_coord
	lda zap_yarray,Y
.zap_do_coord
	; send 2 bytes of coordinate after conversion to OS units
	jsr mul32_add16
	jsr oswrch
	lda zp_temp
	jmp oswrch
}

.zap_plot
{
	lda #10
	jsr delay_start
	jsr zap_really_plot ; plot, then erase
	jsr delay_end
.zap_really_plot	
	ldy zapcount ; this is one more than the number of targets
	dey
.loop
	ldx #4
	sty ytmp+1
	ldy #0
	jsr zap_start_plot
	;ldx #22 ; dotted line, inverse
	ldx #6 ; solid line, inverse
.ytmp
	ldy #0
	jsr zap_start_plot	
	dey
	bne loop
	rts
}
