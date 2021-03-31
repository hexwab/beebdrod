; X,Y reversed coords
.draw_tile
{
	sty zp_tmpx
	stx zp_tmpy
	jsr get_tile
	; fall through
}

; having just called get_[last_]tile, figure out what to plot and plot it.
; opaque in A (Z if A=0), transparent in X, coords in zp_tmpx/zp_tmpy
.plot_from_tile
{
; if there's something in the transparent layer, plot that
; otherwise plot the opaque layer (FIXME)
	bne not_transp
	txa
.not_transp
	ldx zp_tmpx
	ldy zp_tmpy
	; fall through
}

UNROLL_PLOT=1 ; about 20% faster

; X,Y coords, A sprite number
.plot
{
.last_sprite
	cmp #$ee
	beq same ; skip src calc if we can
	sta last_sprite+1
IF UNROLL_PLOT=0
	; calc src address
	and #$0f
	ora #>SPRTAB
	sta src1+2

	lda last_sprite+1
	and #$f0
	sta src1+1
.same
	; calc dest address
	lda linetab_lo,Y
	clc
	adc mul16_lo,X
	sta dst1+1
	lda linetab_hi,Y
	adc mul16_hi,X
	sta dst1+2
	ldx #15
.loop
.src1
	lda $ee00,X
.dst1
	sta $ee00,X
	dex
	bpl loop
ELSE
	; calc src address
	and #$0f
	ora #>SPRTAB
	sta src1+2
	sta src2+2

	lda last_sprite+1
	and #$f0
	sta src1+1
	ora #8
	sta src2+1
.same
	; calc dest address
	lda linetab_lo,Y
	clc
	adc mul16_lo,X
	sta dst1+1
	ora #8
	sta dst2+1
	lda linetab_hi,Y
	adc mul16_hi,X
	sta dst1+2
	sta dst2+2
	ldx #7
.loop
.src1
	lda $ee00,X
.dst1
	sta $ee00,X
.src2
	lda $ee00,X
.dst2
	sta $ee00,X
	dex
	bpl loop
ENDIF
	rts
}

; UNUSED, UNTESTED

; X,Y coords, A masked sprite number
.plot_masked
{
	sta tmp+1
	and #$0f
	ora #>MSPRTAB
	sta src1+2
	sta mask1+2
.tmp
	lda #$00
	and #$f0
	sta src1+1
	ora #$80
	sta mask1+1
	lda linetab_lo,Y
	clc
	adc mul16_lo,X
	sta dst1+1
	sta dst2+1
	lda linetab_hi,Y
	adc mul16_hi,X
	sta dst1+2
	sta dst2+2
	ldx #15
.loop
.dst1
	lda $ee00,X
.src1
	and $ee00,X
.mask1
	ora $ee00,X
.dst2
	sta $ee00,X
	dex
	bpl loop
	rts
}
.linetab_lo
FOR I,0,32,1
	EQUB <(I*XRES*16+SCRSTART)
NEXT
.linetab_hi
FOR I,0,32,1
	EQUB >(I*XRES*16+SCRSTART)
NEXT
.mul16_lo
FOR I,0,42,1
	EQUB <(I*16)
NEXT
.mul16_hi
FOR I,0,42,1
	EQUB >(I*16)
NEXT
