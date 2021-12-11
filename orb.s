; activate the orb at coordinates zp_tmpx/zp_tmpy
; this is either actually an orb we hit with our sword
; or a scroll we just walked over
.orb
{
	ldy #0
.orbloop
	lda orbs,Y
	php
	and #$3f
	cmp zp_tmpx
	bne no
	lda orbs+1,Y
	lsr a
	lsr a
	cmp zp_tmpy
	bne no
	sty zp_tmpindex
.do_orb
{
	plp
	bmi actually_scroll
	jsr zap_start
; loop over targets for this orb
.do_orb_loop
	ldy zp_tmpindex
	lda orbs+3,Y
	sta orb_type+1
	lsr a
	lsr a
	tax
	lda orbs+2,Y
	php
	iny
	iny
	sty zp_tmpindex
	and #$7f
	tay

	sty zp_tmpx
	stx zp_tmpy
	jsr zap_to
	jsr get_tile
.orb_type
	lda #OVERB
	and #3
	cmp #1
	beq orb_type_toggle
	cmp #2
	beq orb_type_open
	;cmp #3
	;beq orb_type_close
	;brk
.orb_type_close
	cpx #$0a
	bne skip
	beq done_orb_type
.orb_type_open
	cpx #$09
	bne skip
.orb_type_toggle
.done_orb_type
	stx fill_from+1
	txa
	eor #$03
	sta fill_to+1
	ldy zp_tmpx
	ldx zp_tmpy
	jsr fill
.skip
	plp
	bpl do_orb_loop
	jmp zap_plot
	;rts
}
; not this orb
.no
	plp
	bmi skip_scroll
	lda orbs+1,Y
	and #3
	clc
	adc #1+1
	asl a
.*orb_skip_a
	sta tmp+1
	tya
	clc
.tmp	adc #OVERB
	tay
	bne orbloop ;always
}	
