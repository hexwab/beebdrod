; hwscroll: smooth scrolling when moving from room to room

; the big annoyance here is that the scrolled region is 38x32
; whereas the framebuffer is 40x32, meaning that lines can wrap around
; the end and we need to ensure the rightmost two columns are always
; empty. the fixups required for this make their presence felt
; *all over the freaking place*.

; CHECKME: does OS linedrawing work?
IF HWSCROLL

ASSERT XRES=40
ASSERT SCRSTART=$3000
.hwscroll_addr_lo
	equb 0
.hwscroll_addr_hi
	equb $30
; X lo, Y hi
.hwscroll_scroll_by
{
	txa
	clc
	adc hwscroll_addr_lo
	sta hwscroll_addr_lo
	tya
	adc hwscroll_addr_hi
	clc
	adc #$50
	bpl nowrap
.loop
	sec
	sbc #$50
	bmi loop
.nowrap
	sta hwscroll_addr_hi
	rts
}
.hwscroll_reset
{
	ldx #0
	stx hwscroll_addr_lo
	lda #$30
	sta hwscroll_addr_hi
	; fall through
	}
IF 0
.hwscroll_set_linetab_from_screen_address
{
	lda hwscroll_addr_hi
	ldx hwscroll_addr_lo
	; fall through
}
ENDIF
; fill in linetab. in: AX start address
.hwscroll_set_linetab
{
	stx linetab_lo
	sta linetab_hi
	ldx #1
.loop
	lda linetab_lo-1,X
	clc
	adc #$80
	sta linetab_lo,X
	lda linetab_hi-1,X
	adc #2
	bpl nowrap
	sec
	sbc #$50
.nowrap
	sta linetab_hi,X
	inx
	cpx #32
	bne loop
	rts
}

.hwscroll_set_6845
{	
	lda hwscroll_addr_lo
	sta $350 ; tell OS
	sta zp_temp
	lda hwscroll_addr_hi
	sta $351 ; tell OS
	lsr a
	ror zp_temp
	lsr a
	ror zp_temp
	lsr a
	ror zp_temp
	ldx #12
	stx $fe00
	sta $fe01 ; screen start lo
	lda zp_temp
	inx
	stx $fe00
	sta $fe01 ; screen start hi
	rts
}

; blank out a column
; 
.blank_column
{
	lda #31
	sta zp_temp
	lda #LO(16*38)
	clc
	adc linetab_lo
	tax
	lda #HI(16*38)
	adc linetab_hi
.loop
	sta dst1+2
	sta dst2+2
	sta dst3+2
	sta dst4+2
	;jsr osrdch
	ldy #3
	lda #0
.loop2	
.dst1	sta $EE00,X
.dst2	sta $EE04,X
.dst3	sta $EE08,X
.dst4	sta $EE0c,X
	inx
	dey
	bpl loop2
	txa
	clc ; unnecessary?
	adc #$7C
	tax
	lda dst1+2
	adc #2
	bpl nowrap
	sec
	sbc #$50
.nowrap
	dec zp_temp
	bpl loop
	rts
}	

