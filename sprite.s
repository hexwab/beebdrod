MACRO nibshiftright
	lsr a
	lsr a
	lsr a
	lsr a
ENDMACRO
MACRO nibshiftleft
	asl a
	asl a
	asl a
	asl a
ENDMACRO

.plot_with_bounds_check
{
	cpx #0
	bmi no
	cpx #XSIZE
	beq no
	cpy #0
	bmi no
	cpy #YSIZE
	bne plot
.no	rts
}

; X,Y reversed coords
.draw_tile
{
	sty zp_tmpx
	stx zp_tmpy
	jsr get_tile
	; check for special tile types
.*plot_from_tile_with_special
	php
	cpx #1
	bne notfloor
.floor
	; checkered pattern for floor
	pha
	lda zp_tmpx
	eor zp_tmpy
	and #1
	tax
	pla
.notfloor
	cmp #$66 ; roach
	bne notroach
{ ; roach fixup
	stx xtmp+1
	jsr get_dir_to_player
	ora #$68
.xtmp	ldx #OVERB
	plp
	jmp plot_from_tile_always_masked_no_flags
}	
.notroach
	cmp #$23
	bne nottar
{ ; tar fixup
	stx xtmp+1
	jsr tar_get_corner
IF DEBUG
	; should not be baby here
	;bne ok
	;brk
.ok
ENDIF
	; hack: centre need not be transparent
	cmp #$23
	bne xtmp
	plp
	tax
	lda #0
	beq plot_from_tile ; always
.xtmp
	ldx #OVERB
}
.nottar
	plp
	; fall through
}

; having just called get_[last_]tile, figure out what to plot and plot it.
; transparent in A (Z if A=0), opaque in X, coords in zp_tmpx/zp_tmpy
.plot_from_tile
{
	beq not_transp
.*plot_from_tile_always_masked_no_flags
	; plot tranparent over opaque
	stx background_sprite+1
	ldx zp_tmpx
	ldy zp_tmpy
	jmp plot_masked_inline_with_background
.not_transp
	; common case: nothing in the transparent layer
	; so plot just the opaque layer
	txa
	ldx zp_tmpx
	ldy zp_tmpy
	; fall through
}

ONLY_128_SPRITES=1

; X,Y coords, A sprite number
.plot
{
.last_sprite
	cmp #$ee
	beq same ; skip src calc if we can
	sta last_sprite+1
IF UNROLL_PLOT=0
	; calc src address
IF ONLY_128_SPRITES=1
	and #$07
ELSE
	and #$0f
ENDIF
	ora #>SPRTAB
	sta src1+2

	lda last_sprite+1
IF ONLY_128_SPRITES=1
	asl a
ENDIF
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
IF ONLY_128_SPRITES=1
	and #$07
ELSE
	and #$0f
ENDIF
	ora #>SPRTAB
	sta src1+2
	sta src2+2

	lda last_sprite+1
IF ONLY_128_SPRITES=1
	asl a
ENDIF
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


; X,Y coords, A sprite number
.plot_masked_inline
{
.last_sprite
	cmp #$ee
	beq same ; skip src calc if we can
	sta last_sprite+1

	; calc src address
IF ONLY_128_SPRITES=1
	and #$07
ELSE
	and #$0f
ENDIF
	ora #>SPRTAB
	sta src1+2
	sta src2+2

	lda last_sprite+1
IF ONLY_128_SPRITES=1
	asl a
ENDIF
	and #$f0
	sta src1+1
	sta src2+1
.same
	; calc dest address
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
	; get src byte (4px)
	; if it's zero, don't draw anything at all
	; OR MSN with LSN. now LSN is 4 bits of mask (0 for origsrc, 1 for newsrc)
	; OR LSN with LSN<<4. gives bytemask
	; now dest=(origsrc AND bytemask) OR (newsrc AND NOT bytemask)
	
.src1	lda $ee00,X
	eor #$0f ; colour 2 is transparent
	beq skip
	sta tmp+1
	nibshiftright
.tmp	and #$ee
	sta tmp2+1
	nibshiftleft
.tmp2	ora #$ee
	tay
.dst1	and $ee00,X
	sta tmp3+1
	tya
	eor #$ff
.src2	and $ee00,X
.tmp3	ora #$ee
.dst2	sta $ee00,X

.skip
	dex
	bpl loop
	rts
}



; X,Y coords, A sprite number 
.plot_masked_inline_with_background
{
.last_sprite
	cmp #$ee
	beq same ; skip src calc if we can
	sta last_sprite+1

	; calc src address
IF ONLY_128_SPRITES=1
	and #$07
ELSE
	and #$0f
ENDIF
	ora #>SPRTAB
	sta src1+2
	sta src2+2

	lda last_sprite+1
IF ONLY_128_SPRITES=1
	asl a
ENDIF
	and #$f0
	sta src1+1
	sta src2+1
.same

.*background_sprite
	lda #$ee
	; calc src address
IF ONLY_128_SPRITES=1
	and #$07
ELSE
	and #$0f
ENDIF
	ora #>SPRTAB
	sta dst1+2

	lda background_sprite+1
IF ONLY_128_SPRITES=1
	asl a
ENDIF
	and #$f0
	sta dst1+1

	; calc dest address
	lda linetab_lo,Y
	clc
	adc mul16_lo,X
	sta dst2+1
	lda linetab_hi,Y
	adc mul16_hi,X
	sta dst2+2
	ldx #15
.loop
.src1	lda $ee00,X
	eor #$0f ; colour 2 is transparent
	sta tmp+1
	nibshiftright
.tmp	and #$ee
	sta tmp2+1
	nibshiftleft
.tmp2	ora #$ee
	tay
.dst1	and $ee00,X
	sta tmp3+1
	tya
	eor #$ff
.src2	and $ee00,X
.tmp3	ora #$ee
.dst2	sta $ee00,X

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
