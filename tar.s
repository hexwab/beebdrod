; zp_tmpx, zp_tmpy set
; Y index for get_last_tile	
; zp_temp used for orthogonal mask: 0000abcd a=left b=right c=top d=bottom

.tar_table
		     ; ESWN
	equb $0      ; 0000 baby
	equb $0      ; 0001 baby
	equb $0      ; 0010 baby
	equb $35*2   ; 0011 SW
	equb $0      ; 0100 baby
	equb $0      ; 0101 baby
	equb $30*2   ; 0110 NW
	equb $33*2+1 ; 0111 W
	equb $0      ; 1000 baby
	equb $37*2   ; 1001 SE
	equb $0      ; 1010 baby
	equb $36*2+1 ; 1011 S
	equb $32*2   ; 1100 NE
	equb $34*2+1 ; 1101 E
	equb $31*2+1 ; 1110 N
	equb $23*2   ; 1111 centre

	; returns: A transp tile for corner,
	; zero (with Z) if baby, C if cuttable
	; X corrupted, Y preserved
.tar_get_corner
{
	sty tmpindex+1
IF MASTER
	stz zp_temp
ELSE
	lda #0
	sta zp_temp
ENDIF
	ldx #7
.loop
	lda dirtable_offset,X ; 7,5,3,1: orthogonal dirs
	clc
.tmpindex
	adc #OVERB
	tay
	lda (zp_tileptr),Y
	and #&3f
	cmp #$23 ; tar
	clc
	bne skip
	sec
.skip
	rol zp_temp
	dex
	dex
	bpl loop
	ldx zp_temp
	ldy tmpindex+1
	lda tar_table,X
	lsr A
	rts
}

; zp_tmpx/y: coords
.tar_update
{
	ldy zp_tmpx
	ldx zp_tmpy
	jsr get_tile
	cmp #$23
	bne no
	stx xtmp+1
	jsr tar_get_corner
	bne not_baby
	; tar spawned a baby
	; replace transp with baby tile
	; (FIXME: should be in monster list)
	lda #$3c ; baby
	sta (zp_tileptr),Y
.not_baby
.xtmp
	ldx #OVERB
	jmp plot_from_tile
.no
	rts
}