{
.scrollleft
	jmp scrollleft_real
.scrolldown
{
	ldx #31
	stx zp_temp2
.loop
	lda #19
	jsr $fff4
	ldx #LO($280)
	ldy #HI($280)
	jsr hwscroll_scroll_by
	jsr hwscroll_set_6845
	ldx #0
	lda zp_temp2
	eor #$1f
	tay
	sty zp_tmpy
	lda #38
	jsr plot_some_room
	dec zp_temp2
	bpl loop
	rts
}
.^hwscroll
.*came_from
	lda #OVERB
	cmp #$f8
	beq scrollup
	cmp #$8
	beq scrolldown
	cmp #$ff
	beq scrollleft
	cmp #$1
	beq scrollright
IF DEBUG
	;brk
ENDIF
	;jmp scrollleft
	jmp plot_entire_room
; the complicated one. here be dragons.
.scrollup
{
	ldx #31
	stx zp_temp2
	jsr init_timer
{	sei
.m 	lda USERVIA_IFR
	beq m
	lda USERVIA_T1CL ; clear interrupt
	cli
}
.loop
	ldx #LO($10000-$280)
	ldy #HI($10000-$280)
	jsr hwscroll_scroll_by
	jsr hwscroll_set_6845

	ldx #0
	ldy zp_temp2
	sty zp_tmpy

	; temporarily point linetab to buffer
	lda linetab_lo,Y
	sta linetab_lo_temp
	lda linetab_hi,Y
	sta linetab_hi_temp
	lda #LO(line0buffer)
	sta linetab_lo,Y
	lda #HI(line0buffer)
	sta linetab_hi,Y
	
	ldy zp_temp2
	lda #38
	jsr plot_some_room

	; restore linetab
	ldy zp_temp2
	lda linetab_lo_temp
	sta linetab_lo,Y
	lda linetab_hi_temp
	sta linetab_hi,Y

	;jsr osrdch
{	sei
.m 	lda USERVIA_IFR
	beq m
	lda USERVIA_T1CL ; clear interrupt
	jsr buffer_line_0
	cli
}	;jsr osrdch
	dec zp_temp2
	bpl loop

.rts	rts
}	

.scrollright
{
	; inc linetab[0]
{	
	lda #<(38*16)
	clc
	adc linetab_lo
	tax
	lda #>(38*16)
	adc linetab_hi
	bpl nowrap
	sec
	sbc #$50
.nowrap
	jsr hwscroll_set_linetab
}

	lda #37
	sta zp_temp2
	lda #0
	sta zp_tmpx
.colloop
	; scroll
	lda #19
	jsr $fff4
	ldx #LO($10)
	ldy #HI($10)
	jsr hwscroll_scroll_by
	jsr hwscroll_set_6845

	; set dest address for blanking
	ldy zp_tmpx
	iny
	iny ; blank to the right
	lda mul16_lo,Y
	clc
	adc linetab_lo
	sta xtmp+1
	lda mul16_hi,Y
	adc linetab_hi
{	bpl nowrap
	sec
	sbc #$50
.nowrap
}
	ldx #0 ; row
.rowloop
	sta dst1+2
	sta dst2+2
	; plot one tile and one blank from top to bottom
	; this is in raster scan order in the hope that we can race the beam
	stx zp_tmpy
	ldy zp_tmpx
	jsr get_tile
	jsr plot_from_tile_with_special
	;jmp skip ; debug: skip blanking
 ; blank one tile
.xtmp	ldx #OVERB
	lda #0
	ldy #7
.blankloop
.dst1	sta $EE00,X
.dst2	sta $EE08,X
	inx
	dey
	bpl blankloop
	txa
	clc
	adc #$78
	sta xtmp+1
	lda dst1+2
	adc #2
{	bpl nowrap
	sec
	sbc #$50
.nowrap
}
.skip
	ldx zp_tmpy
	inx
	cpx #32
	bne rowloop

	inc zp_tmpx
	dec zp_temp2
	bpl colloop
	rts
}	
.*scrollleft_real
{
	; inc linetab[0]
{	
	lda #<($10000-38*16)
	clc
	adc linetab_lo
	tax
	lda #>($10000-38*16)
	adc linetab_hi
	clc
	adc #$50
	bpl nowrap
.loop
	sec
	sbc #$50
	bmi loop
.nowrap
	jsr hwscroll_set_linetab
}

	lda #37
	sta zp_temp2
	;lda #0
	sta zp_tmpx
.colloop
	; scroll
	lda #19
	jsr $fff4
	ldx #LO($10000-$10)
	ldy #HI($10000-$10)
	jsr hwscroll_scroll_by
	jsr hwscroll_set_6845

	; set dest address for blanking
	;ldy zp_tmpx
	;dey
	;dey ; blank to the left
{	lda zp_tmpx
	clc
	adc #38
	cmp #40
	bcc nowrap
	sec
	sbc #40
.nowrap
}
	tay
	lda mul16_lo,Y
	clc
	adc linetab_lo
	sta xtmp+1
	lda mul16_hi,Y
	adc linetab_hi
{	bpl nowrap
	sec
	sbc #$50
.nowrap
}	ldx #0 ; row
.rowloop
	sta dst1+2
	sta dst2+2
	; plot one tile and one blank from top to bottom
	; this is in raster scan order in the hope that we can race the beam
	stx zp_tmpy
	ldy zp_tmpx
	jsr get_tile
	jsr plot_from_tile_with_special
	;jmp skip ; debug: skip blanking
 ; blank one tile
.xtmp	ldx #OVERB
	lda #0
	ldy #7
.blankloop
.dst1	sta $EE00,X
.dst2	sta $EE08,X
	inx
	dey
	bpl blankloop
	txa
	clc
	adc #$78
	sta xtmp+1
	lda dst1+2
	adc #2
	bpl nowrap
	sec
	sbc #$50
.nowrap
.skip
	ldx zp_tmpy
	inx
	cpx #32
	bne rowloop

	dec zp_tmpx
	dec zp_temp2
	bpl colloop
	rts
}
.init_timer
{
	sei
	lda #2
.l	bit SYSVIA_IFR
	beq l
TIMER=$4670
VSYNC=$4dfe	
	lda #LO(TIMER)
	sta USERVIA_T1CL
	lda #HI(TIMER)
	sta USERVIA_T1CH
	lda #LO(VSYNC)
	sta USERVIA_T1LL
	lda #HI(VSYNC)
	sta USERVIA_T1LH
	lda #%01000000
	sta USERVIA_ACR
	;lda #0 ;%11000000 ; was 0
	;sta USERVIA_IER
	;cli
	rts
}
	
; this trashes the orb buffer so be sure to reload afterwards
line0buffer=$2da0
.linetab_lo_temp
	equb 0
.linetab_hi_temp
	equb 0
	
.buffer_line_0
{
	; copy 38*16=$260 bytes from temporary buffer to linetab[0].
	; dest may wrap, but only on 32-byte boundary.
	lda #3 ; CHECKME
	sta zp_tmpx ; abuse this as a counter
IF 0
	lda linetab_hi
	sta src1+2
	sta src2+2
	sta src3+2
	sta src4+2
	lda linetab_lo
	tax
	lda #HI(line0buffer)
	sta dst1+2
	sta dst2+2
	sta dst3+2
	sta dst4+2
	ldy #$A0
ELSE
	lda linetab_hi_temp
	sta dst1+2
	sta dst2+2
	sta dst3+2
	sta dst4+2
	lda linetab_lo_temp
	tay
	lda #HI(line0buffer)
	sta src1+2
	sta src2+2
	sta src3+2
	sta src4+2
	ldx #LO(line0buffer) ; must be $A0
ENDIF
.loop2
	lda #8
	sta zp_temp
.loop
.src1
	lda $EE00,X
.dst1
	sta $EE00,Y
.src2
	lda $EE08,X
.dst2
	sta $EE08,Y
.src3
	lda $EE10,X
.dst3
	sta $EE10,Y
.src4
	lda $EE18,X
.dst4
	sta $EE18,Y
	inx
	iny
	dec zp_temp
	bne loop

{ ; inc dst
	tya
	clc
	adc #$18
	tay
	bcc noinc
	lda dst1+2 ; this is quicker than 4 incs
	adc #0
	bpl nowrap
	lda #$30
.nowrap
	sta dst1+2
	sta dst2+2
	sta dst3+2
	sta dst4+2
.noinc
}
{ ; inc src
	txa
	clc
	adc #$18
	tax
	bcc loop2 ;noinc
	lda src1+2 ; this is quicker than 4 incs
	adc #0
;	bpl nowrap
;	lda #$30
;.nowrap
	sta src1+2
	sta src2+2
	sta src3+2
	sta src4+2
	dec zp_tmpx
	bmi done
	bne loop2 ; always
}
.done
	rts
}
IF 0
; copy from buffer to screen
.buffer_take2
{
	lda #HI(line0buffer)
	sta src1+2
	sta src2+2
	sta src3+2
	sta src4+2
	ldx #LO(line0buffer)
	lda linetab_hi
	sta dst1+2
	sta dst2+2
	sta dst3+2
	sta dst4+2
	lda linetab_lo
	sec
	

	sta src1+1
	ora #$10
	sta src2+2
	ora #$08
	sta src4+4
	and #$
	sta src3+3

	
	; copy 32 bytes. takes 344 cycles
.loop2
	ldy #7
.loop
	; the loads never cross a page boundary.
	; the stores may (but it doesn't matter)
.src1	
	lda $EE00,X
.dst1
	sta $EEEE,X
.src2
	lda $EE08,X
.dst2
	sta $EEEE,X
.src3
	lda $EE10,X
.dst3
	sta $EEEE,X
.src4
	lda $EE18,X
.dst4
	sta $EEEE,X
	inx
	dey
	bpl loop
	dec zp_tmpx
	bmi done
	txa
	clc
	adc #$18
	tax
	bcc loop2

	; src never wraps. dst may.
	; 50 or 51 cycles
	lda src1+2
	adc #0 ; C always set
	sta src1+2
	sta src2+2
	sta src3+2
	sta src4+2
	lda dst1+2
	adc #1 ; C always clear
	cmp #$7f
	bcs maybewrap
.nowrap
	sta dst1+2
	sta dst2+2
	sta dst3+2
	sta dst4+2
	bne loop2 ; always
.maybewrap
	
	lda #$30
	
.done	rts
}
ENDIF
IF 0
.take2
{
	ldx #$98
.loop
	lda $EEEE,X
	sta line0buffer,X
	lda $EEEE,X
	sta line0buffer+$98,X
	lda $EEEE,X
	sta line0buffer+&130,X
	lda $EEEE,X
	sta line0buffer+&1c8,X
	
}


MACRO SET6845 r n
	lda #r
	sta $fe00
	lda n
	sta $fe01
ENDMACRO
.vrupt
{	
.first
	SET6845 12,#LO(line0buffer/8) ; cache these!
	SET6845 13,#HI(line0buffer/8)

	SET6845 4,#31-1 ; vert total
	SET6845 7,#255  ; vsync pos
	SET6845 6,#255  ; vert displayed

	LDA #timerwait1 AND 255
        STA &FE48
        LDA #timerwait1 DIV 256
        STA &FE49



.second
	SET6845 12,... 
	SET6845 13,...
	SET6845 4,#8-1 ; vert total
	SET6845 7,#34-31 ; vsync pos
	SET6845 6,#1 ; vert displayed
}
ENDIF	
}
ENDIF
