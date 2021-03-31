; decrunched level is 40*34*2=2720 bytes
map_tiles_temp = $b000 ; FIXME
map_tiles_temp_end = map_tiles_temp+40*34*2

;map_draw_ptr = $
; one byte per room (max 25 per level)
; 00 = unexplored
; 01 = unconquered
; 02 = conquered
.do_map

; set up window
{
	ldx #0
.loop
	lda initmaptab,X
	jsr oswrch
	inx
	cpx #initmaptab_end-initmaptab
	bne loop
}	
	jsr print_level_name
	lda #':'
	jsr oswrch
	lda #' '
	jsr oswrch
	ldx zp_roomno
	lda level_coordtab,X
	jsr print_map_offset
	jsr $ffe0 ; wait for key
	ldx #2
	stx zp_tmpy
	ldx #35
	lda #3
	ldy #0
	jmp plot_some_room ; erase title

.initmaptab
	equb 28,3,2,35,0,12,31,1,1
.initmaptab_end
	
.print_level_name
{	
	ldx #0
.loop	
	lda namestash,X
	php
	jsr packed_wrch
	inx
	plp
	bpl loop
	rts
}

; A=zzyyyxxx -> A=yyy X=xxx
.split_coord
{
	pha
	and #$07
	tax
	pla
	lsr A
	lsr A
	lsr A
	and #$07
	rts
}


.print_map_offset_temp
	sei
	lda #4
	sta $fe30
	jsr print_map_offset
	lda $f4
	sta $fe30
	cli
	rts

; offset (3:3) in A
.print_map_offset
{
	tay
	ldx level_startroom
	lda level_coordtab,X
	jsr split_coord
	sta tmp+1
	stx tmp2+1
	tya
	jsr split_coord
	stx tmp3+1
	ldy #14 ; tok_north
	sec
.tmp
	sbc #$00
	sta zp_tmpx
	beq done
	jsr print_dir_offset
.done
.tmp3
	lda #$00
	ldy #16 ;tok_east
	sec
.tmp2
	sbc #$00
	beq done2
	
	; maybe print a comma
	php
	pha
	lda zp_tmpx
	beq skip
	lda #','
	ldy #' '
	jsr print_a_y
	ldy #16 ;tok_east
.skip
	pla
	plp
	
.print_dir_offset
	bpl north ; carry is set if taken
.south
	iny
	equb $2c ; skip
	; carry is clear here
.north
	eor #$ff
	adc #11
.*print_a_ce_y
	ldx #11 ;tok_ce
.*print_a_x_y
	jsr packed_wrch
	txa
.*print_a_y
	jsr packed_wrch
	tya
	jmp packed_wrch
.done2
	lda zp_tmpx
	bne done3
.entrance
	lda #18;tok_the
	ldx #12;tok_entran
	ldy #11;tok_ce
	bne print_a_x_y ;always
.done3
	rts
}

.explored_array
	skip 25

; we only need 280x256 pixel screen = 17920 bytes
; rooms are 40x34 pixels (38x32 plus border)
; max 7x7 map area (FIXME: level 8 is 8 high)
IF 0
.draw_map_screen
{
	;; decompress one room to temporary storage
	ldy zp_roomno
	lda level_roomptrlo,Y
	sta INPOS
	lda level_roomptrhi,Y
        sta INPOS+1
	; we start from the end and decompress backwards
	lda #<map_tiles_temp_end
	sta zp_dest_lo
	lda #>map_tiles_temp_end
	sta zp_dest_hi
	jsr continue_decrunching
}
ENDIF
