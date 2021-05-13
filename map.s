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
	ldy #' '
	jsr print_a_y
	ldx zp_roomno
	lda level_coordtab,X
	jsr print_map_offset
	lda #13
	jsr packed_wrch ; hack to force write
	jsr draw_map_screen
	jsr osrdch ; wait for key
IF 0
	ldx #2
	stx zp_tmpy
	ldx #35
	lda #3
	ldy #0
	jmp plot_some_room ; erase title
ELSE
	jmp plot_entire_room
ENDIF
	
.initmaptab
	;equb 28,3,2,35,0,12,31,1,1
	equb 26,17,128,17,3,12,31,3,0
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

IF 0
.print_map_offset_temp
	sei
	lda #4
	sta $fe30
	jsr print_map_offset
	lda $f4
	sta $fe30
	cli
	rts
ENDIF
	
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


zp_tmpchar=$79
zp_screen_hoffset=$7a
zp_linecount=$7b
zp_screenptr=$7c
zp_tmproomno=$7e
.exit rts
; we only need 280x256 pixel screen = 17920 bytes
; rooms are 40x34 pixels (38x32 plus border)
; max 7x7 map area (FIXME: level 8 is 8 high)

.draw_map_screen
{
	; iterate over each room
	ldy level_nrooms
.roomloop
	dey
	bmi exit
	lda level_coordtab,Y
	bpl roomloop ; skip unexplored rooms
	sty zp_tmproomno

	; calc screen start address
	jsr split_coord
	tay
	lda gridx_lo,X
	clc
	adc gridy_lo,Y
	sta zp_screenptr
	lda gridx_hi,X
	adc gridy_hi,Y
	sta zp_screenptr+1
{	
	; decompress tiles to temporary storage
	; we start from the end and decompress backwards
	lda #>map_tiles_temp_end
	sta zp_exo_dest_hi
	ldx zp_tmproomno
	lda level_roomptrlo,X
	ldy level_roomptrhi,X
	clc
	adc level_orblen,X
	bcc noinc
	iny
.noinc
	tax
	lda #<map_tiles_temp_end
	jsr decrunch_to_no_header
}	

	; draw map of one room
.draw_room
	lda #>(map_tiles_temp+40*2)
	sta tileptr+2

	lda #32
	sta zp_linecount
	ldx #0 ; offset into map tiles
.do_line
	lda #0
	sta zp_screen_hoffset
	
.check_tile

.tileptr
	lda map_tiles_temp+40*2,X ; start one line down
	cmp #$01
	beq notblank
.blank
	lda #$00
.notblank
{	
	ror a
	rol zp_tmpchar
	inx
	inx
	bne noincx
	inc tileptr+2
;	lda #>(map_tiles_temp+33*40*2)
;	cmp tileptr+2
;	beq done
.noincx
	txa
	and #7 ; 4 pixels
	bne check_tile
}
.done_collecting_pixels
	; now zp_tmpchar has 4 bits of pixel data in 3:0
	lda zp_tmpchar
	and #$0f
	eor #$0f
	ldy zp_tmproomno
	cpy zp_roomno
	beq h
	; FIXME: colours
	sta multmp+1
	asl a
	asl a
	asl a
	asl a
.multmp	ora #$ee
.h
	ldy zp_screen_hoffset
	; fixup left/right borders (present in map, but we don't want them)
	bne notzero
	; remove left border
	;ora #$88
	and #$77
.notzero
	cpy #72
	bne not72
	; remove right border
	;ora #$11 
	and #$ee
.not72
	
	
.screenptr
	sta (zp_screenptr),Y
	tya
	clc
	adc #8
	sta zp_screen_hoffset

	; more this line?
	cmp #8*10
	bne check_tile
{
	; move one line down
	inc zp_screenptr
	lda #7
	and zp_screenptr
	bne noincline
	lda zp_screenptr
	clc
	adc #<($280-8)
	sta zp_screenptr	
	lda zp_screenptr+1
	adc #>($280-8)
	sta zp_screenptr+1
.noincline
}
	dec zp_linecount
	bne do_line

.room_done
	ldy zp_tmproomno
	jmp roomloop
.map_done
	rts

MACRO x_to_screen_lo
	EQUB x*8
ENDMACRO

MACRO y_to_screen_lo
	EQUB (y AND 7)+(y DIV 8)*LINELEN
ENDMACRO

IF SMALL_SCREEN=1
	; FIXME: are we doing narrower screen to free up space for map buffer?
	LINELEN=$260
ELSE
	LINELEN=$280
ENDIF
.gridx_lo
	FOR i,0,6,1
	EQUB <(i*10*8)
	NEXT
.gridx_hi
	FOR i,0,6,1
	EQUB >(i*10*8)
	NEXT
.gridy_lo
	FOR i,0,6,1
	EQUB <(SCRSTART+(((i*34+16) AND 7)+((i*34+16) DIV 8)*LINELEN))
	NEXT
.gridy_hi
	FOR i,0,6,1
	EQUB >(SCRSTART+(((i*34+16) AND 7)+((i*34+16) DIV 8)*LINELEN))
	NEXT
}
