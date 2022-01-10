; sprite: 8x8 tile plotting

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
	beq no
	jmp plot
.no	rts
}

; X,Y reversed coords
.draw_tile
{
	sty zp_tmpx
	stx zp_tmpy
.*plot_tile_with_special
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
IF PROPER_PITS
	cpx #2
	bne notpit
{	; pit fixup
	pha
	tya
	clc
	adc #256-40*2-1
	tay
	lda (zp_tileptr),Y
	cmp #2 ; pit above?
	bne no
	; FIXME: this is too big and too slow
	ldx zp_tmpy
	dex
	bmi always_spikes_2 ; if out of bounds we assume spikes
	dex
	ldy zp_tmpx
	jsr get_tile_ptr_and_index;_with_bounds
	;bcs no
	;brk
	lda (zp_tileptr),Y
{	pha ; restore
	ldy zp_tmpx
	ldx zp_tmpy
	jsr get_tile_ptr_and_index
	pla
}
.always_spikes_2
	ldx #$60 ; spikes 1
	cmp #2 ; pit above above?
	bne no
	;brk
	inx ; spikes 2
.no
	pla
}
.notpit
ENDIF
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
	bne ok
	brk
.ok
ENDIF
IF OPAQUE_TAR	
	; hack: centre need not be transparent
	; opaque plotting speeds up drawing large areas of tar
	cmp #$23
	bne xtmp
	plp
	bcc not_transp_sprite_in_a ; always
IF DEBUG
	brk
ENDIF
ENDIF	
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
	; hack: check for empty background. makes drawing snakes much faster
	; FIXME: this works only if mask colour is floor colour
	;cpx #0
	;beq not_transp_sprite_in_a
	; plot tranparent over opaque
	stx background_sprite+1
	ldx zp_tmpx
	ldy zp_tmpy
	;bpl plot_masked_inline_with_background ; always
	jmp plot_masked_inline_with_background ; FIXME?
.not_transp
	; common case: nothing in the transparent layer
	; so plot just the opaque layer
	txa
.*not_transp_sprite_in_a
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
IF HWSCROLL
	bmi wrap
.nowrap
ENDIF
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
IF HWSCROLL
	bmi wrap
.nowrap
ENDIF
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
IF HWSCROLL
.wrap
	sec
	sbc #$50
	bpl nowrap ; always
ENDIF
}

FAST_PLOT_INLINE=1
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
IF FAST_PLOT_INLINE
	sta dst3+1
ENDIF
	lda linetab_hi,Y
	adc mul16_hi,X
IF HWSCROLL
	bmi wrap
.nowrap
ENDIF
	sta dst1+2
	sta dst2+2
IF FAST_PLOT_INLINE
	sta dst3+2
ENDIF
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
IF FAST_PLOT_INLINE
	; via https://mdfs.net/Info/Comp/6502/ProgTips/BitManip
	; thanks JGH!
	sta tmp+1
	; swap nibbles
	asl A      ; a   bcdefgh0
	adc #$80   ; b   Bcdefgha
	rol A      ; B   cdefghab
	asl A      ; c   defghab0
	adc #&80   ; d   Defghabc
	rol A      ; D   efghabcd
.tmp	and #$EE
	eor #$ff
	sta tmp2+1 ;bytemask
.src2	lda $ee00,X
.dst1	eor $ee00,X
.tmp2	and #$EE
.dst2	eor $ee00,X
.dst3	sta $ee00,X
ELSE
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
ENDIF
.skip
	dex
	bpl loop
	rts
IF HWSCROLL
.wrap
	sec
	sbc #$50
	bpl nowrap ; always
ENDIF
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
IF HWSCROLL
	bmi wrap
.nowrap
ENDIF
	sta dst2+2
	ldx #15
.loop
.src1	lda $ee00,X
	eor #$0f ; colour 2 is transparent
	beq skip
IF FAST_PLOT_INLINE
	sta tmp+1
	; swap nibbles
	asl A      ; a   bcdefgh0
	adc #$80   ; b   Bcdefgha
	rol A      ; B   cdefghab
	asl A      ; c   defghab0
	adc #&80   ; d   Defghabc
	rol A      ; D   efghabcd
.tmp	and #$EE
ELSE
	sta tmp+1
	nibshiftright
.tmp	and #$ee
	sta tmp2+1
	nibshiftleft
.tmp2	ora #$ee
ENDIF
.skip	tay
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
IF HWSCROLL
.wrap
	sec
	sbc #$50
	bpl nowrap ; always
ENDIF
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
