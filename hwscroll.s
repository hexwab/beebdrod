; hwscroll: smooth scrolling when moving from room to room

; the big annoyance here is that the scrolled region is 38x32
; whereas the framebuffer is 40x32, meaning that lines can wrap around
; the end and we need to ensure the rightmost two columns are always
; empty. the fixups required for this make their presence felt
; *all over the freaking place*.

; CHECKME: does OS linedrawing work?
INCLUDE "hw.h"
IF HWSCROLL
ASSERT XRES=40
ASSERT SCRSTART=$3000
ENDIF

hwscroll_addr_lo=$350
hwscroll_addr_hi=$351

IF PLATFORM_ELK=0
.hwscroll_screen_off
{
	lda #$f0
	equb $2c
.*hwscroll_screen_on
	lda #$00
	ldx #8
	bne hwscroll_write_reg ; always
}

IF HWSCROLL
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
ENDIF
.hwscroll_reset
{
	ldx #0
	lda #$30
.*hwscroll_set_start
	stx hwscroll_addr_lo
	sta hwscroll_addr_hi
	rts
}

.hwscroll_set_6845
{	
	ldx hwscroll_addr_lo
	lda hwscroll_addr_hi
	stx zp_temp
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
.*hwscroll_write_reg
	stx $fe00
	sta $fe01 ; screen start hi
	rts
}

IF HWSCROLL
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

.scrollright
	jmp scrollright_real
; the complicated one. here be dragons.
.scrollup
{
	ldx #31
	stx zp_temp2
	jsr init_timer
{	sei
	lda #$40
.n	cmp USERVIA_T1CH
	bne n
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
	;	jsr buffer_line_0
{
	; copy 38*16=$260 bytes from temporary buffer to linetab[0].
	; dest may wrap, but only on 32-byte boundary.

	; this takes around 7140 cycles. we have (313-256)*128=7296 available

	;lda linetab_hi_temp
	sta dst1+2
	sta dst2+2
	sta dst3+2
	sta dst4+2
	sta dst5+2
	sta dst6+2
	sta dst7+2
	sta dst8+2
	lda linetab_lo_temp
	tay
	lda #HI(line0buffer)
	sta src1+2
	sta src2+2
	sta src3+2
	sta src4+2
	sta src5+2
	sta src6+2
	sta src7+2
	sta src8+2
	ldx #LO(line0buffer) ; must be $A0
	lda USERVIA_T1CL ; clear interrupt
	lda #$40
.m 	bit USERVIA_IFR
	beq m
	lda USERVIA_T1CL ; clear interrupt
	;lda #$95
	;sta $fe21
.loop2
	lda #4
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
.src5
	lda $EE04,X
.dst5
	sta $EE04,Y
.src6
	lda $EE0c,X
.dst6
	sta $EE0c,Y
.src7
	lda $EE14,X
.dst7
	sta $EE14,Y
.src8
	lda $EE1c,X
.dst8
	sta $EE1c,Y
	inx
	iny
	dec zp_temp
	bne loop

{ ; inc dst
	tya
	clc
	adc #$1c
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
	sta dst5+2
	sta dst6+2
	sta dst7+2
	sta dst8+2
.noinc
}
{ ; inc src
	txa
	clc
	adc #$1c
	tax
	bcc loop2 ;noinc
	lda src1+2 ; this is quicker than 4 incs
	adc #0
	cmp #$30
	beq done_buffering
	sta src1+2
	sta src2+2
	sta src3+2
	sta src4+2
	sta src5+2
	sta src6+2
	sta src7+2
	sta src8+2
	jmp loop2 ; always
}
.done_buffering
}
	;lda #$97
	;sta $fe21
	cli
}	;jsr osrdch
	dec zp_temp2
	bmi rts
	jmp loop

.rts	rts
}	

.scrollright_real
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
	lda #BACKG_BYTE
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
	lda #BACKG_BYTE
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
TIMER=$4800
VSYNC=$4e3e	
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
	lda #%01000000 ; was 0
	sta USERVIA_IER
	;cli
	rts
}
; this trashes the orb buffer so be sure to reload afterwards
line0buffer=$2da0
.linetab_lo_temp
	equb 0
.linetab_hi_temp
	equb 0
ENDIF

ELSE
	; elk
.hwscroll_screen_off
{
	sei
	lda #$10+BACKG_COL
	sta $34b
	jsr $cc1b ; blank palette with colour in A
.flip_mode
	lda $282
	eor #%111000 ; screen mode ^= 7
	jmp $e495 ; set ULA misc control and OS copy
.*hwscroll_screen_on
	jsr flip_mode
	cli
	lda $240
.vsync
	cmp $240
	beq vsync
	jmp $cbe8 ; restore palette
}
ENDIF
