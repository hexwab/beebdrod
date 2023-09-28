MINI_SCROLL=1
;SCROLL_POS_LEFT=7
;SCROLL_POS_RIGHT=31
;SCROLL_POS_TOP=8
;SCROLL_POS_BOTTOM=22
SCROLL_POS_LEFT=13
SCROLL_POS_RIGHT=26
SCROLL_POS_TOP=9
SCROLL_POS_BOTTOM=22

; player walked on a scroll
.actually_scroll
{
IF FANCY_BORDERS ; may need to disable for low-memory machines
	sty ytmp+1
	jsr draw_player
.draw_scroll_border
	lda #$58 ; scroll NW
	ldx #SCROLL_POS_LEFT-1
	ldy #SCROLL_POS_TOP-1
	jsr plot_masked_inline
	lda #$5a ; scroll NE
	ldx #SCROLL_POS_RIGHT+1
	ldy #SCROLL_POS_TOP-1
	jsr plot_masked_inline
	lda #$5d ; scroll SW
	ldx #SCROLL_POS_LEFT-1
	ldy #SCROLL_POS_BOTTOM+1
	jsr plot_masked_inline
	lda #$5f ; scroll SE
	ldx #SCROLL_POS_RIGHT+1
	ldy #SCROLL_POS_BOTTOM+1
	jsr plot_masked_inline
.top
	ldx #SCROLL_POS_LEFT
	stx zp_tmpx
.toploop
	lda #$59 ; scroll N
	ldy #SCROLL_POS_TOP-1
	jsr plot_masked_inline
	ldx zp_tmpx
	inx
	stx zp_tmpx
	cpx #SCROLL_POS_RIGHT+1
	bne toploop

.bottom
	ldx #SCROLL_POS_LEFT
	stx zp_tmpx
.bottomloop
	lda #$5e ; scroll S
	ldy #SCROLL_POS_BOTTOM+1
	jsr plot_masked_inline
	ldx zp_tmpx
	inx
	stx zp_tmpx
	cpx #SCROLL_POS_RIGHT+1
	bne bottomloop

.left
	ldy #SCROLL_POS_TOP
	sty zp_tmpy
.leftloop
	lda #$5b ; scroll W
	ldx #SCROLL_POS_LEFT-1
	jsr plot_masked_inline
	ldy zp_tmpy
	iny
	sty zp_tmpy
	cpy #SCROLL_POS_BOTTOM+1
	bne leftloop

.right
	ldy #SCROLL_POS_TOP
	sty zp_tmpy
.rightloop
	lda #$5c ; scroll E
	ldx #SCROLL_POS_RIGHT+1
	jsr plot_masked_inline
	ldy zp_tmpy
	iny
	sty zp_tmpy
	cpy #SCROLL_POS_BOTTOM+1
	bne rightloop
ENDIF
	_print_string drawscrolltab,drawscrolltab_end
IF FANCY_BORDERS
.ytmp	ldy #OVERB
ENDIF
	ldx orbs+2,Y
.scroll_loop
	lda orbs+3,Y
	jsr packed_wrch
	iny
	dex
	cpx #3
	bne scroll_loop
	jsr mini_newl ; force write line
	jsr osrdch ; wait for key
	lda #26
	jsr oswrch
	ldx #SCROLL_POS_TOP-1
	stx zp_tmpy
	ldx #SCROLL_POS_LEFT-1
	lda #SCROLL_POS_RIGHT+2
	ldy #SCROLL_POS_BOTTOM+2
	jmp plot_some_room ; erase scroll
.drawscrolltab
	equb 17,131,17,0
IF FANCY_BORDERS=0
	equb 28,SCROLL_POS_LEFT-1,SCROLL_POS_BOTTOM+1
	equb SCROLL_POS_RIGHT+1,SCROLL_POS_TOP-1,12	
ENDIF
IF PLATFORM_ELK
	equb 28,SCROLL_POS_LEFT+1,SCROLL_POS_BOTTOM,SCROLL_POS_RIGHT+1,SCROLL_POS_TOP,12
ELSE
	equb 28,SCROLL_POS_LEFT,SCROLL_POS_BOTTOM,SCROLL_POS_RIGHT,SCROLL_POS_TOP,12
ENDIF
	
.drawscrolltab_end
}
